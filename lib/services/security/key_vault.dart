import 'dart:convert';
import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/aead.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/security/crypto/recovery_key.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/secure_store.dart';

/// Thrown when the password does not unwrap the data key.
class WrongPasswordException implements Exception {
  const WrongPasswordException();
  @override
  String toString() => 'WrongPasswordException';
}

/// Thrown when the recovery key is malformed or does not unwrap the data key.
class InvalidRecoveryKeyException implements Exception {
  const InvalidRecoveryKeyException();
  @override
  String toString() => 'InvalidRecoveryKeyException';
}

/// Thrown when no key vault exists (not set up, or secure storage was lost).
class VaultMissingException implements Exception {
  const VaultMissingException();
  @override
  String toString() => 'VaultMissingException';
}

/// Thrown when the stored vault cannot be parsed.
class VaultCorruptException implements Exception {
  final String message;
  const VaultCorruptException(this.message);
  @override
  String toString() => 'VaultCorruptException: $message';
}

/// The persisted key vault (format v2). It holds the random 256-bit data
/// key (DEK) that encrypts the database, only ever in wrapped form:
///
/// * `password`: AES-256-GCM under a key derived from the master password
///   with [KdfParams] (stored here, together with the salt);
/// * `recovery`: AES-256-GCM under HKDF-SHA256(recovery key), where the
///   recovery key is 160 random bits independent of the password;
/// * `recoveryKey`: the recovery key encrypted under the DEK, so it can be
///   shown again in Settings after re-authentication. It grants nothing
///   beyond the DEK it is encrypted with.
///
/// A wrong password or recovery key is detected by the GCM tag; there is no
/// separate verifier hash.
class VaultRecord {
  static const int formatVersion = 2;

  final KdfParams passwordKdf;
  final Uint8List passwordNonce;
  final Uint8List passwordCiphertext;
  final Uint8List recoverySalt;
  final Uint8List recoveryNonce;
  final Uint8List recoveryCiphertext;
  final Uint8List recoveryKeyNonce;
  final Uint8List recoveryKeyCiphertext;

  /// Set while a legacy database is being re-keyed to this record's DEK.
  final bool legacyMigrationPending;

  const VaultRecord({
    required this.passwordKdf,
    required this.passwordNonce,
    required this.passwordCiphertext,
    required this.recoverySalt,
    required this.recoveryNonce,
    required this.recoveryCiphertext,
    required this.recoveryKeyNonce,
    required this.recoveryKeyCiphertext,
    this.legacyMigrationPending = false,
  });

  VaultRecord copyWith({
    KdfParams? passwordKdf,
    Uint8List? passwordNonce,
    Uint8List? passwordCiphertext,
    Uint8List? recoverySalt,
    Uint8List? recoveryNonce,
    Uint8List? recoveryCiphertext,
    Uint8List? recoveryKeyNonce,
    Uint8List? recoveryKeyCiphertext,
    bool? legacyMigrationPending,
  }) {
    return VaultRecord(
      passwordKdf: passwordKdf ?? this.passwordKdf,
      passwordNonce: passwordNonce ?? this.passwordNonce,
      passwordCiphertext: passwordCiphertext ?? this.passwordCiphertext,
      recoverySalt: recoverySalt ?? this.recoverySalt,
      recoveryNonce: recoveryNonce ?? this.recoveryNonce,
      recoveryCiphertext: recoveryCiphertext ?? this.recoveryCiphertext,
      recoveryKeyNonce: recoveryKeyNonce ?? this.recoveryKeyNonce,
      recoveryKeyCiphertext:
          recoveryKeyCiphertext ?? this.recoveryKeyCiphertext,
      legacyMigrationPending:
          legacyMigrationPending ?? this.legacyMigrationPending,
    );
  }

  String encode() => jsonEncode({
    'v': formatVersion,
    'password': {
      'kdf': passwordKdf.toJson(),
      'nonce': base64.encode(passwordNonce),
      'ct': base64.encode(passwordCiphertext),
    },
    'recovery': {
      'salt': base64.encode(recoverySalt),
      'nonce': base64.encode(recoveryNonce),
      'ct': base64.encode(recoveryCiphertext),
    },
    'recoveryKey': {
      'nonce': base64.encode(recoveryKeyNonce),
      'ct': base64.encode(recoveryKeyCiphertext),
    },
    if (legacyMigrationPending) 'legacyMigrationPending': true,
  });

  factory VaultRecord.decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['v'] != formatVersion) {
        throw VaultCorruptException('unsupported vault version ${json['v']}');
      }
      final password = json['password'] as Map<String, dynamic>;
      final recovery = json['recovery'] as Map<String, dynamic>;
      final recoveryKey = json['recoveryKey'] as Map<String, dynamic>;
      return VaultRecord(
        passwordKdf: KdfParams.fromJson(
          password['kdf'] as Map<String, dynamic>,
        ),
        passwordNonce: base64.decode(password['nonce'] as String),
        passwordCiphertext: base64.decode(password['ct'] as String),
        recoverySalt: base64.decode(recovery['salt'] as String),
        recoveryNonce: base64.decode(recovery['nonce'] as String),
        recoveryCiphertext: base64.decode(recovery['ct'] as String),
        recoveryKeyNonce: base64.decode(recoveryKey['nonce'] as String),
        recoveryKeyCiphertext: base64.decode(recoveryKey['ct'] as String),
        legacyMigrationPending: json['legacyMigrationPending'] == true,
      );
    } on VaultCorruptException {
      rethrow;
    } catch (e) {
      throw const VaultCorruptException('malformed vault');
    }
  }
}

/// A vault built in memory but not yet saved, plus the secrets the caller
/// must show (recovery key) or use (DEK).
class PendingVault {
  final VaultRecord record;
  final Uint8List dek;
  final RecoveryKey recoveryKey;

  PendingVault(this.record, this.dek, this.recoveryKey);
}

/// Creates, unlocks and re-wraps the key vault. See [VaultRecord].
class KeyVault {
  static const String storageKey = 'lz_key_vault_v2';
  static const int dekLength = 32;

  static final Uint8List _passwordAad = _ascii('ledgerzero/dek/password/v2');
  static final Uint8List _recoveryAad = _ascii('ledgerzero/dek/recovery/v2');
  static final Uint8List _recoveryInfo = _ascii('ledgerzero/recovery-kek/v2');
  static final Uint8List _recoveryKeyAad = _ascii('ledgerzero/recovery-key/v2');

  final SecureStore _store;
  final KdfParams Function() _newKdfParams;

  KeyVault(this._store, {KdfParams Function()? newKdfParams})
    : _newKdfParams = newKdfParams ?? KdfParams.recommended;

  Future<bool> exists() async => (await _store.read(storageKey)) != null;

  Future<VaultRecord> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) {
      throw const VaultMissingException();
    }
    return VaultRecord.decode(raw);
  }

  /// Persists [record] with a single storage write.
  Future<void> save(VaultRecord record) =>
      _store.write(storageKey, record.encode());

  Future<void> delete() => _store.delete(storageKey);

  /// Builds a vault for a new random DEK (or [existingDek]) protected by
  /// [password] and a new recovery key. Nothing is written.
  Future<PendingVault> build(
    String password, {
    Uint8List? existingDek,
    bool legacyMigrationPending = false,
  }) async {
    final dek = existingDek != null
        ? Uint8List.fromList(existingDek)
        : secureRandomBytes(dekLength);
    final recoveryKey = RecoveryKey.generate();
    final passwordPart = await _wrapWithPassword(dek, password);
    final recoverySalt = secureRandomBytes(16);
    final recoveryKek = _recoveryKek(recoveryKey, recoverySalt);
    final recoveryNonce = AesGcm.randomNonce();
    final recoveryCiphertext = AesGcm.encrypt(
      key: recoveryKek,
      nonce: recoveryNonce,
      plaintext: dek,
      aad: _recoveryAad,
    );
    zeroBytes(recoveryKek);
    final recoveryKeyNonce = AesGcm.randomNonce();
    final recoveryKeyCiphertext = AesGcm.encrypt(
      key: dek,
      nonce: recoveryKeyNonce,
      plaintext: recoveryKey.bytes,
      aad: _recoveryKeyAad,
    );
    final record = VaultRecord(
      passwordKdf: passwordPart.$1,
      passwordNonce: passwordPart.$2,
      passwordCiphertext: passwordPart.$3,
      recoverySalt: recoverySalt,
      recoveryNonce: recoveryNonce,
      recoveryCiphertext: recoveryCiphertext,
      recoveryKeyNonce: recoveryKeyNonce,
      recoveryKeyCiphertext: recoveryKeyCiphertext,
      legacyMigrationPending: legacyMigrationPending,
    );
    return PendingVault(record, dek, recoveryKey);
  }

  /// Unwraps the DEK with the master password.
  Future<Uint8List> unlockWithPassword(String password) async {
    final record = await load();
    return unwrapWithPassword(record, password);
  }

  Future<Uint8List> unwrapWithPassword(
    VaultRecord record,
    String password,
  ) async {
    final kek = await deriveKey(password, record.passwordKdf);
    try {
      return AesGcm.decrypt(
        key: kek,
        nonce: record.passwordNonce,
        ciphertext: record.passwordCiphertext,
        aad: _passwordAadFor(record.passwordKdf),
      );
    } on AeadAuthenticationException {
      throw const WrongPasswordException();
    } finally {
      zeroBytes(kek);
    }
  }

  /// Unwraps the DEK with a typed recovery key.
  Future<Uint8List> unlockWithRecoveryKey(String typed) async {
    final key = RecoveryKey.tryParse(typed);
    if (key == null) {
      throw const InvalidRecoveryKeyException();
    }
    final record = await load();
    final kek = _recoveryKek(key, record.recoverySalt);
    try {
      return AesGcm.decrypt(
        key: kek,
        nonce: record.recoveryNonce,
        ciphertext: record.recoveryCiphertext,
        aad: _recoveryAad,
      );
    } on AeadAuthenticationException {
      throw const InvalidRecoveryKeyException();
    } finally {
      zeroBytes(kek);
      key.destroy();
    }
  }

  /// Re-wraps the DEK under [newPassword] after checking [currentPassword].
  /// One storage write; the recovery key stays valid and the database is not
  /// re-keyed.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final record = await load();
    final dek = await unwrapWithPassword(record, currentPassword);
    try {
      await _rewrapPassword(record, dek, newPassword);
    } finally {
      zeroBytes(dek);
    }
  }

  /// Sets a new password for an already-unwrapped [dek] (after a recovery-key
  /// login). One storage write; the recovery key stays valid.
  Future<void> setPassword({
    required Uint8List dek,
    required String newPassword,
  }) async {
    final record = await load();
    _checkDek(record, dek);
    await _rewrapPassword(record, dek, newPassword);
  }

  /// Returns the current recovery key, decrypted with the session's [dek].
  Future<RecoveryKey> revealRecoveryKey(Uint8List dek) async {
    final record = await load();
    return _decryptRecoveryKey(record, dek);
  }

  /// Builds a record with a new recovery key for [dek]. The old one stops
  /// working once the returned record is saved with [save].
  Future<PendingRecoveryRotation> prepareRecoveryKeyRotation(
    Uint8List dek,
  ) async {
    final record = await load();
    _checkDek(record, dek);
    final recoveryKey = RecoveryKey.generate();
    final recoverySalt = secureRandomBytes(16);
    final kek = _recoveryKek(recoveryKey, recoverySalt);
    final recoveryNonce = AesGcm.randomNonce();
    final recoveryCiphertext = AesGcm.encrypt(
      key: kek,
      nonce: recoveryNonce,
      plaintext: dek,
      aad: _recoveryAad,
    );
    zeroBytes(kek);
    final recoveryKeyNonce = AesGcm.randomNonce();
    final recoveryKeyCiphertext = AesGcm.encrypt(
      key: dek,
      nonce: recoveryKeyNonce,
      plaintext: recoveryKey.bytes,
      aad: _recoveryKeyAad,
    );
    return PendingRecoveryRotation(
      record.copyWith(
        recoverySalt: recoverySalt,
        recoveryNonce: recoveryNonce,
        recoveryCiphertext: recoveryCiphertext,
        recoveryKeyNonce: recoveryKeyNonce,
        recoveryKeyCiphertext: recoveryKeyCiphertext,
      ),
      recoveryKey,
    );
  }

  Future<void> _rewrapPassword(
    VaultRecord record,
    Uint8List dek,
    String newPassword,
  ) async {
    final part = await _wrapWithPassword(dek, newPassword);
    await save(
      record.copyWith(
        passwordKdf: part.$1,
        passwordNonce: part.$2,
        passwordCiphertext: part.$3,
      ),
    );
  }

  Future<(KdfParams, Uint8List, Uint8List)> _wrapWithPassword(
    Uint8List dek,
    String password,
  ) async {
    final params = _newKdfParams();
    final kek = await deriveKey(password, params);
    try {
      final nonce = AesGcm.randomNonce();
      final ciphertext = AesGcm.encrypt(
        key: kek,
        nonce: nonce,
        plaintext: dek,
        aad: _passwordAadFor(params),
      );
      return (params, nonce, ciphertext);
    } finally {
      zeroBytes(kek);
    }
  }

  /// Confirms [dek] belongs to [record] (the recovery-key ciphertext is
  /// authenticated with it), so a stale key is never re-wrapped.
  void _checkDek(VaultRecord record, Uint8List dek) {
    _decryptRecoveryKey(record, dek).destroy();
  }

  RecoveryKey _decryptRecoveryKey(VaultRecord record, Uint8List dek) {
    try {
      final bytes = AesGcm.decrypt(
        key: dek,
        nonce: record.recoveryKeyNonce,
        ciphertext: record.recoveryKeyCiphertext,
        aad: _recoveryKeyAad,
      );
      return RecoveryKey.fromBytes(bytes);
    } on AeadAuthenticationException {
      throw const VaultCorruptException('data key does not match the vault');
    }
  }

  static Uint8List _recoveryKek(RecoveryKey key, Uint8List salt) =>
      hkdfSha256(ikm: key.bytes, salt: salt, info: _recoveryInfo);

  static Uint8List _passwordAadFor(KdfParams params) =>
      Uint8List.fromList([..._passwordAad, ...params.canonicalBytes()]);

  static Uint8List _ascii(String s) => Uint8List.fromList(utf8.encode(s));
}

class PendingRecoveryRotation {
  final VaultRecord record;
  final RecoveryKey recoveryKey;

  PendingRecoveryRotation(this.record, this.recoveryKey);
}
