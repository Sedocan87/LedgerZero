import 'package:equatable/equatable.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_view_models.dart';

enum SyncStatus { idle, disconnected, connected, syncing, error }

enum SyncProviderType { none, googleDrive, localWifi }

enum SyncFrequency {
  manual,

  /// Sync on unlock, resume, 10 s after local changes, on reconnect and
  /// every 5 minutes.
  realtime,
  every15Min,
  everyHour,
  every4Hours,
}

/// Passphrase setup of the connected sync folder.
enum SyncSetupState {
  unknown,

  /// The folder is empty: this device sets the sync passphrase.
  needsNewPassphrase,

  /// The folder exists: the user enters the passphrase set on the first
  /// device.
  needsPassphrase,
  ready,
}

class SyncState extends Equatable {
  final SyncStatus status;
  final SyncProviderType selectedProvider;
  final DateTime? lastSyncTime;

  /// Technical detail of the last error (logs, diagnostics, tests); the UI
  /// shows a localised text for [errorKind] instead.
  final String? errorMessage;

  /// Kind of the last error, null when there is none or it is unknown.
  final SyncErrorKind? errorKind;
  final String? accountEmail;
  final String? message;
  final double? progress;
  final bool wifiOnly;
  final SyncFrequency syncFrequency;
  final SyncSetupState setup;

  /// Local changes not uploaded yet.
  final int pendingChanges;
  final List<SyncConflictItem> conflicts;
  final List<SyncQuarantineItem> quarantine;

  /// A change file from a newer app version is waiting.
  final bool newerSchemaPending;

  /// The folder contains files of the old sync format.
  final bool legacyFilesFound;

  /// The app is locked: sync is paused.
  final bool paused;

  /// A received change file carries timestamps far in the future: another
  /// device's clock is off (its edits win every conflict until fixed).
  final bool clockSkewSuspected;

  /// Wi-Fi sync: the paired phone's clock minus this phone's clock, as
  /// last measured (null when unknown).
  final Duration? peerClockSkew;

  const SyncState({
    this.status = SyncStatus.disconnected,
    this.selectedProvider = SyncProviderType.none,
    this.lastSyncTime,
    this.errorMessage,
    this.errorKind,
    this.accountEmail,
    this.message,
    this.progress,
    this.wifiOnly = false,
    this.syncFrequency = SyncFrequency.realtime,
    this.setup = SyncSetupState.unknown,
    this.pendingChanges = 0,
    this.conflicts = const [],
    this.quarantine = const [],
    this.newerSchemaPending = false,
    this.legacyFilesFound = false,
    this.paused = false,
    this.clockSkewSuspected = false,
    this.peerClockSkew,
  });

  /// Quarantined files that failed to apply or do not authenticate (as
  /// opposed to newer-schema deferrals and leftovers of an old folder).
  List<SyncQuarantineItem> get failedFiles => quarantine
      .where((q) => q.reason == 'failed' || q.reason == 'unreadable')
      .toList();

  /// Files of an earlier sync folder (not readable with the current key).
  List<SyncQuarantineItem> get foreignFiles =>
      quarantine.where((q) => q.reason == 'foreign').toList();

  SyncState copyWith({
    SyncStatus? status,
    SyncProviderType? selectedProvider,
    DateTime? lastSyncTime,
    String? errorMessage,
    SyncErrorKind? errorKind,
    bool clearError = false,
    String? accountEmail,
    bool clearAccount = false,
    String? message,
    bool clearMessage = false,
    double? progress,
    bool? wifiOnly,
    SyncFrequency? syncFrequency,
    SyncSetupState? setup,
    int? pendingChanges,
    List<SyncConflictItem>? conflicts,
    List<SyncQuarantineItem>? quarantine,
    bool? newerSchemaPending,
    bool? legacyFilesFound,
    bool? paused,
    bool? clockSkewSuspected,
    Duration? peerClockSkew,
    bool clearPeerClockSkew = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      accountEmail: clearAccount ? null : (accountEmail ?? this.accountEmail),
      message: clearMessage ? null : (message ?? this.message),
      progress: progress ?? this.progress,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      setup: setup ?? this.setup,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      conflicts: conflicts ?? this.conflicts,
      quarantine: quarantine ?? this.quarantine,
      newerSchemaPending: newerSchemaPending ?? this.newerSchemaPending,
      legacyFilesFound: legacyFilesFound ?? this.legacyFilesFound,
      paused: paused ?? this.paused,
      clockSkewSuspected: clockSkewSuspected ?? this.clockSkewSuspected,
      peerClockSkew: clearPeerClockSkew
          ? null
          : (peerClockSkew ?? this.peerClockSkew),
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedProvider,
    lastSyncTime,
    errorMessage,
    errorKind,
    accountEmail,
    message,
    progress,
    wifiOnly,
    syncFrequency,
    setup,
    pendingChanges,
    conflicts,
    quarantine,
    newerSchemaPending,
    legacyFilesFound,
    paused,
    clockSkewSuspected,
    peerClockSkew,
  ];
}
