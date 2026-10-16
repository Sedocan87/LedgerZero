import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';

/// The user's choices for a recorded sync conflict.
class SyncConflictResolver {
  final AppDatabase _db;
  late final SyncSchema _schema = SyncSchema.of(_db);

  SyncConflictResolver(this._db);

  /// Removes the conflict from the list; the remote version stays.
  Future<void> dismiss(int conflictId) =>
      _db.syncDao.deleteConflict(conflictId);

  /// Re-applies the local snapshot as a new local edit (current time as
  /// `updated_at`), which then syncs to the other devices and wins there.
  /// If the local version was a delete, the row is deleted again.
  ///
  /// Throws if the snapshot can no longer be written (e.g. it references a
  /// row that was deleted since).
  Future<void> keepMine(int conflictId, {DateTime? now}) async {
    final conflict = await _db.syncDao.getConflict(conflictId);
    if (conflict == null) {
      return;
    }
    final table = _schema[conflict.syncTable];
    if (table == null) {
      await _db.syncDao.deleteConflict(conflictId);
      return;
    }
    await _db.transaction(() async {
      final snapshot = conflict.localSnapshot;
      if (snapshot == null) {
        await _db.customStatement('DELETE FROM "${table.name}" WHERE id = ?', [
          conflict.rowId,
        ]);
      } else {
        final row = Map<String, Object?>.from(
          jsonDecode(snapshot) as Map<String, dynamic>,
        );
        row.removeWhere((column, _) => !table.hasColumn(column));
        if (table.hasColumn('updated_at')) {
          // Newer than every version seen, so it wins on every device.
          final current = await _db
              .customSelect(
                'SELECT updated_at FROM "${table.name}" WHERE id = ?',
                variables: [Variable.withString(conflict.rowId)],
              )
              .getSingleOrNull();
          final known = await _db.syncDao.getVersion(
            table.name,
            conflict.rowId,
          );
          var micros = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
          for (final v in [
            SyncSchema.versionOf(current?.data['updated_at']),
            known?.version ?? 0,
          ]) {
            if (v >= micros) {
              micros = v + 1000;
            }
          }
          row['updated_at'] = DateTime.fromMicrosecondsSinceEpoch(
            micros,
            isUtc: true,
          ).toIso8601String();
        }
        // The remote winner may hold the same natural key under another id.
        for (final key in table.naturalKeys) {
          final values = [for (final c in key) row[c]];
          if (values.any((v) => v == null)) {
            continue;
          }
          await _db.customStatement(
            'DELETE FROM "${table.name}" WHERE '
            '${key.map((c) => '"$c" = ?').join(' AND ')} AND id != ?',
            [...values, conflict.rowId],
          );
        }
        final columns = row.keys.toList();
        await _db.customStatement(
          'INSERT INTO "${table.name}" '
          '(${columns.map((c) => '"$c"').join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')}) '
          'ON CONFLICT(id) DO UPDATE SET '
          '${columns.where((c) => c != 'id').map((c) => '"$c" = excluded."$c"').join(', ')}',
          [for (final c in columns) row[c]],
        );
      }
      await _db.syncDao.deleteConflict(conflictId);
    });
    _db.notifyUpdates({
      for (final t in _db.allTables)
        if (t.actualTableName == table.name) TableUpdate.onTable(t),
    });
  }
}
