import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'delta_generation_test.mocks.dart';

@GenerateMocks([LocalDeltaQueue, SharedPreferences])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Ensure binding for SharedPreferences

  late AppDatabase db;
  late MockLocalDeltaQueue mockQueue;
  late MockSharedPreferences mockPrefs;
  late DeltaGenerationService service;

  setUp(() async {
    // Setup SharedPreferences for DeviceUtils
    SharedPreferences.setMockInitialValues({});

    // Setup PackageInfo mock
    PackageInfo.setMockInitialValues(
      appName: 'LedgerZero',
      packageName: 'com.ledgerzero.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    // Setup DB
    db = AppDatabase(NativeDatabase.memory());
    // Ensure triggers are created (migration calls onCreate)
    // We force migration to run by querying something or opening connection
    await db.customStatement('PRAGMA foreign_keys = ON');

    // Setup Mocks
    mockQueue = MockLocalDeltaQueue();
    mockPrefs = MockSharedPreferences();

    // Mock Sequence
    when(mockPrefs.getInt(any)).thenReturn(0);
    when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
    when(mockQueue.enqueue(any)).thenAnswer((_) async => File('dummy_path'));

    service = DeltaGenerationService(db, mockQueue, mockPrefs);
  });

  tearDown(() async {
    await db.close();
  });

  group('DeltaGenerationService', () {
    test('INSERT generates insert delta', () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );

      await service.processPendingChanges();

      verify(mockQueue.enqueue(argThat(predicate<SyncDelta>((delta) {
        return delta.action == SyncAction.insert &&
            delta.tableName == 'accounts' &&
            delta.data!['id'] == accountId &&
            delta.data!['name'] == 'Test Account';
      })))).called(1);
    });

    test('UPDATE generates update delta', () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );

      // Clear initial insert delta from queue (simulating it was already processed)
      await db.pendingSyncChangesDao.deleteChange(1); // Assuming ID 1

      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: const Value('Updated Account'),
          type: const Value('checking'), // Required
        ),
      );

      await service.processPendingChanges();

      verify(mockQueue.enqueue(argThat(predicate<SyncDelta>((delta) {
        return delta.action == SyncAction.update &&
            delta.tableName == 'accounts' &&
            delta.data!['id'] == accountId &&
            delta.data!['name'] == 'Updated Account';
      })))).called(1);
    });

    test('DELETE generates delete delta', () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );

      // Clear insert delta
      await db.customStatement('DELETE FROM pending_sync_changes');

      await db.accountsDao.deleteAccount(accountId);

      await service.processPendingChanges();

      verify(mockQueue.enqueue(argThat(predicate<SyncDelta>((delta) {
        return delta.action == SyncAction.delete &&
            delta.tableName == 'accounts' &&
            delta.data!['id'] == accountId;
      })))).called(1);
    });

    test('Squashing: INSERT + UPDATE -> INSERT', () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );

      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: const Value('Updated Account'),
          type: const Value('checking'), // Required
        ),
      );

      await service.processPendingChanges();

      // Should generate only 1 delta: INSERT with the updated name
      verify(mockQueue.enqueue(argThat(predicate<SyncDelta>((delta) {
        return delta.action == SyncAction.insert &&
            delta.tableName == 'accounts' &&
            delta.data!['id'] == accountId &&
            delta.data!['name'] == 'Updated Account';
      })))).called(1);
    });

    test('Squashing: UPDATE + DELETE -> DELETE', () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );

      // Clear insert
      await db.customStatement('DELETE FROM pending_sync_changes');

      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: const Value('Updated Account'),
          type: const Value('checking'), // Required
        ),
      );

      await db.accountsDao.deleteAccount(accountId);

      await service.processPendingChanges();

      // Should generate only 1 delta: DELETE
      verify(mockQueue.enqueue(argThat(predicate<SyncDelta>((delta) {
        return delta.action == SyncAction.delete &&
            delta.tableName == 'accounts' &&
            delta.data!['id'] == accountId;
      })))).called(1);
    });

    test('Squashing: INSERT + DELETE -> NO OP', () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );

      await db.accountsDao.deleteAccount(accountId);

      await service.processPendingChanges();

      // Should generate NO deltas
      verifyNever(mockQueue.enqueue(any));
    });

    test('Squashing: UPDATE + UPDATE -> UPDATE', () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );

      // Clear insert
      await db.customStatement('DELETE FROM pending_sync_changes');

      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: const Value('Updated 1'),
          type: const Value('checking'), // Required
        ),
      );

      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: const Value('Updated 2'),
          type: const Value('checking'), // Required
        ),
      );

      await service.processPendingChanges();

      // Should generate only 1 delta: UPDATE with latest name
      verify(mockQueue.enqueue(argThat(predicate<SyncDelta>((delta) {
        return delta.action == SyncAction.update &&
            delta.tableName == 'accounts' &&
            delta.data!['id'] == accountId &&
            delta.data!['name'] == 'Updated 2';
      })))).called(1);
    });
  });
}
