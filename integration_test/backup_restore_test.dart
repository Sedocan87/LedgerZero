import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:ledger_zero/data/database/database.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Task 803: Test backup and restore flows
// This integration test verifies that we can create a backup and restore it.
// We use a file-based database for this test to allow restoration.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Backup and Restore Integration Test (File-based)', (WidgetTester tester) async {
    // 1. Setup file-based DB
    final tempDir = await Directory.systemTemp.createTemp('lz_backup_test');
    final dbFile = File(p.join(tempDir.path, 'db.sqlite'));
    final db = AppDatabase(NativeDatabase(dbFile));

    // Clear prefs
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    AppConfig(
      environment: AppEnvironment.development,
      appTitle: 'LedgerZero Test',
      enableLogging: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          databaseProvider.overrideWithValue(db),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Insert Data
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc_backup_test',
        name: 'Backup Test Account',
        type: 'checking',
      ),
    );

    // 3. Create Backup
    final backupService = BackupService(db);
    const password = 'integration_test_password';
    final backupFile = await backupService.createBackup(password: password);

    expect(backupFile.existsSync(), true, reason: 'Backup file should exist');
    expect(backupFile.lengthSync() > 0, true, reason: 'Backup file should not be empty');

    // 4. Clear Data (Simulate loss)
    await db.close();

    // Delete the original DB file to simulate total loss
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }

    // 5. Restore
    // Instantiate RestoreService with a new DB connection pointing to the same file path (which is empty/deleted now)
    // Note: RestoreService usually takes the *current* DB instance to close it/checkpoint it.
    // Since we manually closed `db` above, we can pass a new instance or the old one.
    // Ideally we pass a new one that isn't opened yet? Or one that is open?
    // RestoreService logic usually is: Close DB -> Overwrite File -> Open DB.
    // We will verify the *Overwrite* part here.

    final dbForRestore = AppDatabase(NativeDatabase(dbFile));
    final restoreService = RestoreService(dbForRestore);

    // We expect this to succeed. If it fails, the test should fail.
    await restoreService.restoreBackup(backupFile, password: password);

    // 6. Verify Data Restored
    // Open DB again
    final dbRestored = AppDatabase(NativeDatabase(dbFile));
    final accounts = await dbRestored.select(dbRestored.accounts).get();

    expect(accounts.length, 1, reason: 'Account should be restored');
    expect(accounts.first.name, 'Backup Test Account');

    await dbRestored.close();

    // Cleanup
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });
}
