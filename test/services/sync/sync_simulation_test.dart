// ignore_for_file: must_be_immutable
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/service_mocks.mocks.dart';

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {
  @override
  String get email => 'test@example.com';
}

void main() {
  late MockGoogleAuthService mockAuthService;
  late MockGoogleDriveService mockDriveService;
  late MockDeltaGenerationService mockDeltaService;
  late MockLocalDeltaQueue mockDeltaQueue;
  late MockSharedPreferences mockPrefs;
  late SyncController controller;
  late StreamController<GoogleSignInAccount?> authStreamController;

  setUp(() {
    mockAuthService = MockGoogleAuthService();
    mockDriveService = MockGoogleDriveService();
    mockDeltaService = MockDeltaGenerationService();
    mockDeltaQueue = MockLocalDeltaQueue();
    mockPrefs = MockSharedPreferences();
    authStreamController = StreamController<GoogleSignInAccount?>.broadcast();

    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockAuthService.onCurrentUserChanged)
        .thenAnswer((_) => authStreamController.stream);
    when(mockAuthService.isSignedIn()).thenAnswer((_) async => false);
    when(mockAuthService.currentUser).thenReturn(null);

    controller = SyncController(
      mockAuthService,
      mockDriveService,
      mockDeltaService,
      mockDeltaQueue,
      mockPrefs,
    );
  });

  tearDown(() {
    authStreamController.close();
  });

  test('Initial state is disconnected', () {
    expect(controller.state.status, SyncStatus.disconnected);
  });

  test('Updates state when user signs in', () async {
    final mockAccount = MockGoogleSignInAccount();
    authStreamController.add(mockAccount);

    await Future.microtask(() {}); // Process stream

    expect(controller.state.status, SyncStatus.connected);
    expect(controller.state.accountEmail, 'test@example.com');
  });

  test('SyncNow calls services', () async {
    // Setup connected state
    final mockAccount = MockGoogleSignInAccount();
    // Simulate init check finding a user
    when(mockAuthService.isSignedIn()).thenAnswer((_) async => true);
    when(mockAuthService.currentUser).thenReturn(mockAccount);

    // Re-init to pick up connected state
    controller = SyncController(
      mockAuthService,
      mockDriveService,
      mockDeltaService,
      mockDeltaQueue,
      mockPrefs,
    );

    // Wait for init
    await Future.delayed(Duration.zero);

    expect(controller.state.status, SyncStatus.connected);

    // Mock sync dependencies
    when(mockDeltaService.processPendingChanges()).thenAnswer((_) async {});
    when(mockDeltaQueue.getPendingDeltas())
        .thenAnswer((_) async => [File('test_delta.json.gz')]);
    when(mockDriveService.uploadDelta(any, any))
        .thenAnswer((_) async => 'file_id');
    when(mockDeltaQueue.markAsUploaded(any)).thenAnswer((_) async {});
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

    await controller.syncNow();

    verify(mockDeltaService.processPendingChanges()).called(1);
    verify(mockDeltaQueue.getPendingDeltas()).called(1);
    verify(mockDriveService.uploadDelta(any, any)).called(1);
    verify(mockDeltaQueue.markAsUploaded(any)).called(1);
    expect(controller.state.lastSyncTime, isNotNull);
  });
}
