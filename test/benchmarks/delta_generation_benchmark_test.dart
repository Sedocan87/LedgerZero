import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'delta_generation_benchmark_test.mocks.dart';

@GenerateMocks([LocalDeltaQueue, SharedPreferences])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockLocalDeltaQueue mockQueue;
  late MockSharedPreferences mockPrefs;
  late DeltaGenerationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'LedgerZero',
      packageName: 'com.ledgerzero.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');

    mockQueue = MockLocalDeltaQueue();
    mockPrefs = MockSharedPreferences();

    when(mockPrefs.getInt(any)).thenReturn(0);
    when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
    when(mockQueue.enqueue(any)).thenAnswer((invocation) async {
        return File('dummy_${const Uuid().v4()}.json.gz');
    });

    service = DeltaGenerationService(db, mockQueue, mockPrefs);
  });

  tearDown(() async {
    await db.close();
  });

  test('Benchmark: Generate 1000 deltas', () async {
    const count = 1000;

    // 1. Insert 1000 transactions
    final accounts = <AccountsCompanion>[];
    for (var i = 0; i < count; i++) {
        accounts.add(AccountsCompanion.insert(
            id: const Uuid().v4(),
            name: 'Account $i',
            type: 'checking',
            createdAt: Value(DateTime.now()),
        ));
    }

    await db.batch((batch) {
        batch.insertAll(db.accounts, accounts);
    });

    final stopwatch = Stopwatch()..start();
    await service.processPendingChanges();
    stopwatch.stop();

    // print('Processed $count INSERTs in ${stopwatch.elapsedMilliseconds}ms');

    // Verify
    verify(mockQueue.enqueue(any)).called(count);
  });
}
