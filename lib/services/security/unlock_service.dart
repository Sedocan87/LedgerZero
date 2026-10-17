import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/crypto/recovery_key.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/legacy_key_material.dart';

/// The recovery key cannot be used until the legacy migration was finished
/// with the password.
class LegacyMigrationPendingException implements Exception {
  const LegacyMigrationPendingException();
  @override
  String toString() => 'LegacyMigrationPendingException';
}

/// The outcome of a successful unlock.
class UnlockResult {
  /// The data key. The caller hands it to the session and then zeroes it.
  final Uint8List dek;

  /// A recovery key created during this unlock (legacy migration). It has
  /// never been shown: the UI must show it and ask the user to confirm they
  /// saved it.
  final RecoveryKey? newRecoveryKey;

  /// The legacy design kept a plaintext key for biometrics; it was deleted
  /// and biometric unlock must be enabled again.
  final bool biometricsWereReset;

  const UnlockResult(
    this.dek, {
    this.newRecoveryKey,
    this.biometricsWereReset = false,
  });
}

/// Turns a password, recovery key or biometric authentication into the
/// database key, migrating legacy installs on the way.
class UnlockService {
  final KeyVault _vault;
  final LegacyKeyMaterial _legacy;
  final BiometricKeyStore _biometrics;
  final Future<File> Function() _databaseFile;

  UnlockService({
    required this._vault,
    required this._legacy,
    required this._biometrics,
    required this._databaseFile,
  });

  /// Whether any key material (current or legacy) exists.
  Future<bool> isSetUp() async =>
      await _vault.exists() || await _legacy.exists();

  /// Unlocks with the master password.
  ///
  /// Throws [WrongPasswordException], [VaultMissingException] or
  /// [DatabaseKeyException] (key unwraps but the database does not open).
  Future<UnlockResult> unlockWithPassword(String password) async {
    if (await _vault.exists()) {
      final record = await _vault.load();
      final dek = await _vault.unwrapWithPassword(record, password);
      if (record.legacyMigrationPending) {
        return _finishLegacyMigration(record, dek, password);
      }
      await _ensureDatabaseOpens(dek);
      return UnlockResult(dek);
    }
    if (await _legacy.exists()) {
      return _migrateLegacy(password);
    }
    throw const VaultMissingException();
  }

  /// Unlocks with the recovery key.
  Future<Uint8List> unlockWithRecoveryKey(String typed) async {
    final record = await _vault.load();
    if (record.legacyMigrationPending) {
      // The database may still carry the legacy key; only the password can
      // finish the migration.
      throw const LegacyMigrationPendingException();
    }
    final dek = await _vault.unlockWithRecoveryKey(typed);
    await _ensureDatabaseOpens(dek);
    return dek;
  }

  /// Unlocks with the biometric store. Throws [BiometricException].
  Future<Uint8List> unlockWithBiometrics(BiometricPromptTexts texts) async {
    Uint8List dek;
    try {
      dek = await _biometrics.read(texts);
    } on BiometricException catch (e) {
      if (e.failure == BiometricFailure.invalidated) {
        await _biometrics.delete();
      }
      rethrow;
    }
    try {
      // Confirms the stored key still belongs to the vault (it would not
      // after a reset or a vault rebuilt elsewhere).
      (await _vault.revealRecoveryKey(dek)).destroy();
    } on VaultCorruptException {
      zeroBytes(dek);
      await _biometrics.delete();
      throw const BiometricException(BiometricFailure.invalidated);
    }
    await _ensureDatabaseOpens(dek);
    return dek;
  }

  Future<void> _ensureDatabaseOpens(Uint8List dek) async {
    final file = await _databaseFile();
    if (!file.existsSync()) {
      return; // Created on first use with this key.
    }
    if (!SqlCipher.canOpen(file, RawSqlCipherKey(dek))) {
      throw const DatabaseKeyException(
        'the data key does not open the database',
      );
    }
  }

  /// First login after updating from the pre-v2 design.
  ///
  /// Crash safety: the vault for the new key is written (marked pending)
  /// before the database is re-keyed and the legacy entries are deleted only
  /// afterwards, so every interruption leaves a state that
  /// [_finishLegacyMigration] can complete with the same password.
  Future<UnlockResult> _migrateLegacy(String password) async {
    final salt = (await _legacy.salt())!;
    final passphrase = await _legacy.derivePassphrase(password, salt);
    final legacyKey = LegacyPassphraseKey(passphrase);
    final file = await _databaseFile();
    final hasDatabase = file.existsSync();

    final verified = await _legacy.matchesVerifier(passphrase);
    if (verified == false) {
      throw const WrongPasswordException();
    }
    if (hasDatabase && !SqlCipher.canOpen(file, legacyKey)) {
      throw const WrongPasswordException();
    }

    final pending = await _vault.build(password, legacyMigrationPending: true);
    await _vault.save(pending.record);
    if (hasDatabase) {
      await _rekey(file, legacyKey, pending.dek);
    }
    await _vault.save(pending.record.copyWith(legacyMigrationPending: false));
    final hadBiometricKey =
        await _legacyBiometricKeyPresent() || await _biometrics.hasKey();
    await _legacy.deleteAll();
    await _biometrics.delete();
    return UnlockResult(
      pending.dek,
      newRecoveryKey: pending.recoveryKey,
      biometricsWereReset: hadBiometricKey,
    );
  }

  Future<UnlockResult> _finishLegacyMigration(
    VaultRecord record,
    Uint8List dek,
    String password,
  ) async {
    final file = await _databaseFile();
    final rawKey = RawSqlCipherKey(dek);
    if (file.existsSync() && !SqlCipher.canOpen(file, rawKey)) {
      final salt = await _legacy.salt();
      if (salt == null) {
        throw const DatabaseKeyException('legacy key material is missing');
      }
      final legacyKey = LegacyPassphraseKey(
        await _legacy.derivePassphrase(password, salt),
      );
      if (!SqlCipher.canOpen(file, legacyKey)) {
        throw const DatabaseKeyException(
          'database opens with neither the new nor the legacy key',
        );
      }
      await _rekey(file, legacyKey, dek);
    }
    await _vault.save(record.copyWith(legacyMigrationPending: false));
    final hadBiometricKey = await _legacyBiometricKeyPresent();
    await _legacy.deleteAll();
    await _biometrics.delete();
    // The recovery key was created before the interruption and never shown.
    final recoveryKey = await _vault.revealRecoveryKey(dek);
    return UnlockResult(
      dek,
      newRecoveryKey: recoveryKey,
      biometricsWereReset: hadBiometricKey,
    );
  }

  Future<bool> _legacyBiometricKeyPresent() async =>
      (await _legacyStoreRead(LegacyKeyMaterial.keyEntry)) != null;

  Future<String?> _legacyStoreRead(String key) => _legacy.read(key);

  static Future<void> _rekey(
    File file,
    LegacyPassphraseKey from,
    Uint8List dek,
  ) {
    final path = file.path;
    final passphrase = from.passphrase;
    final keyBytes = Uint8List.fromList(dek);
    return Isolate.run(() {
      try {
        SqlCipher.rekey(
          File(path),
          LegacyPassphraseKey(passphrase),
          RawSqlCipherKey(keyBytes),
        );
      } finally {
        zeroBytes(keyBytes);
      }
    });
  }
}
