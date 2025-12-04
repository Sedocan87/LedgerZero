import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncController extends StateNotifier<SyncState> {
  final GoogleAuthService _authService;
  final GoogleDriveService _driveService;
  final DeltaGenerationService _deltaService;
  final LocalDeltaQueue _deltaQueue;
  final SharedPreferences _prefs;

  static const String _lastSyncKey = 'sync_last_sync_time';

  SyncController(
    this._authService,
    this._driveService,
    this._deltaService,
    this._deltaQueue,
    this._prefs,
  ) : super(const SyncState()) {
    _init();
  }

  Future<void> _init() async {
    // Load last sync time
    final lastSyncStr = _prefs.getString(_lastSyncKey);
    if (lastSyncStr != null) {
      state = state.copyWith(lastSyncTime: DateTime.parse(lastSyncStr));
    }

    // Listen to auth changes
    _authService.onCurrentUserChanged.listen((account) {
      if (account != null) {
        state = state.copyWith(
          status: SyncStatus.connected,
          accountEmail: account.email,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: SyncStatus.disconnected,
          accountEmail: null,
        );
      }
    });

    // Check initial state
    final isSignedIn = await _authService.isSignedIn();
    if (isSignedIn) {
      final user = _authService.currentUser;
      state = state.copyWith(
        status: SyncStatus.connected,
        accountEmail: user?.email,
      );
    }
  }

  Future<void> connect() async {
    state = state.copyWith(status: SyncStatus.syncing); // Optimistic UI
    try {
      final account = await _authService.signIn();
      if (account != null) {
        state = state.copyWith(
          status: SyncStatus.connected,
          accountEmail: account.email,
          errorMessage: null,
        );
      } else {
        // User cancelled
        state = state.copyWith(status: SyncStatus.disconnected);
      }
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    try {
      await _authService.signOut();
      await _prefs.remove(_lastSyncKey);
      state = state.copyWith(
        status: SyncStatus.disconnected,
        accountEmail: null,
        lastSyncTime: null,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> syncNow() async {
    if (state.status != SyncStatus.connected) {
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);
    try {
      Logger.info('Starting manual sync...');

      // 1. Generate Deltas
      await _deltaService.processPendingChanges();

      // 2. Upload Pending Deltas
      final pendingDeltas = await _deltaQueue.getPendingDeltas();
      Logger.info('Found ${pendingDeltas.length} pending deltas to upload.');

      for (final file in pendingDeltas) {
        final filename = file.uri.pathSegments.last;
        await _driveService.uploadDelta(file, filename);
        await _deltaQueue.markAsUploaded(file);
      }

      // TODO: Download logic (Task 407/444) - stub for now
      // await _downloadAndApplyDeltas();

      final now = DateTime.now();
      await _prefs.setString(_lastSyncKey, now.toIso8601String());
      state = state.copyWith(
        status: SyncStatus.connected,
        lastSyncTime: now,
      );
      Logger.info('Sync completed successfully.');
    } catch (e) {
      Logger.error('Sync failed', e);
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
