import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:ledger_zero/core/utils/device_utils.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class DeltaGenerationService {
  final AppDatabase _db;
  final DeltaFilenameGenerator _filenameGenerator;

  DeltaGenerationService(this._db, this._filenameGenerator);

  Future<void> processPendingChanges() async {
    final deviceUuid = await DeviceUtils.getDeviceUuid();
    final changes = await _db.pendingSyncChangesDao.getPendingChanges(limit: 50);

    if (changes.isEmpty) {
      return;
    }

    final docDir = await getApplicationDocumentsDirectory();
    final deltaDir = Directory('${docDir.path}/deltas');
    if (!await deltaDir.exists()) {
      await deltaDir.create(recursive: true);
    }

    for (final change in changes) {
      try {
        Map<String, dynamic>? data;

        if (change.action != 'DELETE') {
          // Fetch data for INSERT/UPDATE
          final result = await _db.customSelect(
            'SELECT * FROM ${change.targetTableName} WHERE id = ?',
            variables: [Variable.withString(change.recordId)],
            readsFrom: {},
          ).getSingleOrNull();

          if (result != null) {
            data = result.data;
          } else {
             // Data missing, treat as skipped or maybe it was deleted subsequently
             // If we skip, we assume a DELETE record is coming or it's a transient state.
             // We delete the pending change to avoid stuck queue.
             await _db.pendingSyncChangesDao.deleteChange(change.id);
             continue;
          }
        } else {
          // DELETE: include ID in data
          data = {'id': change.recordId};
        }

        final delta = SyncDelta(
          timestamp: DateTime.now().toUtc(),
          deviceUuid: deviceUuid,
          sequence: change.id,
          action: SyncAction.fromJson(change.action),
          tableName: change.targetTableName,
          data: data,
        );

        final filename = _filenameGenerator.generate(
          timestamp: delta.timestamp,
          deviceUuid: delta.deviceUuid,
          sequence: delta.sequence,
        );

        final file = File('${deltaDir.path}/$filename');
        await file.writeAsString(jsonEncode(delta.toJson()));

        // Log to SyncLog
        await _db.syncLogDao.insertSyncLog(
          SyncLogCompanion.insert(
            id: const Uuid().v4(),
            deltaFilename: Value(filename),
            action: Value(change.action),
            targetTableName: Value(change.targetTableName),
            recordId: Value(change.recordId),
            appliedAt: Value(DateTime.now()),
            deviceUuid: Value(deviceUuid),
          ),
        );

        // Remove from pending
        await _db.pendingSyncChangesDao.deleteChange(change.id);

      } catch (e, stackTrace) {
        Logger.error('Error generating delta for change ${change.id}', e, stackTrace);
      }
    }
  }
}
