import 'dart:convert';
import 'dart:typed_data';

import 'package:ledger_zero/data/database/daos/sync_dao.dart';

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

  Future<bool> fullUploadRequired() async =>
      await _dao.getValue(_fullUpload) == '1';

  Future<void> setFullUploadRequired(bool value) =>
      value ? _dao.setValue(_fullUpload, '1') : _dao.deleteValue(_fullUpload);

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

  /// When this device started counting towards its first snapshot.
  Future<DateTime?> snapshotClock() async {
    final raw = await _dao.getValue(_snapshotClock);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> setSnapshotClock(DateTime time) =>
      _dao.setValue(_snapshotClock, time.toUtc().toIso8601String());
}
