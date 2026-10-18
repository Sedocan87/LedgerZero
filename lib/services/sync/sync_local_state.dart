import 'dart:convert';
import 'dart:typed_data';

import 'package:ledger_zero/data/database/daos/sync_dao.dart';

/// How the next run uploads every local row.
enum FullUpload {
  none,

  /// Every row, whatever its age: joining a folder that has never seen
  /// this device's data (new sync set).
  everything,

  /// Re-sharing with a folder that already knows this device (after a
  /// restore or a reconnect): rows older than the tombstone retention are
  /// sent only if this device's version is newer than the one the folder
  /// knows, so a row deleted elsewhere long enough ago for its tombstone
  /// to be pruned does not come back (docs/SYNC_ARCHITECTURE.md, "Restore").
  reshare,
}

/// Typed access to the `sync_kv` entries. Everything here lives in the
/// encrypted database, including the derived sync key (never in
/// SharedPreferences or plain files).
class SyncLocalState {
  final SyncDao _dao;

  SyncLocalState(this._dao);

  static const String _syncKey = 'sync_key';
  static const String _syncId = 'sync_id';
  static const String _ownSequence = 'own_sequence';
  static const String _fullUpload = 'full_upload_required';
  static const String _snapshots = 'own_snapshots';
  static const String _snapshotClock = 'snapshot_clock_started';
  static const String deviceIdKey = 'device_id';
  static const String _needsSnapshot = 'needs_snapshot';

  Future<Uint8List?> syncKey() async {
    final value = await _dao.getValue(_syncKey);
    return value == null ? null : Uint8List.fromList(base64.decode(value));
  }

  Future<String?> syncId() => _dao.getValue(_syncId);

  /// The device id as last used with this database (see `SyncDeviceId`).
  Future<String?> deviceId() => _dao.getValue(deviceIdKey);

  Future<void> setDeviceId(String id) => _dao.setValue(deviceIdKey, id);

  Future<void> setSyncKey(String syncId, Uint8List key) async {
    await _dao.setValue(_syncId, syncId);
    await _dao.setValue(_syncKey, base64.encode(key));
  }

  Future<void> forgetSyncKey() async {
    await _dao.deleteValue(_syncKey);
  }

  Future<int> ownSequence() async =>
      int.tryParse(await _dao.getValue(_ownSequence) ?? '') ?? 0;

  Future<void> setOwnSequence(int value) =>
      _dao.setValue(_ownSequence, '$value');

  /// Whether the next run uploads every row, and how (see [FullUpload]).
  Future<FullUpload> fullUpload() async =>
      switch (await _dao.getValue(_fullUpload)) {
        '1' => FullUpload.everything,
        'reshare' => FullUpload.reshare,
        _ => FullUpload.none,
      };

  Future<void> setFullUpload(FullUpload value) => switch (value) {
    FullUpload.none => _dao.deleteValue(_fullUpload),
    FullUpload.everything => _dao.setValue(_fullUpload, '1'),
    FullUpload.reshare => _dao.setValue(_fullUpload, 'reshare'),
  };

  /// Own snapshots written so far: sequence -> creation time.
  Future<Map<int, DateTime>> ownSnapshots() async {
    final raw = await _dao.getValue(_snapshots);
    if (raw == null) {
      return {};
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in json.entries)
          int.parse(e.key): DateTime.parse(e.value as String).toUtc(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> setOwnSnapshots(Map<int, DateTime> snapshots) {
    return _dao.setValue(
      _snapshots,
      jsonEncode({
        for (final e in snapshots.entries)
          '${e.key}': e.value.toUtc().toIso8601String(),
      }),
    );
  }

  /// Devices whose file was skipped here: device -> sequence of the skipped
  /// file. A snapshot of that device covering the sequence repairs the gap.
  Future<Map<String, int>> needsSnapshot() async {
    final raw = await _dao.getValue(_needsSnapshot);
    if (raw == null) {
      return {};
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in json.entries) e.key: e.value as int};
    } catch (_) {
      return {};
    }
  }

  Future<void> setNeedsSnapshot(Map<String, int> value) => value.isEmpty
      ? _dao.deleteValue(_needsSnapshot)
      : _dao.setValue(_needsSnapshot, jsonEncode(value));

  /// When this device started counting towards its first snapshot.
  Future<DateTime?> snapshotClock() async {
    final raw = await _dao.getValue(_snapshotClock);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> setSnapshotClock(DateTime time) =>
      _dao.setValue(_snapshotClock, time.toUtc().toIso8601String());
}
