import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:mockito/mockito.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

// Mock dependencies
class MockLocalDeltaQueue extends Mock implements LocalDeltaQueue {
  @override
  Future<File> enqueue(SyncDelta? delta) {
    return super.noSuchMethod(
      Invocation.method(#enqueue, [delta]),
      returnValue: Future.value(File('test_delta.json.gz')),
      returnValueForMissingStub: Future.value(File('test_delta.json.gz')),
    );
  }
}

void main() {
  late AppDatabase database;
  late MockLocalDeltaQueue mockLocalDeltaQueue;
  late DeltaGenerationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'last_delta_sequence': 0});
    PackageInfo.setMockInitialValues(
      appName: 'LedgerZero',
      packageName: 'com.ledgerzero.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    database = AppDatabase(NativeDatabase.memory());
    mockLocalDeltaQueue = MockLocalDeltaQueue();
    final prefs = await SharedPreferences.getInstance();

    service = DeltaGenerationService(
      database,
      mockLocalDeltaQueue,
      prefs,
      deviceUuid: 'test-device-uuid'
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('DeltaGenerationService', () {
    test('INSERT action generates correct delta', () async {
      // 1. Simulate an INSERT change
      const id = 'test-id-1';
      await database.accounts.insertOne(AccountsCompanion.insert(
        id: id,
        name: 'Test Account',
        type: 'checking',
      ));

      final pending = await database.pendingSyncChangesDao.getPendingChanges();
      expect(pending.isNotEmpty, isTrue);

      // 2. Run processing
      await service.processPendingChanges();

      // 3. Verify
      final syncLogs = await database.syncLogDao.getAllFilenames();
      expect(syncLogs.length, equals(1));

      verify(mockLocalDeltaQueue.enqueue(argThat(
        predicate<SyncDelta>((delta) {
          return delta.action == SyncAction.insert &&
                 delta.tableName == 'accounts' &&
                 delta.data!['id'] == id &&
                 delta.data!['name'] == 'Test Account';
        })
      ))).called(1);
    });

    test('UPDATE action generates correct delta', () async {
      const id = 'test-id-2';
      await database.accounts.insertOne(AccountsCompanion.insert(
        id: id,
        name: 'Original Name',
        type: 'checking',
      ));

      // Clear initial insert pending change
      await database.pendingSyncChangesDao.customStatement('DELETE FROM pending_sync_changes');

      // Update
      await database.accounts.update().replace(
        const AccountsCompanion(
           id: Value(id),
           name: Value('Updated Name'),
           type: Value('checking'),
           currency: Value('USD'),
           startingBalance: Value(0.0),
           currentBalance: Value(0.0),
           isClosed: Value(false),
        )
      );

      await service.processPendingChanges();

      verify(mockLocalDeltaQueue.enqueue(argThat(
        predicate<SyncDelta>((delta) {
          return delta.action == SyncAction.update &&
                 delta.tableName == 'accounts' &&
                 delta.data!['name'] == 'Updated Name';
        })
      ))).called(1);
    });

    test('DELETE action generates correct delta', () async {
      const id = 'test-id-3';
      await database.accounts.insertOne(AccountsCompanion.insert(
        id: id,
        name: 'To Delete',
        type: 'checking',
      ));

      await database.pendingSyncChangesDao.customStatement('DELETE FROM pending_sync_changes');

      await database.accounts.deleteWhere((tbl) => tbl.id.equals(id));

      await service.processPendingChanges();

      verify(mockLocalDeltaQueue.enqueue(argThat(
        predicate<SyncDelta>((delta) {
          return delta.action == SyncAction.delete &&
                 delta.tableName == 'accounts' &&
                 delta.data!['id'] == id;
        })
      ))).called(1);
    });

    test('Squashes INSERT + UPDATE into INSERT', () async {
       const id = 'test-id-4';

       // Insert
       await database.accounts.insertOne(AccountsCompanion.insert(
        id: id,
        name: 'Initial',
        type: 'checking',
      ));

       // Update immediately
       await database.accounts.update().replace(
         const AccountsCompanion(
           id: Value(id),
           name: Value('Updated'),
           type: Value('checking'),
           currency: Value('USD'),
           startingBalance: Value(0.0),
           currentBalance: Value(0.0),
           isClosed: Value(false),
         )
       );

       await service.processPendingChanges();

       verify(mockLocalDeltaQueue.enqueue(argThat(
        predicate<SyncDelta>((delta) {
          return delta.action == SyncAction.insert &&
                 delta.tableName == 'accounts' &&
                 delta.data!['name'] == 'Updated';
        })
      ))).called(1);
    });

    test('Squashes INSERT + DELETE into Nothing', () async {
       const id = 'test-id-5';

       // Insert
       await database.accounts.insertOne(AccountsCompanion.insert(
        id: id,
        name: 'Ephemeral',
        type: 'checking',
      ));

       // Delete immediately
       await database.accounts.deleteWhere((tbl) => tbl.id.equals(id));

       await service.processPendingChanges();

       // Should generate NO deltas
       verifyNever(mockLocalDeltaQueue.enqueue(any));
    });
  });
}
