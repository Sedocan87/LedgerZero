import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/sync/format/sync_change.dart';
import 'package:ledger_zero/services/sync/format/sync_file_codec.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';

/// A change file that cannot be applied (unknown table or column, a
/// constraint that cannot be resolved, ...). The file is quarantined.
class SyncApplyException implements Exception {
  final String message;
  const SyncApplyException(this.message);
  @override
  String toString() => 'SyncApplyException: $message';
}

/// Result of applying one file.
class ApplyResult {
  int applied = 0;
  int skipped = 0;
  int conflicts = 0;
  int repaired = 0;
}

/// This device's current version of a row (live row or tombstone).
class _Local {
  final Map<String, Object?>? row;
  final int version;
  final String deviceId;

  /// For versions written here: the sequence of the change file that
  /// carried it (0 = unknown/old, [_unsent] = not uploaded yet).
  final int? ownSequence;

  const _Local(this.row, this.version, this.deviceId, this.ownSequence);

  bool get exists => row != null;
}

const int _unsent = 1 << 62;

/// Applies decrypted change files to the database.
///
/// Each file is applied in one transaction:
/// * `sync_applying` is set, so the sync triggers ignore the writes (no
///   echo) and do not touch `updated_at`;
/// * `PRAGMA defer_foreign_keys = ON`: references are checked at commit, so
///   the order of rows inside the file does not matter;
/// * per row, the incoming version wins iff its `(version, deviceId)` is
///   greater than the local one (a pending, unsent local change competes
///   the same way; it does not win automatically). Deletes are tombstones
///   with the same rule. Unique natural keys (budgets per category and
///   month, one report note per date) are merged by the same rule;
/// * a local edit that loses against a concurrent remote edit with
///   different content is recorded in `sync_conflicts`;
/// * before commit, rows whose parent no longer exists (deleted on another
///   device) are repaired: nullable references are cleared, required
///   references and split children are deleted;
/// * [onCommit] runs last in the transaction (advances the high-water mark).
///
/// Any error rolls the whole file back.
class ChangeApplier {
  final AppDatabase _db;
  final SyncSchema _schema;
  final String _deviceId;

  ChangeApplier(this._db, this._schema, this._deviceId);

  Map<String, List<String>>? _foreignKeyColumns;

  Future<ApplyResult> apply(
    SyncFile file, {
    Future<void> Function()? onCommit,
    DateTime? now,
  }) {
    final result = ApplyResult();
    final header = file.header;
    final ordered = [...file.changes]
      ..sort((a, b) {
        if (a.deleted != b.deleted) {
          return a.deleted ? 1 : -1;
        }
        final ra = _schema[a.table]?.rank ?? 0;
        final rb = _schema[b.table]?.rank ?? 0;
        return a.deleted ? rb.compareTo(ra) : ra.compareTo(rb);
      });
    final applied = _db.transaction(() async {
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      await _db.customStatement(
        'INSERT OR REPLACE INTO sync_applying (id) VALUES (1)',
      );
      final resolvedAt = (now ?? DateTime.now()).toUtc();
      for (final change in ordered) {
        await _applyOne(change, header, result, resolvedAt);
      }
      result.repaired = await _repairForeignKeys();
      await _db.customStatement('DELETE FROM sync_applying');
      if (onCommit != null) {
        await onCommit();
      }
      return result;
    });
    // Raw SQL writes do not notify Drift's stream queries: tell them which
    // tables changed so open screens refresh after a sync.
    return applied.then((value) {
      final touched = {for (final c in file.changes) c.table};
      if (touched.isNotEmpty) {
        _db.notifyUpdates({
          for (final t in _db.allTables)
            if (touched.contains(t.actualTableName)) TableUpdate.onTable(t),
        });
      }
      return value;
    });
  }

  Future<void> _applyOne(
    SyncChange change,
    SyncFileHeader header,
    ApplyResult result,
    DateTime resolvedAt,
  ) async {
    final table = _schema[change.table];
    if (table == null) {
      throw SyncApplyException('unknown table ${change.table}');
    }
    if (!SyncFileName.deviceIdPattern.hasMatch(change.deviceId)) {
      throw const SyncApplyException('invalid device id in change');
    }
    final row = change.row;
    if (row != null) {
      for (final column in row.keys) {
        if (!table.hasColumn(column)) {
          throw SyncApplyException('unknown column ${table.name}.$column');
        }
      }
    }

    // Unique natural keys: another row (other id) may hold the same key.
    if (row != null) {
      for (final key in table.naturalKeys) {
        final values = [for (final c in key) row[c]];
        if (values.any((v) => v == null)) {
          continue;
        }
        final where = key.map((c) => '"$c" = ?').join(' AND ');
        final other = await _db
            .customSelect(
              'SELECT * FROM "${table.name}" WHERE $where AND id != ?',
              variables: [
                for (final v in values) SyncSchema.variable(v),
                Variable.withString(change.id),
              ],
            )
            .getSingleOrNull();
        if (other == null) {
          continue;
        }
        final otherId = other.data['id'] as String;
        final otherLocal = await _localVersion(table.name, otherId);
        if (otherLocal == null || !_wins(change, otherLocal)) {
          result.skipped++;
          return;
        }
        await _recordConflictIfNeeded(
          table.name,
          otherId,
          otherLocal,
          change,
          header,
          result,
          resolvedAt,
        );
        await _db.customStatement('DELETE FROM "${table.name}" WHERE id = ?', [
          otherId,
        ]);
        await _putVersion(
          table.name,
          otherId,
          otherLocal.version,
          otherLocal.deviceId,
          deleted: true,
        );
        await _clearPending(table.name, otherId);
      }
    }

    final local = await _localVersion(table.name, change.id);
    if (local != null && !_wins(change, local)) {
      result.skipped++;
      return;
    }
    if (local != null) {
      await _recordConflictIfNeeded(
        table.name,
        change.id,
        local,
        change,
        header,
        result,
        resolvedAt,
      );
    }

    final ownSequence =
        change.deviceId == _deviceId &&
            header.deviceId == _deviceId &&
            header.kind == SyncFileKind.changes
        ? header.sequence
        : null;
    if (change.deleted) {
      if (local?.exists ?? false) {
        await _db.customStatement('DELETE FROM "${table.name}" WHERE id = ?', [
          change.id,
        ]);
      }
      await _putVersion(
        table.name,
        change.id,
        change.version,
        change.deviceId,
        deleted: true,
        sequence: ownSequence,
      );
    } else {
      await _upsert(table, row!);
      await _putVersion(
        table.name,
        change.id,
        change.version,
        change.deviceId,
        deleted: false,
        sequence: ownSequence,
      );
    }
    // The local change (if any) lost: nothing left to send for this row.
    await _clearPending(table.name, change.id);
    result.applied++;
  }

  /// Incoming wins iff its (version, deviceId) is greater.
  static bool _wins(SyncChange incoming, _Local local) {
    if (incoming.version != local.version) {
      return incoming.version > local.version;
    }
    return incoming.deviceId.compareTo(local.deviceId) > 0;
  }

  Future<_Local?> _localVersion(String table, String id) async {
    final rowResult = await _db
        .customSelect(
          'SELECT * FROM "$table" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    final known = await _db.syncDao.getVersion(table, id);
    final pending = await _db
        .customSelect(
          'SELECT action, changed_at, old_updated_at FROM pending_sync_changes '
          'WHERE table_name = ? AND record_id = ? ORDER BY id DESC LIMIT 1',
          variables: [Variable.withString(table), Variable.withString(id)],
        )
        .getSingleOrNull();

    if (rowResult != null) {
      final row = Map<String, Object?>.of(rowResult.data);
      final version = SyncSchema.versionOf(row['updated_at']);
      if (pending == null &&
          known != null &&
          !known.deleted &&
          known.version == version) {
        return _Local(
          row,
          version,
          known.deviceId,
          known.deviceId == _deviceId ? (known.sequence ?? 0) : null,
        );
      }
      // Edited here and not sent yet (or never sent).
      return _Local(row, version, _deviceId, _unsent);
    }
    if (pending != null && pending.read<String>('action') == 'DELETE') {
      final changedAt = SyncSchema.versionOf(
        pending.readNullable<String>('changed_at'),
      );
      final oldUpdated = SyncSchema.versionOf(
        pending.readNullable<String>('old_updated_at'),
      );
      final version = changedAt > oldUpdated ? changedAt : oldUpdated + 1;
      return _Local(null, version, _deviceId, _unsent);
    }
    if (known != null && known.deleted) {
      return _Local(
        null,
        known.version,
        known.deviceId,
        known.deviceId == _deviceId ? (known.sequence ?? 0) : null,
      );
    }
    return null;
  }

  /// Records a conflict when a version written on this device is replaced
  /// by a remote version that was made without knowing it (the sender had
  /// not applied the file carrying it) and the content differs.
  Future<void> _recordConflictIfNeeded(
    String table,
    String rowId,
    _Local local,
    SyncChange incoming,
    SyncFileHeader header,
    ApplyResult result,
    DateTime resolvedAt,
  ) async {
    if (local.deviceId != _deviceId || incoming.deviceId == _deviceId) {
      return;
    }
    final known = header.vector[_deviceId] ?? 0;
    if (known >= (local.ownSequence ?? 0)) {
      return; // sequential edit: the sender had seen our version
    }
    if (SyncSchema.contentKey(local.row) ==
        SyncSchema.contentKey(incoming.row)) {
      return;
    }
    await _db.syncDao.addConflict(
      SyncConflictsCompanion.insert(
        syncTable: table,
        rowId: rowId,
        localSnapshot: Value(local.row == null ? null : jsonEncode(local.row)),
        remoteSnapshot: Value(
          incoming.row == null ? null : jsonEncode(incoming.row),
        ),
        remoteDeviceId: incoming.deviceId,
        resolvedAt: resolvedAt,
      ),
    );
    result.conflicts++;
  }

  Future<void> _upsert(SyncedTable table, Map<String, Object?> row) async {
    final columns = row.keys.toList();
    final quoted = columns.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(columns.length, '?').join(', ');
    final updates = columns
        .where((c) => c != 'id')
        .map((c) => '"$c" = excluded."$c"')
        .join(', ');
    final sql = updates.isEmpty
        ? 'INSERT OR IGNORE INTO "${table.name}" ($quoted) '
              'VALUES ($placeholders)'
        : 'INSERT INTO "${table.name}" ($quoted) VALUES ($placeholders) '
              'ON CONFLICT(id) DO UPDATE SET $updates';
    await _db.customStatement(sql, [for (final c in columns) row[c]]);
  }

  Future<void> _putVersion(
    String table,
    String rowId,
    int version,
    String deviceId, {
    required bool deleted,
    int? sequence,
  }) {
    return _db.syncDao.putVersion(
      SyncRowVersionsCompanion.insert(
        syncTable: table,
        rowId: rowId,
        version: version,
        deviceId: deviceId,
        deleted: Value(deleted),
        sequence: Value(sequence),
      ),
    );
  }

  Future<void> _clearPending(String table, String id) {
    return _db.customStatement(
      'DELETE FROM pending_sync_changes WHERE table_name = ? AND record_id = ?',
      [table, id],
    );
  }

  /// Resolves rows that reference a missing parent (see class docs).
  /// Returns the number of repaired rows.
  Future<int> _repairForeignKeys() async {
    var repaired = 0;
    for (var round = 0; round < 16; round++) {
      final violations = await _db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (violations.isEmpty) {
        return repaired;
      }
      for (final v in violations) {
        final table = v.data['table'] as String;
        final rowid = v.data['rowid'] as int?;
        final fkid = v.data['fkid'] as int;
        if (_schema[table] == null || rowid == null) {
          throw SyncApplyException('foreign key violation in $table');
        }
        final column = (await _foreignKeyColumnsOf(table))[fkid] ?? '';
        if (column.isEmpty) {
          throw SyncApplyException('unknown foreign key in $table');
        }
        final idRow = await _db
            .customSelect(
              'SELECT id FROM "$table" WHERE rowid = ?',
              variables: [Variable.withInt(rowid)],
            )
            .getSingleOrNull();
        if (idRow == null) {
          continue; // already removed in this round
        }
        final id = idRow.read<String>('id');
        if (_schema.deletesOnMissingParent(table, column)) {
          Logger.info('Sync: deleting $table row whose $column is gone');
          await _db.customStatement('DELETE FROM "$table" WHERE rowid = ?', [
            rowid,
          ]);
          await _db.syncDao.deleteVersion(table, id);
          await _clearPending(table, id);
        } else {
          Logger.info('Sync: clearing $table.$column (parent deleted)');
          await _db.customStatement(
            'UPDATE "$table" SET "$column" = NULL WHERE rowid = ?',
            [rowid],
          );
        }
        repaired++;
      }
    }
    throw const SyncApplyException('foreign keys could not be resolved');
  }

  Future<Map<int, String>> _foreignKeyColumnsOf(String table) async {
    final cache = _foreignKeyColumns ??= {};
    final cached = cache[table];
    if (cached != null) {
      return cached.asMap();
    }
    final rows = await _db
        .customSelect('PRAGMA foreign_key_list("$table")')
        .get();
    final byId = <int, String>{};
    for (final r in rows) {
      byId[r.data['id'] as int] = r.data['from'] as String;
    }
    final maxId = byId.keys.fold<int>(-1, (a, b) => a > b ? a : b);
    cache[table] = [for (var i = 0; i <= maxId; i++) byId[i] ?? ''];
    return cache[table]!.asMap();
  }
}
