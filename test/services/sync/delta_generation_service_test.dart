import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'delta_generation_service_test.mocks.dart';

@GenerateMocks([LocalDeltaQueue])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MockLocalDeltaQueue mockQueue;
  late DeltaGenerationService service;

  setUp(() async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    db = AppDatabase(NativeDatabase.memory());
    mockQueue = MockLocalDeltaQueue();
    service = DeltaGenerationService(db, mockQueue, prefs);

    // Mock PackageInfo
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'LedgerZero',
          'packageName': 'com.ledgerzero.app',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });

    // Allow enqueue to return a dummy file with unique name
    var seq = 0;
    when(mockQueue.enqueue(any)).thenAnswer((_) async {
      seq++;
      return File('dummy_$seq');
    });
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), null);
  });

  test('processPendingChanges squashes INSERT then UPDATE', () async {
    // Insert a category
    const catId = 'cat1';

    // We need to create a group first to satisfy FK
    await db.categoryGroups.insertOne(CategoryGroupsCompanion.insert(
        id: 'group1', name: 'Group', createdAt: Value(DateTime.now())));

    // Insert category
    await db.categories.insertOne(CategoriesCompanion.insert(
      id: catId,
      name: 'Test Category',
      categoryGroupId: const Value('group1'),
      createdAt: Value(DateTime.now()),
    ));

    // Update the category
    await (db.update(db.categories)..where((t) => t.id.equals(catId)))
        .write(const CategoriesCompanion(
      name: Value('Updated Name'),
    ));

    // Now we should have 2 pending changes for cat1: INSERT, then UPDATE.
    // Also one for group1 (INSERT).

    final changes = await db.pendingSyncChangesDao.getPendingChanges();
    expect(changes.length, 3); // Group INSERT, Cat INSERT, Cat UPDATE

    // Run service
    await service.processPendingChanges();

    // Verify squashing for Category
    // We expect 1 delta for Group (INSERT)
    // We expect 1 delta for Category (INSERT with Updated Name) because first action was INSERT.

    final captured = verify(mockQueue.enqueue(captureAny)).captured;
    expect(captured.length, 2);

    // Sort captured by tableName to be deterministic
    captured.sort((a, b) => (a as SyncDelta).tableName.compareTo((b as SyncDelta).tableName));

    final catDelta = captured.firstWhere((d) => (d as SyncDelta).tableName == 'categories') as SyncDelta;
    expect(catDelta.action, SyncAction.insert);
    expect(catDelta.data!['name'], 'Updated Name');
    expect(catDelta.appVersion, '1.0.0');
    expect(catDelta.schemaVersion, 11);
    expect(catDelta.checksum, isNotNull);
    expect(catDelta.verifyChecksum(), isTrue);

    final groupDelta = captured.firstWhere((d) => (d as SyncDelta).tableName == 'category_groups') as SyncDelta;
    expect(groupDelta.action, SyncAction.insert);
    expect(groupDelta.checksum, isNotNull);
    expect(groupDelta.verifyChecksum(), isTrue);

    // Verify pending changes cleared
    expect(await db.pendingSyncChangesDao.getPendingChanges(), isEmpty);
  });

  test('processPendingChanges squashes INSERT then DELETE', () async {
    // Create group
    await db.categoryGroups.insertOne(CategoryGroupsCompanion.insert(
        id: 'group1', name: 'Group', createdAt: Value(DateTime.now())));

    // Delete group
    await db.categoryGroups.deleteWhere((tbl) => tbl.id.equals('group1'));

    // Pending changes: INSERT, DELETE

    await service.processPendingChanges();

    // Should result in NO delta for this group
    verifyNever(mockQueue.enqueue(any));

    expect(await db.pendingSyncChangesDao.getPendingChanges(), isEmpty);
  });

  test('processPendingChanges squashes UPDATE then DELETE', () async {
    // Manually insert pending changes to simulate existing record state

    // Insert initial data (this creates an INSERT pending change)
    await db.categoryGroups.insertOne(CategoryGroupsCompanion.insert(
        id: 'group1', name: 'Group', createdAt: Value(DateTime.now())));

    // Clear the INSERT pending change to simulate it was already synced
    final changes = await db.pendingSyncChangesDao.getPendingChanges();
    await db.pendingSyncChangesDao.deleteChange(changes.first.id);

    // Update (Creates UPDATE pending change)
    await (db.update(db.categoryGroups)..where((t) => t.id.equals('group1')))
        .write(const CategoryGroupsCompanion(
      name: Value('Updated'),
    ));

    // Delete (Creates DELETE pending change)
    await db.categoryGroups.deleteWhere((tbl) => tbl.id.equals('group1'));

    await service.processPendingChanges();

    // Expect 1 delta: DELETE
    final captured = verify(mockQueue.enqueue(captureAny)).captured;
    expect(captured.length, 1);
    final delta = captured.first as SyncDelta;
    expect(delta.action, SyncAction.delete);
    expect(delta.tableName, 'category_groups');
  });
}
