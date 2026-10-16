import 'package:equatable/equatable.dart';

/// A local edit that lost against a newer edit from another device, as the
/// sync screens show it. Mapped from the `sync_conflicts` row by the sync
/// controller, so presentation never depends on Drift row types.
class SyncConflictItem extends Equatable {
  const SyncConflictItem({
    required this.id,
    required this.syncTable,
    required this.rowId,
    required this.localSnapshot,
    required this.remoteSnapshot,
    required this.remoteDeviceId,
    required this.resolvedAt,
  });

  final int id;

  /// Synced table name, e.g. `payees`.
  final String syncTable;
  final String rowId;

  /// JSON of the local row that was overwritten; null if it was a delete.
  final String? localSnapshot;

  /// JSON of the winning remote row; null if the remote change was a delete.
  final String? remoteSnapshot;
  final String remoteDeviceId;
  final DateTime resolvedAt;

  @override
  List<Object?> get props => [
    id,
    syncTable,
    rowId,
    localSnapshot,
    remoteSnapshot,
    remoteDeviceId,
    resolvedAt,
  ];
}

/// A change file that could not be applied (or waits for a newer app
/// version), as the sync screens show it.
class SyncQuarantineItem extends Equatable {
  const SyncQuarantineItem({
    required this.filename,
    required this.deviceId,
    required this.sequence,
    required this.reason,
    required this.error,
    required this.attempts,
    required this.firstSeen,
    required this.lastAttempt,
    required this.nextAttempt,
  });

  final String filename;
  final String deviceId;
  final int sequence;

  /// `failed` (decrypt/parse/apply error) or `newer_schema`.
  final String reason;
  final String error;
  final int attempts;
  final DateTime firstSeen;
  final DateTime lastAttempt;
  final DateTime nextAttempt;

  @override
  List<Object?> get props => [
    filename,
    deviceId,
    sequence,
    reason,
    error,
    attempts,
    firstSeen,
    lastAttempt,
    nextAttempt,
  ];
}
