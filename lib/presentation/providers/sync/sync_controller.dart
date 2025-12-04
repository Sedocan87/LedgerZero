import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncController extends StateNotifier<SyncState> {
  final GoogleAuthService _authService;
  final GoogleDriveService _driveService;
  final ICloudDriveService _iCloudService;
  final DeltaGenerationService _deltaService;
  final LocalDeltaQueue _deltaQueue;
  final SharedPreferences _prefs;

  static const String _lastSyncKey = 'sync_last_sync_time';
  static const String _syncProviderKey = 'sync_provider';

  SyncController(
    this._authService,
    this._driveService,
    this._iCloudService,
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

    // Load selected provider
    final providerStr = _prefs.getString(_syncProviderKey);
    if (providerStr != null) {
      final provider = SyncProviderType.values.firstWhere(
        (e) => e.name == providerStr,
        orElse: () => SyncProviderType.none,
      );
      state = state.copyWith(selectedProvider: provider);
    }

    // Listen to auth changes
    _authService.onCurrentUserChanged.listen((account) {
      if (state.selectedProvider == SyncProviderType.googleDrive) {
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
      }
    });

    // Check connection status based on provider
    if (state.selectedProvider == SyncProviderType.googleDrive) {
      // Check initial state
      final isSignedIn = await _authService.isSignedIn();
      if (isSignedIn) {
        final user = _authService.currentUser;
        state = state.copyWith(
          status: SyncStatus.connected,
          accountEmail: user?.email,
        );
      }
    } else if (state.selectedProvider == SyncProviderType.iCloud) {
       // Check if iCloud is accessible
       try {
         await _iCloudService.verifyContainerAccess();
         state = state.copyWith(status: SyncStatus.connected);
       } catch (e) {
          state = state.copyWith(status: SyncStatus.error, errorMessage: e.toString());
       }
    }
  }

  Future<void> setProvider(SyncProviderType provider) async {
    if (state.selectedProvider == provider) {
      return;
    }

    // Disconnect previous if needed (though we might want to keep creds? for now let's strict switch)
    // Actually, simply switching provider doesn't necessarily mean signing out of Google Drive,
    // but the UI should reflect the new provider's status.

    await _prefs.setString(_syncProviderKey, provider.name);
    state = state.copyWith(selectedProvider: provider, status: SyncStatus.disconnected, errorMessage: null, accountEmail: null);

    if (provider == SyncProviderType.googleDrive) {
       // Check if already signed in
       final isSignedIn = await _authService.isSignedIn();
       if (isSignedIn) {
          final user = _authService.currentUser;
          state = state.copyWith(
            status: SyncStatus.connected,
            accountEmail: user?.email
          );
       }
    } else if (provider == SyncProviderType.iCloud) {
        // Auto-connect for iCloud
        await connect();
    }
  }


  Future<void> connect() async {
    state = state.copyWith(status: SyncStatus.syncing); // Optimistic UI
    try {
      if (state.selectedProvider == SyncProviderType.googleDrive) {
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
      } else if (state.selectedProvider == SyncProviderType.iCloud) {
        await _iCloudService.verifyContainerAccess();
        state = state.copyWith(
          status: SyncStatus.connected,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: SyncStatus.disconnected,
          errorMessage: 'No provider selected',
        );
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
      if (state.selectedProvider == SyncProviderType.googleDrive) {
        await _authService.signOut();
      }
      // For iCloud, we don't really "sign out", we just stop using it.

      await _prefs.remove(_syncProviderKey);
      // We also remove the last sync time probably? Or keep it?
      // Let's remove provider setting so it goes back to "None" or remains selected but disconnected?
      // The requirement says "Add iCloud disconnection option".
      // If we remove provider key, on reload it will be 'none'.

      state = state.copyWith(
        status: SyncStatus.disconnected,
        accountEmail: null,
        // lastSyncTime: null, // Keep history?
        errorMessage: null,
        selectedProvider: SyncProviderType.none,
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
      Logger.info('Starting manual sync with ${state.selectedProvider}...');

      // 1. Generate Deltas
      await _deltaService.processPendingChanges();

      // 2. Upload Pending Deltas
      final pendingDeltas = await _deltaQueue.getPendingDeltas();
      Logger.info('Found ${pendingDeltas.length} pending deltas to upload.');

      for (final file in pendingDeltas) {
        final filename = file.uri.pathSegments.last;
        if (state.selectedProvider == SyncProviderType.googleDrive) {
          await _driveService.uploadDelta(file, filename);
        } else if (state.selectedProvider == SyncProviderType.iCloud) {
          await _iCloudService.uploadDelta(file, filename);
        }
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
