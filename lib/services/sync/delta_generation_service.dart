import 'package:drift/drift.dart';
import 'package:ledger_zero/core/utils/device_utils.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'dart:async';

import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeltaGenerationService {
  final AppDatabase _db;
  final LocalDeltaQueue _localDeltaQueue;
  final SharedPreferences _prefs;
  final _sequenceLock = _Mutex();

  static const String _lastSequenceKey = 'last_delta_sequence';

  DeltaGenerationService(this._db, this._localDeltaQueue, this._prefs);

  Future<int> _getNextSequence() {
    return _sequenceLock.protect(() async {
      final current = _prefs.getInt(_lastSequenceKey) ?? 0;
      final next = current + 1;
      await _prefs.setInt(_lastSequenceKey, next);
      return next;
    });
  }

  Future<void> processPendingChanges() async {
    final deviceUuid = await DeviceUtils.getDeviceUuid();
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;
    final schemaVersion = _db.schemaVersion;

    while (true) {
      final changes = await _db.pendingSyncChangesDao.getPendingChanges(limit: 500);

      if (changes.isEmpty) {
        break;
      }

      int processedChangesCount = 0;

      final groupedChanges = <String, List<PendingSyncChange>>{};
      for (final change in changes) {
        final key = '${change.targetTableName}:${change.recordId}';
        groupedChanges.putIfAbsent(key, () => []).add(change);
      }

      final fetchNeeded = <String, Set<String>>{};

      for (final group in groupedChanges.values) {
        if (group.isEmpty) continue;
        group.sort((a, b) => a.id.compareTo(b.id));

        final first = group.first;
        final last = group.last;

        if (last.action != 'DELETE') {
          fetchNeeded
              .putIfAbsent(first.targetTableName, () => {})
              .add(first.recordId);
        }
      }

      final fetchedData = <String, Map<String, Map<String, dynamic>>>{};

      for (final table in fetchNeeded.keys) {
        final ids = fetchNeeded[table]!.toList();
        if (ids.isEmpty) continue;

        const chunkSize = 500;
        for (var i = 0; i < ids.length; i += chunkSize) {
          final chunk = ids.sublist(
              i, i + chunkSize < ids.length ? i + chunkSize : ids.length);

          final sql =
              'SELECT * FROM $table WHERE id IN (${chunk.map((_) => '?').join(',')})';
          final rows = await _db.customSelect(
            sql,
            variables: chunk.map((id) => Variable.withString(id)).toList(),
            readsFrom: {},
          ).get();

          for (final row in rows) {
            fetchedData.putIfAbsent(table, () => {})[row.data['id'].toString()] =
                row.data;
          }
        }
      }

      for (final group in groupedChanges.values) {
        if (group.isEmpty) continue;

        final firstChange = group.first;
        final lastChange = group.last;

        final tableName = firstChange.targetTableName;
        final recordId = firstChange.recordId;

        try {
          SyncAction? effectiveAction;
          Map<String, dynamic>? data;
          bool shouldGenerateDelta = true;

          if (lastChange.action == 'DELETE') {
            if (firstChange.action == 'INSERT') {
              shouldGenerateDelta = false;
            } else {
              effectiveAction = SyncAction.delete;
              data = {'id': recordId};
            }
          } else {
            data = fetchedData[tableName]?[recordId];

            if (data == null) {
              Logger.warning('Data missing for $tableName:$recordId during delta generation. Skipping.');
              shouldGenerateDelta = false;
            } else {
              if (firstChange.action == 'INSERT') {
                effectiveAction = SyncAction.insert;
              } else {
                effectiveAction = SyncAction.update;
              }
            }
          }

          if (shouldGenerateDelta && effectiveAction != null) {
            final sequence = await _getNextSequence();

            var delta = SyncDelta(
              timestamp: DateTime.now().toUtc(),
              deviceUuid: deviceUuid,
              sequence: sequence,
              action: effectiveAction,
              tableName: tableName,
              data: data,
              schemaVersion: schemaVersion,
              appVersion: appVersion,
            );

            final checksum = delta.calculateChecksum();
            delta = delta.copyWith(checksum: checksum);

            delta.validate();

            final file = await _localDeltaQueue.enqueue(delta);
            final filename = file.uri.pathSegments.last;

            await _db.syncLogDao.insertSyncLog(
              SyncLogCompanion.insert(
                id: const Uuid().v4(),
                deltaFilename: Value(filename),
                action: Value(effectiveAction.toJson()),
                targetTableName: Value(tableName),
                recordId: Value(recordId),
                appliedAt: Value(DateTime.now()),
                deviceUuid: Value(deviceUuid),
              ),
            );
          }

          for (final change in group) {
            await _db.pendingSyncChangesDao.deleteChange(change.id);
          }
          processedChangesCount += group.length;
        } catch (e, stackTrace) {
          Logger.error(
              'Error processing changes for $tableName:$recordId', e, stackTrace);
        }
      }

      if (processedChangesCount == 0) {
        Logger.warning(
            'ProcessPendingChanges: Fetched ${changes.length} changes but failed to process any. Breaking to avoid infinite loop.');
        break;
      }
    }
  }

  Future<Set<String>> getAppliedDeltaFilenames() async {
    final list = await _db.syncLogDao.getAllFilenames();
    return list.toSet();
  }
}

class _Mutex {
  Future<void> _last = Future.value();

  Future<T> protect<T>(Future<T> Function() block) async {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;
    try {
      await prev;
      return await block();
    } finally {
      completer.complete();
    }
  }
}
