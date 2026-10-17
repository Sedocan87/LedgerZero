import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/sync_dao.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_view_models.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:ledger_zero/services/sync/format/sync_manifest.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:ledger_zero/services/sync/lan/lan_sync_service.dart';
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What sync needs from the unlocked database. Created by
/// `syncDependenciesProvider`; reading it while the app is locked throws.
class SyncDependencies {
  final SyncEngine Function(SyncTransport transport) engineFor;
  final SyncDao dao;
  final SyncConflictResolver resolver;

  const SyncDependencies({
    required this.engineFor,
    required this.dao,
    required this.resolver,
  });
}

/// Outcome of starting or joining Wi-Fi sync.
enum LanSetupResult {
  ok,

  /// The scanned or typed text is not a LedgerZero pairing code.
  invalidCode,

  /// The other phone could not be reached (not on the same Wi-Fi, app not
  /// open, or the network blocks phones from talking to each other).
  phoneNotFound,
  failed,
}

/// Outcome of setting or entering the sync passphrase.
enum SyncPassphraseResult {
  ok,
  wrongPassphrase,

  /// Another device created the folder first; enter its passphrase.
  folderExists,
  failed,
}

/// Owns sync for the app's lifetime (decision D6, finding H5):
///
/// * pauses while the database is closed (cancels the running sync, stops
///   timers and subscriptions) and resumes when it opens. It is open from
///   start-up on, also behind the app lock (see [appLockStateProvider]);
/// * syncs automatically when the database opens, on app resume (if the last sync is
///   older than [resumeThreshold]), [debounce] after local changes, on the
///   periodic timer of the chosen frequency, and when connectivity returns
///   — none of these when the frequency is manual;
/// * Wi-Fi only applies to automatic syncs;
/// * every entry point catches its errors (no unhandled futures).
class SyncController extends StateNotifier<SyncState> {
  final GoogleAuthService _authService;
  final SharedPreferences _prefs;
  final ConnectivityService _connectivity;
  final SyncDependencies Function() _dependencies;
  final SyncTransport? Function(SyncProviderType provider) _transportFor;

  /// Wi-Fi sync (null in tests that do not use it).
  final LanSyncService? _lan;
  final Duration debounce;
  final Duration resumeThreshold;
  final Duration Function(SyncFrequency frequency)? _intervalOverride;
  final DateTime Function() _clock;

  static const String _syncProviderKey = 'sync_provider';
  static const String _syncWifiOnlyKey = 'sync_on_wifi_only';
  static const String _syncFrequencyKey = 'sync_frequency';

  bool _unlocked = false;
  bool _foreground = true;
  static bool _legacyQueueRemoved = false;
  bool _disposed = false;
  SyncDependencies? _deps;
  SyncEngine? _engine;
  SyncTransport? _engineTransport;
  SyncCancellation? _cancellation;
  Future<void>? _running;
  bool _rerun = false;
  int _retries = 0;

  Timer? _periodic;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  StreamSubscription<ConnectionStatus>? _connectivitySub;
  StreamSubscription<int>? _pendingSub;
  StreamSubscription<List<SyncConflict>>? _conflictSub;
  StreamSubscription<List<SyncQuarantineData>>? _quarantineSub;
  StreamSubscription<Object?>? _authSub;
  int _lastPending = 0;
  ConnectionStatus? _lastConnection;

  /// Number of sync runs started (for tests and diagnostics).
  int runCount = 0;

  SyncController({
    required this._authService,
    required this._prefs,
    required this._connectivity,
    required this._dependencies,
    required this._transportFor,
    this._lan,
    this.debounce = const Duration(seconds: 10),
    this.resumeThreshold = const Duration(seconds: 60),
    Duration Function(SyncFrequency frequency)? intervalFor,
    DateTime Function()? clock,
  }) : _intervalOverride = intervalFor,
       _clock = clock ?? DateTime.now,
       super(const SyncState(paused: true)) {
    _loadSettings();
    _authSub = _authService.onCurrentUserChanged.listen((account) {
      if (state.selectedProvider != SyncProviderType.googleDrive) {
        return;
      }
      state = account != null
          ? state.copyWith(
              status: SyncStatus.connected,
              accountEmail: account.email,
              clearError: true,
            )
          : state.copyWith(status: SyncStatus.disconnected, clearAccount: true);
    }, onError: (Object e) => Logger.warning('Google account stream: $e'));
  }

  void _loadSettings() {
    final lastSync = DateTime.tryParse(
      _prefs.getString(SyncEngine.lastSyncKey) ?? '',
    );
    final provider = SyncProviderType.values.firstWhere(
      (e) => e.name == _prefs.getString(_syncProviderKey),
      orElse: () => SyncProviderType.none,
    );
    final frequency = SyncFrequency.values.firstWhere(
      (e) => e.name == _prefs.getString(_syncFrequencyKey),
      orElse: () => SyncFrequency.realtime,
    );
    state = state.copyWith(
      lastSyncTime: lastSync,
      selectedProvider: provider,
      wifiOnly: _prefs.getBool(_syncWifiOnlyKey) ?? false,
      syncFrequency: frequency,
    );
  }

  bool get _automatic =>
      state.syncFrequency != SyncFrequency.manual &&
      state.selectedProvider != SyncProviderType.none;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Called with `appLockStateProvider` (fires immediately).
  Future<void> onLockStateChanged(AppLockState lockState) async {
    if (_disposed) {
      return;
    }
    if (lockState == AppLockState.unlocked) {
      await _onUnlocked();
    } else {
      _onLocked();
    }
  }

  Future<void> _onUnlocked() async {
    if (_unlocked) {
      return;
    }
    try {
      _deps = _dependencies();
    } catch (e) {
      Logger.warning('Sync: database not available: $e');
      return;
    }
    _unlocked = true;
    state = state.copyWith(paused: false);
    if (!_legacyQueueRemoved) {
      _legacyQueueRemoved = true;
      unawaited(SyncOutbox.removeLegacyQueue());
    }
    final deps = _deps!;
    _pendingSub = deps.dao.watchPendingCount().listen(
      _onPendingCount,
      onError: (Object e) => Logger.warning('Sync pending watch: $e'),
    );
    _conflictSub = deps.dao.watchConflicts().listen(
      (c) => _set(state.copyWith(conflicts: [for (final r in c) _conflict(r)])),
      onError: (Object e) => Logger.warning('Sync conflict watch: $e'),
    );
    _quarantineSub = deps.dao.watchQuarantine().listen(
      (q) => _set(
        state.copyWith(
          quarantine: [for (final r in q) _quarantined(r)],
          newerSchemaPending: q.any((e) => e.reason == 'newer_schema'),
        ),
      ),
      onError: (Object e) => Logger.warning('Sync quarantine watch: $e'),
    );
    _connectivitySub = _connectivity.connectionStatusStream.listen(
      _onConnectivity,
      onError: (Object e) => Logger.warning('Connectivity: $e'),
    );
    _restartPeriodic();
    await _refreshConnectionState();
    if (state.selectedProvider == SyncProviderType.none) {
      await _discardCapturedChanges();
    }
    _requestAutoSync('unlock');
  }

  void _onLocked() {
    if (!_unlocked) {
      return;
    }
    _unlocked = false;
    unawaited(_lan?.stop());
    _cancellation?.cancel();
    _stopTimersAndSubscriptions();
    _deps = null;
    _engine = null;
    _engineTransport = null;
    _set(state.copyWith(paused: true));
  }

  void _stopTimersAndSubscriptions() {
    _periodic?.cancel();
    _periodic = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _pendingSub?.cancel();
    _pendingSub = null;
    _conflictSub?.cancel();
    _conflictSub = null;
    _quarantineSub?.cancel();
    _quarantineSub = null;
  }

  /// The app went to the background: Wi-Fi sync stops listening (Android
  /// would stop it soon anyway).
  void onAppPaused() {
    _foreground = false;
    unawaited(_lan?.stop());
  }

  /// The app returned to the foreground.
  void onAppResumed() {
    _foreground = true;
    unawaited(_startLanIfPaired());
    final last = state.lastSyncTime;
    if (last == null || _clock().difference(last) > resumeThreshold) {
      _requestAutoSync('resume');
    }
  }

  void _onPendingCount(int count) {
    final previous = _lastPending;
    _lastPending = count;
    _set(state.copyWith(pendingChanges: count));
    if (count > previous && count > 0 && _automatic && _unlocked) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, () => _requestAutoSync('changes'));
    }
  }

  void _onConnectivity(ConnectionStatus status) {
    final previous = _lastConnection;
    _lastConnection = status;
    if (status == ConnectionStatus.online &&
        previous == ConnectionStatus.offline) {
      _requestAutoSync('connectivity');
    }
  }

  Duration? _intervalFor(SyncFrequency frequency) {
    final override = _intervalOverride;
    if (override != null) {
      return frequency == SyncFrequency.manual ? null : override(frequency);
    }
    return switch (frequency) {
      SyncFrequency.manual => null,
      SyncFrequency.realtime => const Duration(minutes: 5),
      SyncFrequency.every15Min => const Duration(minutes: 15),
      SyncFrequency.everyHour => const Duration(hours: 1),
      SyncFrequency.every4Hours => const Duration(hours: 4),
    };
  }

  void _restartPeriodic() {
    _periodic?.cancel();
    _periodic = null;
    final interval = _intervalFor(state.syncFrequency);
    if (interval == null || !_unlocked) {
      return;
    }
    _periodic = Timer.periodic(interval, (_) => _requestAutoSync('timer'));
  }

  void _requestAutoSync(String reason) {
    if (!_unlocked || !_automatic || _disposed) {
      return;
    }
    Logger.info('Sync requested ($reason)');
    unawaited(_runSync(automatic: true));
  }

  // ---------------------------------------------------------------------
  // Running
  // ---------------------------------------------------------------------

  /// Manual sync (button, pull to refresh). Never throws.
  Future<void> syncNow() => _runSync(automatic: false);

  Future<void> _runSync({required bool automatic}) {
    final running = _running;
    if (running != null) {
      _rerun = true;
      return running;
    }
    final run = _syncOnce(automatic: automatic).whenComplete(() {
      _running = null;
      if (_rerun && _unlocked && !_disposed) {
        _rerun = false;
        _requestAutoSync('rerun');
      }
    });
    _running = run;
    return run;
  }

  Future<void> _syncOnce({required bool automatic}) async {
    try {
      final engine = _currentEngine();
      if (engine == null) {
        return;
      }
      if (!await _connectivity.isConnected) {
        Logger.info('Sync deferred: offline.');
        _lastConnection = ConnectionStatus.offline;
        return;
      }
      if (automatic && state.wifiOnly && !await _connectivity.isWifi) {
        Logger.info('Sync deferred: Wi-Fi only.');
        return;
      }
      if (state.selectedProvider == SyncProviderType.localWifi &&
          (!(_lan?.isPaired ?? false) || !await _connectivity.isWifi)) {
        return;
      }
      if (_disposed || !_unlocked) {
        return;
      }
      final cancellation = _cancellation = SyncCancellation();
      runCount++;
      _set(state.copyWith(status: SyncStatus.syncing, clearError: true));
      final report = await engine.sync(cancellation: cancellation);
      _retries = 0;
      final setup = switch (report.setup) {
        SyncSetupStatus.noFolder => SyncSetupState.needsNewPassphrase,
        SyncSetupStatus.needsPassphrase => SyncSetupState.needsPassphrase,
        SyncSetupStatus.ready => SyncSetupState.ready,
      };
      _set(
        state.copyWith(
          status: SyncStatus.connected,
          setup: setup,
          lastSyncTime: report.setup == SyncSetupStatus.ready ? _clock() : null,
          legacyFilesFound: report.legacyFilesFound,
        ),
      );
    } on SyncCancelledException {
      _set(state.copyWith(status: SyncStatus.connected));
    } on DatabaseLockedException {
      // Closed while running (factory reset); resumes when it reopens.
    } catch (e, stack) {
      if (_cancellation?.isCancelled ?? false) {
        return;
      }
      Logger.error('Sync failed', e, stack);
      _set(
        state.copyWith(
          status: SyncStatus.error,
          errorMessage: _describe(e),
          errorKind: e is SyncException ? e.kind : null,
          clearError: e is! SyncException,
        ),
      );
      if (automatic && e is SyncException && e.retryable) {
        _scheduleRetry();
      }
    } finally {
      _cancellation = null;
    }
  }

  void _scheduleRetry() {
    if (_retries >= 4 || !_unlocked) {
      return;
    }
    _retries++;
    final delay = Duration(seconds: 30 * (1 << (_retries - 1)));
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => _requestAutoSync('retry'));
  }

  /// Technical detail kept in the state: a [SyncException]'s own message,
  /// null for anything else. The UI shows a localised text for the
  /// exception's [SyncErrorKind]; details go to the log, never to the
  /// screen.
  String? _describe(Object error) {
    if (error is SyncException) {
      return error.message;
    }
    Logger.error('Sync failed', error);
    return null;
  }

  /// The engine for the selected provider (recreated after a provider
  /// change or a reopened database).
  SyncEngine? _currentEngine() {
    final deps = _deps;
    if (!_unlocked || deps == null) {
      return null;
    }
    final transport = _transportFor(state.selectedProvider);
    if (transport == null) {
      return null;
    }
    if (_engine == null || !identical(_engineTransport, transport)) {
      _engine = deps.engineFor(transport);
      _engineTransport = transport;
    }
    return _engine;
  }

  void _set(SyncState next) {
    if (!_disposed && mounted) {
      state = next;
    }
  }

  // ---------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------

  Future<void> setProvider(SyncProviderType provider) async {
    if (state.selectedProvider == provider) {
      return;
    }
    await _prefs.setString(_syncProviderKey, provider.name);
    if (state.selectedProvider == SyncProviderType.localWifi) {
      await _lan?.stop();
    }
    _engine = null;
    _engineTransport = null;
    state = state.copyWith(
      selectedProvider: provider,
      status: SyncStatus.disconnected,
      setup: SyncSetupState.unknown,
      clearError: true,
      clearAccount: true,
    );
    if (provider == SyncProviderType.none) {
      await _discardCapturedChanges();
    } else {
      await _refreshConnectionState();
    }
  }

  Future<void> setWifiOnly(bool enabled) async {
    await _prefs.setBool(_syncWifiOnlyKey, enabled);
    state = state.copyWith(wifiOnly: enabled);
  }

  Future<void> setSyncFrequency(SyncFrequency frequency) async {
    await _prefs.setString(_syncFrequencyKey, frequency.name);
    state = state.copyWith(syncFrequency: frequency);
    _restartPeriodic();
  }

  Future<void> _refreshConnectionState() async {
    try {
      switch (state.selectedProvider) {
        case SyncProviderType.googleDrive:
          if (!await _authService.isSignedIn()) {
            await _authService.signInSilently();
          }
          if (await _authService.isSignedIn()) {
            _set(
              state.copyWith(
                status: SyncStatus.connected,
                accountEmail: _authService.currentUser?.email,
              ),
            );
          }
        case SyncProviderType.localWifi:
          if (!await _prepareLan()) {
            return;
          }
        case SyncProviderType.none:
          return;
      }
      await refreshSetup();
    } catch (e) {
      _set(
        state.copyWith(
          status: SyncStatus.error,
          errorMessage: _describe(e),
          errorKind: e is SyncException ? e.kind : null,
          clearError: e is! SyncException,
        ),
      );
    }
  }

  /// Re-reads the folder's manifest state.
  Future<void> refreshSetup() async {
    try {
      final engine = _currentEngine();
      if (engine == null || state.status != SyncStatus.connected) {
        return;
      }
      final status = await engine.setupStatus();
      _set(
        state.copyWith(
          setup: switch (status) {
            SyncSetupStatus.noFolder => SyncSetupState.needsNewPassphrase,
            SyncSetupStatus.needsPassphrase => SyncSetupState.needsPassphrase,
            SyncSetupStatus.ready => SyncSetupState.ready,
          },
        ),
      );
    } catch (e) {
      Logger.warning('Sync setup check failed: $e');
    }
  }

  Future<void> connect() async {
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      switch (state.selectedProvider) {
        case SyncProviderType.googleDrive:
          final account = await _authService.signIn();
          if (account == null) {
            state = state.copyWith(status: SyncStatus.disconnected);
            return;
          }
          state = state.copyWith(
            status: SyncStatus.connected,
            accountEmail: account.email,
          );
        case SyncProviderType.localWifi:
          if (!await _prepareLan()) {
            return;
          }
        case SyncProviderType.none:
          state = state.copyWith(status: SyncStatus.disconnected);
          return;
      }
      await refreshSetup();
    } catch (e) {
      _set(
        state.copyWith(
          status: SyncStatus.error,
          errorMessage: _describe(e),
          errorKind: e is SyncException ? e.kind : null,
          clearError: e is! SyncException,
        ),
      );
    }
  }

  Future<void> disconnect() async {
    try {
      _cancellation?.cancel();
      final engine = _currentEngine();
      if (engine != null) {
        await engine.forgetKey();
      }
      if (state.selectedProvider == SyncProviderType.googleDrive) {
        await _authService.signOut();
      }
      if (state.selectedProvider == SyncProviderType.localWifi) {
        await _lan?.unpair();
      }
      await _prefs.remove(_syncProviderKey);
      _engine = null;
      _engineTransport = null;
      await _discardCapturedChanges();
      state = state.copyWith(
        status: SyncStatus.disconnected,
        selectedProvider: SyncProviderType.none,
        setup: SyncSetupState.unknown,
        clearAccount: true,
        clearError: true,
      );
    } catch (e) {
      _set(
        state.copyWith(
          status: SyncStatus.error,
          errorMessage: _describe(e),
          errorKind: e is SyncException ? e.kind : null,
          clearError: e is! SyncException,
        ),
      );
    }
  }

  /// Without sync, captured changes are not needed: enabling sync uploads
  /// every row. Keeps `pending_sync_changes` from growing forever.
  Future<void> _discardCapturedChanges() async {
    try {
      await _deps?.dao.customStatement('DELETE FROM pending_sync_changes');
    } catch (e) {
      Logger.warning('Could not clear captured changes: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Wi-Fi sync
  // ---------------------------------------------------------------------

  /// Loads the pairing and starts listening; false while not paired (the
  /// setup offers "start" and "join").
  Future<bool> _prepareLan() async {
    final lan = _lan;
    if (lan == null) {
      return false;
    }
    await lan.load();
    _set(state.copyWith(status: SyncStatus.connected, clearError: true));
    if (!lan.isPaired) {
      _set(state.copyWith(setup: SyncSetupState.needsNewPassphrase));
      return false;
    }
    await _startLanIfPaired();
    return true;
  }

  Future<void> _startLanIfPaired() async {
    final lan = _lan;
    if (lan != null &&
        lan.isPaired &&
        _foreground &&
        _unlocked &&
        state.selectedProvider == SyncProviderType.localWifi) {
      await lan.start();
    }
  }

  /// First phone: creates the pairing and the sync folder.
  Future<LanSetupResult> startLanSync() async {
    final lan = _lan;
    final engine = _currentEngine();
    if (lan == null || engine == null) {
      return LanSetupResult.failed;
    }
    try {
      final pairing = LanPairing.generate();
      await lan.folder.clear();
      await lan.pair(pairing);
      await _startLanIfPaired();
      await engine.createSyncFolder(pairing.passphrase);
      _set(state.copyWith(setup: SyncSetupState.ready, clearError: true));
      unawaited(syncNow());
      return LanSetupResult.ok;
    } catch (e, stack) {
      Logger.error('Starting Wi-Fi sync failed', e, stack);
      return LanSetupResult.failed;
    }
  }

  /// Further phones: pairs with the code scanned on the first phone,
  /// fetches its sync folder and joins it. This phone's data is merged
  /// into the shared budget by the first sync.
  Future<LanSetupResult> joinLanSync(String codeText) async {
    final lan = _lan;
    final engine = _currentEngine();
    if (lan == null || engine == null) {
      return LanSetupResult.failed;
    }
    final LanPairingCode code;
    try {
      code = LanPairingCode.decode(codeText);
    } on FormatException {
      return LanSetupResult.invalidCode;
    }
    try {
      await lan.folder.clear();
      await lan.pair(code.pairing);
      await _startLanIfPaired();
      await lan.addPeerFromCode(code);
      await engine.joinSyncFolder(code.pairing.passphrase);
      _set(state.copyWith(setup: SyncSetupState.ready, clearError: true));
      unawaited(syncNow());
      return LanSetupResult.ok;
    } on SyncFolderMissingException {
      await lan.unpair();
      return LanSetupResult.phoneNotFound;
    } catch (e, stack) {
      Logger.error('Joining Wi-Fi sync failed', e, stack);
      await lan.unpair();
      return LanSetupResult.failed;
    }
  }

  /// The code (and QR code) to show on this phone for pairing another one.
  Future<String?> lanPairingCode() async =>
      (await _lan?.pairingCode())?.encode();

  /// A paired phone appeared or sent files.
  void onLanActivity() => _requestAutoSync('wifi peer');

  // ---------------------------------------------------------------------
  // Passphrase
  // ---------------------------------------------------------------------

  /// First device: sets the sync passphrase for the empty folder.
  Future<SyncPassphraseResult> createPassphrase(String passphrase) =>
      _withPassphrase((engine) => engine.createSyncFolder(passphrase));

  /// Further devices: enters the passphrase set on the first device.
  Future<SyncPassphraseResult> enterPassphrase(String passphrase) =>
      _withPassphrase((engine) => engine.joinSyncFolder(passphrase));

  Future<SyncPassphraseResult> _withPassphrase(
    Future<void> Function(SyncEngine engine) action,
  ) async {
    final engine = _currentEngine();
    if (engine == null) {
      return SyncPassphraseResult.failed;
    }
    try {
      await action(engine);
      _set(state.copyWith(setup: SyncSetupState.ready, clearError: true));
      unawaited(syncNow());
      return SyncPassphraseResult.ok;
    } on WrongSyncPassphraseException {
      return SyncPassphraseResult.wrongPassphrase;
    } on SyncFolderExistsException {
      _set(state.copyWith(setup: SyncSetupState.needsPassphrase));
      return SyncPassphraseResult.folderExists;
    } on SyncFolderMissingException {
      _set(state.copyWith(setup: SyncSetupState.needsNewPassphrase));
      return SyncPassphraseResult.failed;
    } catch (e, stack) {
      Logger.error('Sync passphrase setup failed', e, stack);
      _set(
        state.copyWith(
          errorMessage: _describe(e),
          errorKind: e is SyncException ? e.kind : null,
          clearError: e is! SyncException,
        ),
      );
      return SyncPassphraseResult.failed;
    }
  }

  // ---------------------------------------------------------------------
  // Conflicts and quarantine
  // ---------------------------------------------------------------------

  /// Re-applies the local version of a conflict. Returns false if that is
  /// no longer possible.
  Future<bool> keepMine(int conflictId) async {
    try {
      await _deps?.resolver.keepMine(conflictId);
      return _deps != null;
    } catch (e) {
      Logger.warning('Keep mine failed: $e');
      return false;
    }
  }

  Future<void> dismissConflict(int conflictId) async {
    try {
      await _deps?.resolver.dismiss(conflictId);
    } catch (e) {
      Logger.warning('Dismiss conflict failed: $e');
    }
  }

  Future<void> retryQuarantined([String? filename]) async {
    try {
      await _currentEngine()?.retryQuarantined(filename);
      await syncNow();
    } catch (e) {
      Logger.warning('Retry failed: $e');
    }
  }

  Future<void> skipQuarantined(String filename) async {
    try {
      await _currentEngine()?.skipQuarantined(filename);
      await syncNow();
    } catch (e) {
      Logger.warning('Skip failed: $e');
    }
  }

  /// Maps Drift rows to the view models the screens use.
  static SyncConflictItem _conflict(SyncConflict row) => SyncConflictItem(
    id: row.id,
    syncTable: row.syncTable,
    rowId: row.rowId,
    localSnapshot: row.localSnapshot,
    remoteSnapshot: row.remoteSnapshot,
    remoteDeviceId: row.remoteDeviceId,
    resolvedAt: row.resolvedAt,
  );

  static SyncQuarantineItem _quarantined(SyncQuarantineData row) =>
      SyncQuarantineItem(
        filename: row.filename,
        deviceId: row.deviceId,
        sequence: row.sequence,
        reason: row.reason,
        error: row.error,
        attempts: row.attempts,
        firstSeen: row.firstSeen,
        lastAttempt: row.lastAttempt,
        nextAttempt: row.nextAttempt,
      );

  /// Text for "share diagnostic": file names, reasons and errors only (no
  /// financial data, no keys).
  String quarantineDiagnostics() {
    final buffer = StringBuffer('LedgerZero sync diagnostics\n');
    for (final q in state.quarantine) {
      buffer
        ..writeln('file: ${q.filename}')
        ..writeln('  reason: ${q.reason}, attempts: ${q.attempts}')
        ..writeln('  first seen: ${q.firstSeen.toUtc().toIso8601String()}')
        ..writeln('  last attempt: ${q.lastAttempt.toUtc().toIso8601String()}')
        ..writeln('  error: ${q.error}');
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancellation?.cancel();
    _stopTimersAndSubscriptions();
    _authSub?.cancel();
    super.dispose();
  }
}
