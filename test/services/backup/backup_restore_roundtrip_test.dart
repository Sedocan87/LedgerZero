import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' hide isNull;

void main() {
  late AppDatabase db;
  late BackupService backupService;
  late RestoreService restoreService;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('ledger_zero_restore_test');

    // Mock path_provider
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
       await tempDir.delete(recursive: true);
    }
  });

  test('Backup and Restore Roundtrip (Encrypted + Compressed)', () async {
    // 1. Setup DB with data
    final file = File(p.join(tempDir.path, 'db_source.sqlite'));
    db = AppDatabase(NativeDatabase(file));

    // Insert some data
    await db.into(db.accounts).insert(
       AccountsCompanion.insert(id: 'acc_1', name: 'Source Account', type: 'checking')
    );
    await db.into(db.transactions).insert(
       TransactionsCompanion.insert(
         id: 'tx_1',
         accountId: 'acc_1',
         date: DateTime.now(),
         amount: 100.0,
         memo: Value('Original Transaction')
       )
    );

    // 2. Create Backup
    backupService = BackupService(db);
    final backupFile = await backupService.createBackup(password: 'secret123');

    expect(backupFile.existsSync(), true);
    expect(backupFile.path.endsWith('.lzbk'), true);

    // 3. Restore to a new DB location
    // RestoreService typically overwrites the main DB file.
    // In this test environment, we need to be careful.
    // RestoreService uses `getApplicationDocumentsDirectory` to find the target.
    // We mocked it to `tempDir`. So it will try to overwrite `db.sqlite` (or whatever `AppConstants.databaseFilename` is).
    // Let's assume `AppConstants.databaseFilename` is 'db.sqlite'.

    // We need to close the original DB first if it's pointing to the same file.
    // But here `db` points to `db_source.sqlite`.
    // RestoreService will write to `tempDir/db.sqlite` (default name).

    restoreService = RestoreService(db); // It takes a DB instance but uses file ops internally

    await restoreService.restoreBackup(backupFile, password: 'secret123');

    // 4. Verify Restored Data
    // Open the restored file
    final restoredFile = File(p.join(tempDir.path, 'db.sqlite'));
    expect(restoredFile.existsSync(), true);

    final restoredDb = AppDatabase(NativeDatabase(restoredFile));

    final accounts = await restoredDb.select(restoredDb.accounts).get();
    expect(accounts.length, 1);
    expect(accounts.first.name, 'Source Account');

    final transactions = await restoredDb.select(restoredDb.transactions).get();
    expect(transactions.length, 1);
    expect(transactions.first.memo, 'Original Transaction');

    await restoredDb.close();
  });
}
