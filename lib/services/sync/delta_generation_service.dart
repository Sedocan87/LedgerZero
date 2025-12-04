import 'package:drift/drift.dart';
import 'package:ledger_zero/core/utils/device_utils.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeltaGenerationService {
  final AppDatabase _db;
  final LocalDeltaQueue _localDeltaQueue;

  DeltaGenerationService(this._db, this._localDeltaQueue);

  Future<void> processPendingChanges() async {
    final deviceUuid = await DeviceUtils.getDeviceUuid();

    // Task 388: Get App Version
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;
    final schemaVersion = _db.schemaVersion;

    // Fetch changes - increased limit for better batching/squashing
    final changes = await _db.pendingSyncChangesDao.getPendingChanges(limit: 100);

    if (changes.isEmpty) {
      return;
    }

    // Task 390: Deduplication / Squashing
    // Group changes by table and record ID
    final groupedChanges = <String, List<PendingSyncChange>>{};
    for (final change in changes) {
      final key = '${change.targetTableName}:${change.recordId}';
      groupedChanges.putIfAbsent(key, () => []).add(change);
    }

    for (final group in groupedChanges.values) {
      if (group.isEmpty) {
        continue;
      }

      // Sort by ID to ensure correct sequence
      group.sort((a, b) => a.id.compareTo(b.id));

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
            // Created then Deleted locally -> Net effect is nothing.
            shouldGenerateDelta = false;
          } else {
            effectiveAction = SyncAction.delete;
            data = {'id': recordId};
          }
        } else {
          // INSERT or UPDATE
          // Fetch current data
          final result = await _db.customSelect(
            'SELECT * FROM $tableName WHERE id = ?',
            variables: [Variable.withString(recordId)],
            readsFrom: {},
          ).getSingleOrNull();

          if (result == null) {
            // Data missing despite last action being INSERT/UPDATE.
            // This suggests inconsistent state or concurrent deletion not yet picked up.
            // We will skip generating a delta but consume the changes to unblock the queue.
            Logger.warning('Data missing for $tableName:$recordId during delta generation. Skipping.');
            shouldGenerateDelta = false;
          } else {
            data = result.data;
            // If the first action was INSERT, we treat the net result as INSERT.
            // Otherwise, it's an UPDATE.
            if (firstChange.action == 'INSERT') {
              effectiveAction = SyncAction.insert;
            } else {
              effectiveAction = SyncAction.update;
            }
          }
        }

        if (shouldGenerateDelta && effectiveAction != null) {
          // Use the ID of the last change for the sequence number of the delta
          // This ensures strict ordering if we have multiple deltas for different records.
          final sequence = lastChange.id;

          final delta = SyncDelta(
            timestamp: DateTime.now().toUtc(),
            deviceUuid: deviceUuid,
            sequence: sequence,
            action: effectiveAction,
            tableName: tableName,
            data: data,
            schemaVersion: schemaVersion,
            appVersion: appVersion,
          );

          // Task 386 & 387 & 389: Enqueue (writes compressed file)
          final file = await _localDeltaQueue.enqueue(delta);
          final filename = file.uri.pathSegments.last;

          // Log to SyncLog
          // We log the net action.
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

        // Cleanup processed changes
        // We delete all changes in this group
        for (final change in group) {
          await _db.pendingSyncChangesDao.deleteChange(change.id);
        }

      } catch (e, stackTrace) {
        Logger.error('Error processing changes for $tableName:$recordId', e, stackTrace);
        // We do NOT delete the changes if an error occurs, so we can retry.
      }
    }
  }
}
