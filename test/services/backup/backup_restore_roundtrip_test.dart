import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../database/generated_migrations/schema.dart';
import '../../domain/services/ledger_test_helpers.dart';
import '../../helpers/security_fakes.dart';
import '../../helpers/test_database.dart';

/// Opens/closes the live database like the providers do: a connection keyed
/// with the session key, on the real file.
class _FileLifecycle implements DatabaseLifecycle {
  final File file;
  final Uint8List key;
  AppDatabase? db;
  int failReopens = 0;

  _FileLifecycle(this.file, this.key);

  AppDatabase open() =>
      db = AppDatabase(openEncryptedConnection(key, file: file));

  @override
  Future<void> close() async {
    await db?.close();
    db = null;
  }

  @override
  Future<AppDatabase> reopen() async {
    if (failReopens > 0) {
      failReopens--;
      throw StateError('simulated failure after the swap');
    }
    return open();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Directory tempDir;
  late File liveFile;
  late Uint8List deviceKey;
  late _FileLifecycle lifecycle;
  late SharedPreferences prefs;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = Directory.systemTemp.createTempSync('lz_roundtrip_');
    tempDir = Directory('${dir.path}/tmp')..createSync();
    liveFile = File('${dir.path}/ledger_zero.db');
    deviceKey = secureRandomBytes(32);
    lifecycle = _FileLifecycle(liveFile, deviceKey);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await lifecycle.close();
    dir.deleteSync(recursive: true);
  });

  ExportFileService files() => ExportFileService(
    baseDirectory: () async => tempDir,
    deferDeletion: false,
  );

  BackupService backupService(AppDatabase db) =>
      BackupService(db, files: files(), kdf: fastKdf);

  RestoreService restoreService({Uint8List? key}) => RestoreService(
    () => lifecycle.db!,
    lifecycle: lifecycle,
    databaseFile: () async => liveFile,
    dataKey: () => key ?? deviceKey,
    rebootstrap: SyncRebootstrap(prefs),
    tempDirectory: () async => tempDir,
  );

  Future<void> addAccount(AppDatabase db, String id, String name) => db
      .into(db.accounts)
      .insert(AccountsCompanion.insert(id: id, name: name, type: 'checking'));

  bool containsPlaintext(File file, String text) =>
      latin1.decode(file.readAsBytesSync()).contains(text);

  test(
    'backup of the keyed database is a plain snapshot under the backup password',
    () async {
      final db = lifecycle.open();
      await addAccount(db, 'a1', 'Household Checking');

      final backup = await backupService(
        db,
      ).createBackup(password: 'backup pw');

      expect(backup.path, endsWith('.lzbk'));
      expect(containsPlaintext(backup, 'Household Checking'), isFalse);
      // No plaintext snapshot is left behind.
      final leftovers = tempDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => !f.path.endsWith('.lzbk'));
      expect(leftovers, isEmpty);
      expect(prefs.getInt('last_backup_timestamp'), isNull); // no scheduler

      // The decrypted content is a plain SQLite file (not one still keyed
      // with the device key, which `VACUUM INTO` would have produced).
      final out = File('${dir.path}/check.sqlite');
      await BackupFormat.decryptFile(
        input: backup,
        output: out,
        password: 'backup pw',
      );
      expect(
        ascii.decode(out.readAsBytesSync().sublist(0, 15)),
        'SQLite format 3',
      );
      final plain = sqlite.sqlite3.open(out.path);
      expect(
        plain.select('SELECT name FROM accounts').single['name'],
        'Household Checking',
      );
      expect(
        plain.select('PRAGMA user_version').single.values.first,
        AppDatabase.currentSchemaVersion,
      );
      plain.close();
    },
  );

  test(
    'restore replaces the data, keeps the file encrypted with the device key and marks sync for re-bootstrap',
    () async {
      var db = lifecycle.open();
      await addAccount(db, 'a1', 'Household Checking');
      final backup = await backupService(
        db,
      ).createBackup(password: 'backup pw');
      await addAccount(db, 'a2', 'Added After Backup');
      expect(
        (await db
                .customSelect('SELECT count(*) AS c FROM pending_sync_changes')
                .getSingle())
            .data['c'],
        greaterThan(0),
      );

      await restoreService().restoreBackup(backup, password: 'backup pw');

      db = lifecycle.db!;
      final accounts = await db.select(db.accounts).get();
      expect(accounts.map((a) => a.id), ['a1']);
      final pending = await db
          .customSelect('SELECT count(*) AS c FROM pending_sync_changes')
          .getSingle();
      expect(pending.data['c'], 0);
      expect(prefs.getBool(SyncRebootstrap.prefsKey), isTrue);

      await lifecycle.close();
      expect(
        ascii.decode(
          liveFile.readAsBytesSync().sublist(0, 15),
          allowInvalid: true,
        ),
        isNot('SQLite format 3'),
      );
      expect(SqlCipher.canOpen(liveFile, RawSqlCipherKey(deviceKey)), isTrue);
      expect(containsPlaintext(liveFile, 'Household Checking'), isFalse);
      // Exactly no previous copy and no staging file remain; temp is clean.
      expect(File('${liveFile.path}.previous').existsSync(), isFalse);
      expect(File('${liveFile.path}.restore-new').existsSync(), isFalse);
      expect(
        tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => !f.path.endsWith('.lzbk')),
        isEmpty,
      );
    },
  );

  test('a backup from another device restores into this device key', () async {
    // Made on device A with key A.
    final otherFile = File('${dir.path}/other.db');
    final otherDb = AppDatabase(
      openEncryptedConnection(secureRandomBytes(32), file: otherFile),
    );
    await addAccount(otherDb, 'x1', 'From Device A');
    final backup = await backupService(
      otherDb,
    ).createBackup(password: 'shared pw');
    await otherDb.close();

    // Restored on device B.
    final db = lifecycle.open();
    await addAccount(db, 'b1', 'Device B');
    await restoreService().restoreBackup(backup, password: 'shared pw');

    final restored = lifecycle.db!;
    expect(
      (await restored.select(restored.accounts).get()).map((a) => a.name),
      ['From Device A'],
    );
    await lifecycle.close();
    expect(SqlCipher.canOpen(liveFile, RawSqlCipherKey(deviceKey)), isTrue);
  });

  test('wrong password leaves the live database untouched', () async {
    final db = lifecycle.open();
    await addAccount(db, 'a1', 'Household Checking');
    final backup = await backupService(db).createBackup(password: 'backup pw');
    await addAccount(db, 'a2', 'Still Here');

    await expectLater(
      restoreService().restoreBackup(backup, password: 'wrong'),
      throwsA(isA<BackupAuthenticationException>()),
    );
    expect((await db.select(db.accounts).get()).length, 2);
  });

  test(
    'a failure after the swap rolls back to the previous database',
    () async {
      final db = lifecycle.open();
      await addAccount(db, 'a1', 'Household Checking');
      final backup = await backupService(
        db,
      ).createBackup(password: 'backup pw');
      await addAccount(db, 'a2', 'Kept By Rollback');

      lifecycle.failReopens = 1;
      await expectLater(
        restoreService().restoreBackup(backup, password: 'backup pw'),
        throwsA(isA<StateError>()),
      );

      final current = lifecycle.db!;
      expect((await current.select(current.accounts).get()).length, 2);
      expect(File('${liveFile.path}.previous').existsSync(), isFalse);
      expect(prefs.getBool(SyncRebootstrap.prefsKey), isNull);
    },
  );

  test('restores and migrates a backup with an older schema (v14)', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(14);
    final raw = schema.rawDatabase;
    raw.execute(
      'INSERT INTO accounts (id, name, type, currency, starting_balance, '
      'current_balance, is_closed) VALUES '
      "('old1', 'Old Account', 'checking', 'EUR', 12.5, 12.5, 0)",
    );
    final oldPlain = File('${dir.path}/old_v14.sqlite');
    raw.execute('VACUUM INTO ?', [oldPlain.path]);
    final backup = File('${dir.path}/old.lzbk');
    await BackupFormat.encryptFile(
      plaintext: oldPlain,
      output: backup,
      password: 'backup pw',
      schemaVersion: 14,
      kdf: fastKdf(),
    );

    lifecycle.open();
    await restoreService().restoreBackup(backup, password: 'backup pw');

    final db = lifecycle.db!;
    final account = await db.select(db.accounts).getSingle();
    expect(account.id, 'old1');
    expect(account.startingBalance, 1250); // REAL -> minor units (v15)
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, AppDatabase.currentSchemaVersion);
  });

  test('a backup from a newer schema is refused', () async {
    final plain = File('${dir.path}/newer.sqlite');
    final tmp = AppDatabase(NativeDatabase(plain));
    await tmp.select(tmp.accounts).get();
    await tmp.close();
    final raw = sqlite.sqlite3.open(plain.path)
      ..execute('PRAGMA user_version = 99');
    raw.close();
    final backup = File('${dir.path}/newer.lzbk');
    await BackupFormat.encryptFile(
      plaintext: plain,
      output: backup,
      password: 'backup pw',
      schemaVersion: 99,
      kdf: fastKdf(),
    );
    final db = lifecycle.open();
    await addAccount(db, 'a1', 'Untouched');
    await expectLater(
      restoreService().restoreBackup(backup, password: 'backup pw'),
      throwsA(isA<BackupTooNewException>()),
    );
    expect((await db.select(db.accounts).get()).single.id, 'a1');
  });

  test(
    'selective restore merges a date range from an encrypted backup',
    () async {
      final db = lifecycle.open();
      await addAccount(db, 'a1', 'Household Checking');
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 't-may',
              accountId: 'a1',
              date: DateTime.utc(2024, 5, 10),
              amount: -1250,
            ),
          );
      final backup = await backupService(
        db,
      ).createBackup(password: 'backup pw');
      await db.delete(db.transactions).go();

      await restoreService().selectiveRestore(
        backup,
        DateTime.utc(2024, 5, 1),
        DateTime.utc(2024, 5, 31),
        password: 'backup pw',
      );
      final txs = await db.select(db.transactions).get();
      expect(txs.single.id, 't-may');
    },
  );

  test('backup -> restore gives identical balances, budgets and TBB', () async {
    final live = TestDatabase.wrap(lifecycle.open());
    await seedSampleLedger(live);
    final before = await ledgerFingerprint(live, sampleLedgerMonth);
    final backup = await backupService(
      live.db,
    ).createBackup(password: 'backup pw');

    // Changes after the backup are undone by the restore.
    await live.addTransaction(
      accountId: (await live.accounts.getAllAccounts()).first.id,
      amount: -77700,
      date: DateTime.utc(2024, 3, 20),
    );
    expect(await ledgerFingerprint(live, sampleLedgerMonth), isNot(before));

    await restoreService().restoreBackup(backup, password: 'backup pw');

    final restored = TestDatabase.wrap(lifecycle.db!);
    expect(await ledgerFingerprint(restored, sampleLedgerMonth), before);
    await expectLedgerInvariant(restored, sampleLedgerMonth);
  });
}
