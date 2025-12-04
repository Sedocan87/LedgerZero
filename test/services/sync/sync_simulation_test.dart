// ignore_for_file: must_be_immutable
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/service_mocks.mocks.dart';

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {
  @override
  String get email => 'test@example.com';
}

class FakeSyncEngine extends Fake implements SyncEngine {
  final _controller = StreamController<SyncState>.broadcast();
  bool syncCalled = false;

  @override
  Stream<SyncState> get statusStream => _controller.stream;

  @override
  Future<void> sync({bool background = false}) async {
    syncCalled = true;
    _controller.add(
        const SyncState(status: SyncStatus.connected, lastSyncTime: null));
  }
}

void main() {
  late MockGoogleAuthService mockAuthService;
  late MockICloudDriveService mockICloudService;
  late MockSharedPreferences mockPrefs;
  late SyncController controller;
  late StreamController<GoogleSignInAccount?> authStreamController;
  late FakeSyncEngine fakeSyncEngine;

  setUp(() {
    mockAuthService = MockGoogleAuthService();
    mockICloudService = MockICloudDriveService();
    mockPrefs = MockSharedPreferences();
    authStreamController = StreamController<GoogleSignInAccount?>.broadcast();
    fakeSyncEngine = FakeSyncEngine();

    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockAuthService.onCurrentUserChanged)
        .thenAnswer((_) => authStreamController.stream);
    when(mockAuthService.isSignedIn()).thenAnswer((_) async => false);
    when(mockAuthService.currentUser).thenReturn(null);

    controller = SyncController(
      mockAuthService,
      mockICloudService,
      mockPrefs,
      fakeSyncEngine,
    );
  });

  tearDown(() {
    authStreamController.close();
  });

  test('Initial state is disconnected', () {
    expect(controller.state.status, SyncStatus.disconnected);
  });

  test('Updates state when user signs in (Google Drive)', () async {
    when(mockPrefs.getString('sync_provider')).thenReturn('googleDrive');
    when(mockPrefs.getString('sync_last_sync_time')).thenReturn(null);

    controller = SyncController(
      mockAuthService,
      mockICloudService,
      mockPrefs,
      fakeSyncEngine,
    );

    final mockAccount = MockGoogleSignInAccount();
    authStreamController.add(mockAccount);

    await Future.microtask(() {});

    expect(controller.state.status, SyncStatus.connected);
    expect(controller.state.accountEmail, 'test@example.com');
  });

  test('SyncNow calls SyncEngine', () async {
    final mockAccount = MockGoogleSignInAccount();
    when(mockAuthService.isSignedIn()).thenAnswer((_) async => true);
    when(mockAuthService.currentUser).thenReturn(mockAccount);
    when(mockPrefs.getString('sync_provider')).thenReturn('googleDrive');

    controller = SyncController(
      mockAuthService,
      mockICloudService,
      mockPrefs,
      fakeSyncEngine,
    );

    await Future.delayed(Duration.zero);

    expect(controller.state.status, SyncStatus.connected);

    await controller.syncNow();

    expect(fakeSyncEngine.syncCalled, isTrue);
  });
}
