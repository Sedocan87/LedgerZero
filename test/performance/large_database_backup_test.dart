// Encrypted backup of a 10,000-transaction database within a generous time
// budget (KDF at test cost). Tagged `perf`.
@Tags(['perf'])
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';

import '../helpers/security_fakes.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' hide isNull;

void main() {
  late AppDatabase db;
  late BackupService backupService;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('ledger_zero_perf_test');

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Backup performance with 10k transactions', () async {
    // 1. Setup DB with data
    final file = File(p.join(tempDir.path, 'db.sqlite'));
    db = AppDatabase(NativeDatabase(file));

    // Insert 10k transactions
    await db.batch((batch) {
      // Create account
      batch.insert(
        db.accounts,
        AccountsCompanion.insert(
          id: 'acc_1',
          name: 'Test Account',
          type: 'checking',
        ),
      );

      for (int i = 0; i < 10000; i++) {
        batch.insert(
          db.transactions,
          TransactionsCompanion.insert(
            id: 'tx_$i',
            accountId: 'acc_1',
            date:
                DateTime.now(), // Drift automatically converts to string if column is Text
            amount: (i % 100) * 100,
            memo: Value('Transaction $i'),
          ),
        );
      }
    });

    // 2. Measure Backup
    // We need to mock getApplicationDocumentsDirectory to return tempDir
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return tempDir.path;
        });

    backupService = BackupService(
      db,
      files: ExportFileService(
        baseDirectory: () async => tempDir,
        deferDeletion: false,
      ),
      // Measures snapshot + compression + encryption, not the KDF.
      kdf: fastKdf,
    );

    final stopwatch = Stopwatch()..start();
    final backupFile = await backupService.createBackup(password: 'perf pw');
    stopwatch.stop();

    final size = await backupFile.length();

    expect(backupFile.existsSync(), true);
    expect(size, greaterThan(0));
    // Expect reasonable performance (e.g. < 5 seconds to be safe)
    expect(stopwatch.elapsedMilliseconds, lessThan(5000));
  });
}
