import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/delta_replay_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/services.dart';

@GenerateMocks([
  GoogleDriveService,
  ICloudDriveService,
  SharedPreferences,
  ConnectivityService,
  NotificationService
])
import 'sync_simulation_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock Package Info Channel
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), (call) async {
    if (call.method == 'getAll') {
      return {
        'appName': 'LedgerZero',
        'packageName': 'com.ledgerzero.app',
        'version': '1.0.0',
        'buildNumber': '1',
      };
    }
    return null;
  });

  // Mock Path Provider
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
    if (call.method == 'getTemporaryDirectory') {
      return Directory.systemTemp.path;
    }
    if (call.method == 'getApplicationDocumentsDirectory') {
      return Directory.systemTemp.path;
    }
    return null;
  });

  late MockGoogleDriveService mockDrive;
  late MockICloudDriveService mockICloud;

  // Simulated Cloud Storage
  final Map<String, List<int>> cloudStorage = {}; // id -> content
  final Map<String, String> cloudFilenames = {}; // id -> filename

  setUp(() {
    mockDrive = MockGoogleDriveService();
    mockICloud = MockICloudDriveService();

    cloudStorage.clear();
    cloudFilenames.clear();

    // Mock Drive listDeltas
    when(mockDrive.listDeltas()).thenAnswer((_) async {
      return cloudFilenames.entries.map((e) => drive.File(id: e.key, name: e.value)).toList();
    });

    // Mock Drive downloadDelta
    when(mockDrive.downloadDelta(any, any)).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      final savePath = invocation.positionalArguments[1] as String;
      final content = cloudStorage[id];
      if (content == null) throw Exception('File not found: $id');
      final file = File(savePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(content);
      return file;
    });

    // Mock Drive uploadDelta
    when(mockDrive.uploadDelta(any, any)).thenAnswer((invocation) async {
      final file = invocation.positionalArguments[0] as File;
      final filename = invocation.positionalArguments[1] as String;
      final id = const Uuid().v4();
      cloudStorage[id] = await file.readAsBytes();
      cloudFilenames[id] = filename;
      return id;
    });
  });

  Future<AppDatabase> createDb() async {
     final db = AppDatabase(NativeDatabase.memory());
     await db.customStatement('PRAGMA foreign_keys = ON');
     return db;
  }

  Future<SyncEngine> createRealStack(AppDatabase db, String deviceUuid) async {
     final devicePrefs = MockSharedPreferences();
     when(devicePrefs.getString('sync_provider')).thenReturn('googleDrive');
     when(devicePrefs.setString(any, any)).thenAnswer((_) async => true);
     when(devicePrefs.getInt(any)).thenReturn(0);
     when(devicePrefs.setInt(any, any)).thenAnswer((_) async => true);

     final tempDir = await Directory.systemTemp.createTemp('ledger_test_$deviceUuid');

     final queue = LocalDeltaQueue(DeltaFilenameGenerator(), tempDir);
     final deltaGen = DeltaGenerationService(db, queue, devicePrefs, deviceUuid: deviceUuid);
     final deltaReplay = DeltaReplayService(db, queue);

     final mockConnectivity = MockConnectivityService();
     when(mockConnectivity.isConnected).thenAnswer((_) async => true);
     when(mockConnectivity.connectionStatusStream).thenAnswer((_) => Stream.value(ConnectionStatus.online));

     final mockNotification = MockNotificationService();

     return SyncEngine(deltaGen, queue, deltaReplay, mockDrive, mockICloud, devicePrefs, mockConnectivity, mockNotification);
  }

  test('Task 456: Multi-device Sync', () async {
      final db1 = await createDb();
      final db2 = await createDb();
      final engine1 = await createRealStack(db1, 'device1');
      final engine2 = await createRealStack(db2, 'device2');

      await db1.into(db1.accounts).insert(AccountsCompanion.insert(id: 'acc1', name: 'Acc1', type: 'checking'));
      await db2.into(db2.accounts).insert(AccountsCompanion.insert(id: 'acc1', name: 'Acc1', type: 'checking'));

      // 1. Device 1 creates transaction
      await db1.into(db1.transactions).insert(
          TransactionsCompanion.insert(
              id: 'tx1',
              accountId: 'acc1',
              date: DateTime.now(),
              amount: 100.0,
          )
      );

      // 2. Sync Device 1
      await engine1.sync();

      // Verify upload
      expect(cloudStorage, isNotEmpty);

      // 3. Sync Device 2
      await engine2.sync();

      // 4. Verify Device 2 has transaction
      final tx2 = await db2.transactionsDao.getTransactionById('tx1');
      expect(tx2, isNotNull);
      expect(tx2!.amount, 100.0);

      await db1.close();
      await db2.close();
  });

  test('Task 457: Extended Offline Period', () async {
      final db1 = await createDb();
      final engine1 = await createRealStack(db1, 'device1');
      final db2 = await createDb();
      final engine2 = await createRealStack(db2, 'device2');

      // Device 1 creates 10 changes (simulating activity over time)
      for (int i=0; i<10; i++) {
          await db1.into(db1.accounts).insert(AccountsCompanion.insert(id: 'acc_$i', name: 'Acc $i', type: 'checking'));
          await engine1.sync();
      }

      // Device 2 (offline until now) syncs
      await engine2.sync();

      // Verify Device 2 has all 10 accounts
      final count = (await db2.select(db2.accounts).get()).length;
      expect(count, 10);

      await db1.close();
      await db2.close();
  });

  test('Task 458: Sync Conflict Resolution', () async {
      final db1 = await createDb();
      final db2 = await createDb();
      final engine1 = await createRealStack(db1, 'deviceA');
      final engine2 = await createRealStack(db2, 'deviceB');

      await db1.into(db1.accounts).insert(AccountsCompanion.insert(id: 'acc1', name: 'Acc1', type: 'checking'));
      await db2.into(db2.accounts).insert(AccountsCompanion.insert(id: 'acc1', name: 'Acc1', type: 'checking'));

      // Initial state: tx1 exists
      await db1.into(db1.transactions).insert(
          TransactionsCompanion.insert(id: 'tx1', accountId: 'acc1', date: DateTime.now(), amount: 100.0));
      await engine1.sync();
      await engine2.sync(); // B gets tx1

      // A updates tx1 -> 200
      await db1.update(db1.transactions).replace(
         (await db1.transactionsDao.getTransactionById('tx1'))!.copyWith(amount: 200.0)
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // B updates tx1 -> 300 (before syncing A's change)
      await db2.update(db2.transactions).replace(
         (await db2.transactionsDao.getTransactionById('tx1'))!.copyWith(
             amount: 300.0,
             updatedAt: Value(DateTime.now().toUtc())
         )
      );

      // A Syncs (uploads 200)
      await engine1.sync();

      // B Syncs (downloads 200, but has local pending 300)
      // Expectation: B ignores 200 (LWW/Local-Priority), keeps 300, and uploads 300.
      await engine2.sync();

      final txB = await db2.transactionsDao.getTransactionById('tx1');
      expect(txB!.amount, 300.0);

      // A Syncs again (downloads 300)
      await engine1.sync();

      final txA = await db1.transactionsDao.getTransactionById('tx1');
      expect(txA!.amount, 300.0);

      await db1.close();
      await db2.close();
  });

  test('Task 451/452: Full Sync vs Incremental', () async {
      final db1 = await createDb();
      final engine1 = await createRealStack(db1, 'device1');

      await db1.into(db1.accounts).insert(AccountsCompanion.insert(id: 'acc1', name: 'Acc1', type: 'checking'));
      await db1.into(db1.transactions).insert(TransactionsCompanion.insert(id: 'tx1', accountId: 'acc1', date: DateTime.now(), amount: 100.0));
      await engine1.sync();

      // Create new device
      final db2 = await createDb();
      final engine2 = await createRealStack(db2, 'device2');

      // 1. Initial Sync (Incremental/First time)
      await engine2.sync();
      expect(await db2.transactionsDao.getTransactionById('tx1'), isNotNull);

      // 2. Add more data
      await db1.into(db1.transactions).insert(TransactionsCompanion.insert(id: 'tx2', accountId: 'acc1', date: DateTime.now(), amount: 200.0));
      await engine1.sync();

      // 3. Full Sync Device 2
      // Should re-process tx1 (but insertOnConflictUpdate handles it) and process tx2.
      await engine2.sync(forceFullSync: true);
      expect(await db2.transactionsDao.getTransactionById('tx2'), isNotNull);

      await db1.close();
      await db2.close();
  });
}
