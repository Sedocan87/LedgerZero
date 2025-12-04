
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:mockito/mockito.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

import '../mocks/service_mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late LocalDeltaQueue localDeltaQueue;
  late DeltaGenerationService deltaGenService;
  late SyncEngine syncEngine;

  late MockGoogleDriveService mockGoogleDriveService;
  late MockICloudDriveService mockICloudDriveService;
  late MockSharedPreferences mockPrefs;
  late MockConnectivityService mockConnectivityService;
  late MockNotificationService mockNotificationService;
  late MockDeltaReplayService mockDeltaReplayService;

  setUp(() async {
    // Mock Path Provider for getTemporaryDirectory calls inside SyncEngine
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
      return '.';
    });

    // Mock PackageInfo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (MethodCall methodCall) async {
      return {
        'appName': 'LedgerZero',
        'packageName': 'com.ledgerzero.app',
        'version': '1.0.0',
        'buildNumber': '1',
        'buildSignature': '',
      };
    });

    tempDir = await Directory.systemTemp.createTemp('offline_sync_test');
    db = AppDatabase(NativeDatabase.memory());

    // Use REAL LocalDeltaQueue with temp dir
    localDeltaQueue = LocalDeltaQueue(DeltaFilenameGenerator(), tempDir);

    mockPrefs = MockSharedPreferences();
    // Default prefs
    when(mockPrefs.getInt(any)).thenReturn(0);
    when(mockPrefs.getString('sync_provider')).thenReturn('googleDrive');
    when(mockPrefs.getBool('sync_on_wifi_only')).thenReturn(false);
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

    // Use REAL DeltaGenerationService
    deltaGenService = DeltaGenerationService(db, localDeltaQueue, mockPrefs, deviceUuid: 'test-device');

    mockGoogleDriveService = MockGoogleDriveService();
    mockICloudDriveService = MockICloudDriveService();
    mockConnectivityService = MockConnectivityService();
    mockNotificationService = MockNotificationService();
    mockDeltaReplayService = MockDeltaReplayService();

    // Default connectivity: Offline initially
    when(mockConnectivityService.connectionStatusStream).thenAnswer((_) => const Stream.empty());
    when(mockConnectivityService.isConnected).thenAnswer((_) async => false);

    syncEngine = SyncEngine(
      deltaGenService,
      localDeltaQueue,
      mockDeltaReplayService,
      mockGoogleDriveService,
      mockICloudDriveService,
      mockPrefs,
      mockConnectivityService,
      mockNotificationService,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('Sync recovery after app crash / offline scenario', () async {
    // 1. Simulate Offline State
    when(mockConnectivityService.isConnected).thenAnswer((_) async => false);

    // 2. Add data to DB -> Generates Pending Change
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc1',
        name: 'Test Account',
        type: 'checking',
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // 3. Process changes (offline) -> Generates Delta in Queue
    await deltaGenService.processPendingChanges();

    // Verify delta file exists
    final pending = await localDeltaQueue.getPendingDeltas();
    expect(pending.length, equals(1));
    print('Pending delta created: ${pending.first.path}');

    // 4. Simulate App Crash/Restart
    // Dispose engine
    syncEngine.dispose();
    // Create NEW engine instance (simulating restart)
    // We reuse the same localDeltaQueue/db/prefs objects as they simulate persistent storage
    // But we create a new SyncEngine
    final newSyncEngine = SyncEngine(
      deltaGenService,
      localDeltaQueue,
      mockDeltaReplayService,
      mockGoogleDriveService,
      mockICloudDriveService,
      mockPrefs,
      mockConnectivityService,
      mockNotificationService,
    );

    // 5. Verify Queue Persisted
    final pendingAfterRestart = await localDeltaQueue.getPendingDeltas();
    expect(pendingAfterRestart.length, equals(1));
    expect(pendingAfterRestart.first.path, equals(pending.first.path));

    // 6. Connect to Network
    when(mockConnectivityService.isConnected).thenAnswer((_) async => true);
    when(mockConnectivityService.isWifi).thenAnswer((_) async => true);

    // Mock upload success
    when(mockGoogleDriveService.uploadDelta(any, any)).thenAnswer((_) async => 'fake-file-id');
    when(mockGoogleDriveService.listDeltas()).thenAnswer((_) async => []); // No remote deltas

    // 7. Trigger Sync
    await newSyncEngine.sync();

    // 8. Verify Upload happened
    verify(mockGoogleDriveService.uploadDelta(any, any)).called(1);

    // 9. Verify Queue is empty (moved to uploaded)
    final pendingFinal = await localDeltaQueue.getPendingDeltas();
    expect(pendingFinal, isEmpty);
  });
}
