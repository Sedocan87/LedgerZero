import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncController extends StateNotifier<SyncState> {
  final GoogleAuthService _authService;
  final ICloudDriveService _iCloudService;
  final SharedPreferences _prefs;
  final SyncEngine _syncEngine;

  static const String _lastSyncKey = 'sync_last_sync_time';
  static const String _syncProviderKey = 'sync_provider';
  static const String _syncWifiOnlyKey = 'sync_on_wifi_only';
  static const String _syncFrequencyKey = 'sync_frequency';

  SyncController(
    this._authService,
    this._iCloudService,
    this._prefs,
    this._syncEngine,
  ) : super(const SyncState()) {
    _init();
    _listenToEngine();
  }

  void _listenToEngine() {
    _syncEngine.statusStream.listen((engineState) {
      state = state.copyWith(
        status: engineState.status,
        message: engineState.message,
        progress: engineState.progress,
        lastSyncTime: engineState.lastSyncTime,
      );
    });
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

    // Load Wi-Fi only setting
    final wifiOnly = _prefs.getBool(_syncWifiOnlyKey) ?? false;
    state = state.copyWith(wifiOnly: wifiOnly);

    // Load Sync Frequency
    final freqStr = _prefs.getString(_syncFrequencyKey);
    final frequency = SyncFrequency.values.firstWhere(
      (e) => e.name == freqStr,
      orElse: () => SyncFrequency.manual,
    );
    state = state.copyWith(syncFrequency: frequency);
    _syncEngine.updateSyncFrequency(frequency);

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

  Future<void> setWifiOnly(bool enabled) async {
    await _prefs.setBool(_syncWifiOnlyKey, enabled);
    state = state.copyWith(wifiOnly: enabled);
  }

  Future<void> setSyncFrequency(SyncFrequency frequency) async {
    await _prefs.setString(_syncFrequencyKey, frequency.name);
    state = state.copyWith(syncFrequency: frequency);
    _syncEngine.updateSyncFrequency(frequency);
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

      await _prefs.remove(_syncProviderKey);

      state = state.copyWith(
        status: SyncStatus.disconnected,
        accountEmail: null,
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
    await _syncEngine.sync();
  }
}
