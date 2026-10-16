import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/legacy_key_material.dart';
import 'package:ledger_zero/services/security/unlock_service.dart';
import 'package:pointycastle/export.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../helpers/security_fakes.dart';

// These tests run against the real SQLCipher library: `flutter test` builds
// the sqlite3 package's native asset with `source: sqlcipher` from
// pubspec.yaml (asserted below).

String _legacyPassphrase(String password, String salt) {
  final d = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(Uint8List.fromList(utf8.encode(salt)), 100000, 32));
  return base64Url.encode(d.process(Uint8List.fromList(utf8.encode(password))));
}

String _legacyVerifier(String passphrase) => base64Url.encode(
  SHA256Digest().process(Uint8List.fromList(utf8.encode(passphrase))),
);

void main() {
  late Directory dir;
  late File dbFile;
  late InMemorySecureStore currentStore;
  late InMemorySecureStore legacyStore;
  late FakeBiometricKeyStore biometrics;
  late KeyVault vault;
  late UnlockService service;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lz_unlock_');
    dbFile = File('${dir.path}/ledger_zero.db');
    currentStore = InMemorySecureStore();
    legacyStore = InMemorySecureStore();
    biometrics = FakeBiometricKeyStore();
    vault = KeyVault(currentStore, newKdfParams: fastKdf);
    service = UnlockService(
      vault: vault,
      legacy: LegacyKeyMaterial(legacyStore),
      biometrics: biometrics,
      databaseFile: () async => dbFile,
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  void createDatabase(SqlCipherKey key, {String secret = 'Rent 1250'}) {
    final db = sqlite.sqlite3.open(dbFile.path);
    try {
      SqlCipher.applyKey(db, key);
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('CREATE TABLE notes (text TEXT)');
      db.execute('INSERT INTO notes VALUES (?)', [secret]);
      db.execute('PRAGMA user_version = 16');
    } finally {
      db.close();
    }
  }

  List<String> readNotes(SqlCipherKey key) {
    final db = sqlite.sqlite3.open(dbFile.path);
    try {
      SqlCipher.applyKey(db, key);
      return db
          .select('SELECT text FROM notes')
          .map((r) => r['text'] as String)
          .toList();
    } finally {
      db.close();
    }
  }

  test('the test environment links SQLCipher', () {
    final db = sqlite.sqlite3.openInMemory();
    expect(SqlCipher.isAvailable(db), isTrue);
    db.close();
  });

  group('current vault', () {
    test('password unlock returns the key that opens the database', () async {
      final pending = await vault.build('master password');
      await vault.save(pending.record);
      createDatabase(RawSqlCipherKey(pending.dek));

      final result = await service.unlockWithPassword('master password');
      expect(result.dek, pending.dek);
      expect(result.newRecoveryKey, isNull);
      expect(readNotes(RawSqlCipherKey(result.dek)), ['Rent 1250']);
    });

    test('a key that does not open the database fails closed', () async {
      final pending = await vault.build('master password');
      await vault.save(pending.record);
      createDatabase(RawSqlCipherKey(Uint8List(32)..[0] = 7));

      expect(
        () => service.unlockWithPassword('master password'),
        throwsA(isA<DatabaseKeyException>()),
      );
    });

    test('recovery-key unlock opens the same database', () async {
      final pending = await vault.build('master password');
      await vault.save(pending.record);
      createDatabase(RawSqlCipherKey(pending.dek));

      final dek = await service.unlockWithRecoveryKey(
        pending.recoveryKey.format(),
      );
      expect(readNotes(RawSqlCipherKey(dek)), ['Rent 1250']);
    });

    test('biometric unlock returns the key; invalidation removes it', () async {
      final pending = await vault.build('master password');
      await vault.save(pending.record);
      biometrics.secret = Uint8List.fromList(pending.dek);

      expect(await service.unlockWithBiometrics(testPromptTexts), pending.dek);

      biometrics.failNextReadWith = BiometricFailure.invalidated;
      await expectLater(
        service.unlockWithBiometrics(testPromptTexts),
        throwsA(isA<BiometricException>()),
      );
      expect(await biometrics.hasKey(), isFalse);
    });

    test(
      'a biometric key from an older vault is rejected and removed',
      () async {
        final pending = await vault.build('master password');
        await vault.save(pending.record);
        biometrics.secret = Uint8List(32);

        await expectLater(
          service.unlockWithBiometrics(testPromptTexts),
          throwsA(
            isA<BiometricException>().having(
              (e) => e.failure,
              'failure',
              BiometricFailure.invalidated,
            ),
          ),
        );
        expect(await biometrics.hasKey(), isFalse);
      },
    );

    test('no key material at all', () async {
      expect(await service.isSetUp(), isFalse);
      expect(
        () => service.unlockWithPassword('x'),
        throwsA(isA<VaultMissingException>()),
      );
    });
  });

  group('legacy migration', () {
    const password = 'legacy password';
    const salt = 'c2FsdC1mcm9tLW9sZC1pbnN0YWxs';
    late String passphrase;

    setUp(() {
      passphrase = _legacyPassphrase(password, salt);
      legacyStore.values.addAll({
        LegacyKeyMaterial.saltEntry: salt,
        LegacyKeyMaterial.verifierEntry: _legacyVerifier(passphrase),
        // The old design stored the raw key for biometrics.
        LegacyKeyMaterial.keyEntry: passphrase,
      });
      createDatabase(LegacyPassphraseKey(passphrase));
    });

    test(
      'first password login re-keys to a random key and drops legacy data',
      () async {
        final result = await service.unlockWithPassword(password);

        expect(result.dek.length, 32);
        expect(result.newRecoveryKey, isNotNull);
        expect(result.biometricsWereReset, isTrue);
        // The database now opens only with the new raw key.
        expect(readNotes(RawSqlCipherKey(result.dek)), ['Rent 1250']);
        expect(
          SqlCipher.canOpen(dbFile, LegacyPassphraseKey(passphrase)),
          isFalse,
        );
        // Legacy entries (salt, verifier, plaintext biometric key) are gone.
        expect(legacyStore.values, isEmpty);
        final record = await vault.load();
        expect(record.legacyMigrationPending, isFalse);
        // The shown recovery key works, and so does the password.
        expect(
          await vault.unlockWithRecoveryKey(result.newRecoveryKey!.format()),
          result.dek,
        );
        expect((await service.unlockWithPassword(password)).dek, result.dek);
      },
    );

    test('wrong password changes nothing', () async {
      await expectLater(
        service.unlockWithPassword('not the password'),
        throwsA(isA<WrongPasswordException>()),
      );
      expect(await vault.exists(), isFalse);
      expect(legacyStore.values, hasLength(3));
      expect(readNotes(LegacyPassphraseKey(passphrase)), ['Rent 1250']);
    });

    test(
      'crash after writing the pending vault, before re-key, is completed at next login',
      () async {
        final pending = await vault.build(
          password,
          legacyMigrationPending: true,
        );
        await vault.save(pending.record);
        // (process dies here: database still has the legacy key)

        final result = await service.unlockWithPassword(password);
        expect(result.dek, pending.dek);
        expect(result.newRecoveryKey!.format(), pending.recoveryKey.format());
        expect(readNotes(RawSqlCipherKey(pending.dek)), ['Rent 1250']);
        expect(legacyStore.values, isEmpty);
        expect((await vault.load()).legacyMigrationPending, isFalse);
      },
    );

    test(
      'crash after re-key, before clearing the marker, is completed at next login',
      () async {
        final pending = await vault.build(
          password,
          legacyMigrationPending: true,
        );
        await vault.save(pending.record);
        SqlCipher.rekey(
          dbFile,
          LegacyPassphraseKey(passphrase),
          RawSqlCipherKey(pending.dek),
        );
        // (process dies here)

        final result = await service.unlockWithPassword(password);
        expect(result.dek, pending.dek);
        expect(readNotes(RawSqlCipherKey(pending.dek)), ['Rent 1250']);
        expect(legacyStore.values, isEmpty);
      },
    );

    test(
      'recovery key cannot be used while the migration is pending',
      () async {
        final pending = await vault.build(
          password,
          legacyMigrationPending: true,
        );
        await vault.save(pending.record);
        expect(
          () => service.unlockWithRecoveryKey(pending.recoveryKey.format()),
          throwsA(isA<LegacyMigrationPendingException>()),
        );
      },
    );
  });
}
