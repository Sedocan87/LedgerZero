
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/service_mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDeltaGenerationService mockDeltaGenService;
  late MockLocalDeltaQueue mockLocalDeltaQueue;
  late MockDeltaReplayService mockDeltaReplayService;
  late MockGoogleDriveService mockGoogleDriveService;
  late MockICloudDriveService mockICloudDriveService;
  late MockSharedPreferences mockPrefs;
  late MockConnectivityService mockConnectivityService;
  late MockNotificationService mockNotificationService;

  late SyncEngine syncEngine;

  setUp(() {
    // Mock Path Provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
      return '.';
    });

    mockDeltaGenService = MockDeltaGenerationService();
    mockLocalDeltaQueue = MockLocalDeltaQueue();
    mockDeltaReplayService = MockDeltaReplayService();
    mockGoogleDriveService = MockGoogleDriveService();
    mockICloudDriveService = MockICloudDriveService();
    mockPrefs = MockSharedPreferences();
    mockConnectivityService = MockConnectivityService();
    mockNotificationService = MockNotificationService();

    // Default mock behaviors
    when(mockConnectivityService.connectionStatusStream)
        .thenAnswer((_) => const Stream.empty());

    // Default provider to Google Drive so it doesn't exit early on "none"
    when(mockPrefs.getString('sync_provider')).thenReturn('googleDrive');
    // Default stats
    when(mockPrefs.getInt(any)).thenReturn(0);
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);

    // Mock getAppliedDeltaFilenames
    when(mockDeltaGenService.getAppliedDeltaFilenames()).thenAnswer((_) async => {});

    // Mock listDeltas
    when(mockGoogleDriveService.listDeltas()).thenAnswer((_) async => []);

    syncEngine = SyncEngine(
      mockDeltaGenService,
      mockLocalDeltaQueue,
      mockDeltaReplayService,
      mockGoogleDriveService,
      mockICloudDriveService,
      mockPrefs,
      mockConnectivityService,
      mockNotificationService,
    );
  });

  group('SyncEngine Wi-Fi Only Tests', () {
    test('Background sync proceeds if Wi-Fi only is FALSE and on Cellular', () async {
      // Setup: Wifi Only = False
      when(mockPrefs.getBool('sync_on_wifi_only')).thenReturn(false);

      // Setup: Connected, but NOT Wifi (Cellular)
      when(mockConnectivityService.isConnected).thenAnswer((_) async => true);
      when(mockConnectivityService.isWifi).thenAnswer((_) async => false);

      // Setup: processPendingChanges returns
      when(mockDeltaGenService.processPendingChanges()).thenAnswer((_) async {});
      when(mockLocalDeltaQueue.getPendingDeltas()).thenAnswer((_) async => []);

      // Act
      await syncEngine.sync(background: true);

      // Assert
      // Should have called processPendingChanges
      verify(mockDeltaGenService.processPendingChanges()).called(1);
    });

    test('Background sync ABORTS if Wi-Fi only is TRUE and on Cellular', () async {
      // Setup: Wifi Only = True
      when(mockPrefs.getBool('sync_on_wifi_only')).thenReturn(true);

      // Setup: Connected, but NOT Wifi (Cellular)
      when(mockConnectivityService.isConnected).thenAnswer((_) async => true);
      when(mockConnectivityService.isWifi).thenAnswer((_) async => false);

      // Act
      await syncEngine.sync(background: true);

      // Assert
      // processPendingChanges is called first (step 1)
      verify(mockDeltaGenService.processPendingChanges()).called(1);
      // But upload logic (getPendingDeltas) is NOT called
      verifyNever(mockLocalDeltaQueue.getPendingDeltas());
    });

    test('Background sync PROCEEDS if Wi-Fi only is TRUE and on Wi-Fi', () async {
      // Setup: Wifi Only = True
      when(mockPrefs.getBool('sync_on_wifi_only')).thenReturn(true);

      // Setup: Connected AND Wifi
      when(mockConnectivityService.isConnected).thenAnswer((_) async => true);
      when(mockConnectivityService.isWifi).thenAnswer((_) async => true);

      // Setup: processPendingChanges returns
      when(mockDeltaGenService.processPendingChanges()).thenAnswer((_) async {});
      when(mockLocalDeltaQueue.getPendingDeltas()).thenAnswer((_) async => []); // No pending uploads

      // Act
      await syncEngine.sync(background: true);

      // Assert
      verify(mockDeltaGenService.processPendingChanges()).called(1);
      verify(mockLocalDeltaQueue.getPendingDeltas()).called(1); // Proceeded to upload check
    });

    test('Manual sync PROCEEDS even if Wi-Fi only is TRUE and on Cellular', () async {
      // Setup: Wifi Only = True
      when(mockPrefs.getBool('sync_on_wifi_only')).thenReturn(true);

      // Setup: Connected, but NOT Wifi
      when(mockConnectivityService.isConnected).thenAnswer((_) async => true);
      when(mockConnectivityService.isWifi).thenAnswer((_) async => false);

      // Setup: processPendingChanges returns
      when(mockDeltaGenService.processPendingChanges()).thenAnswer((_) async {});
      when(mockLocalDeltaQueue.getPendingDeltas()).thenAnswer((_) async => []);

      // Act: background = false (manual)
      await syncEngine.sync(background: false);

      // Assert
      verify(mockDeltaGenService.processPendingChanges()).called(1);
      verify(mockLocalDeltaQueue.getPendingDeltas()).called(1); // Should proceed because manual overrides
    });
  });
}
