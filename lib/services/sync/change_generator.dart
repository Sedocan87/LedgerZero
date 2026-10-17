import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/sync/format/sync_change.dart';
import 'package:ledger_zero/services/sync/format/sync_file_codec.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/personal_rows.dart';
import 'package:ledger_zero/services/sync/sync_local_state.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';

/// Turns captured local changes (`pending_sync_changes`) into encrypted
/// change files in the [SyncOutbox].
///
/// One sync run produces one file, or several when it has more than
/// [maxChangesPerFile] changes. Changes are squashed per row: an upsert
/// carries the row as it is now, a delete becomes a tombstone. Files are
/// cut only between "families" of rows (a split parent and its children, the
/// two legs of a transfer), upserts come parents-first and deletes
/// children-first, so a receiver can apply each file on its own. The rows
/// of personal accounts ([PersonalRows]) are left out.
class ChangeGenerator {
  final AppDatabase _db;
  final SyncSchema _schema;
  final SyncLocalState _state;
  final String _deviceId;
  final int maxChangesPerFile;

  ChangeGenerator(
    this._db,
    this._schema,
    this._state,
    this._deviceId, {
    this.maxChangesPerFile = 2000,
  });

  /// Writes change files for all pending changes (and, if [fullUpload], for
  /// every row of every synced table) to [outbox]. Returns their names.
  ///
  /// Everything happens in one database transaction: the files are written
  /// first, then the pending changes are deleted and the sequence advanced.
  /// If the transaction fails the files are orphans with sequences above the
  /// committed one, which the next run deletes.
  Future<List<SyncFileName>> generate({
    required Uint8List key,
    required SyncOutbox outbox,
    bool fullUpload = false,
    DateTime? now,
  }) async {
    final committed = await _state.ownSequence();
    await outbox.removeAbove(_deviceId, committed);

    return _db.transaction(() async {
      final pendingRows = await _db
          .customSelect(
            'SELECT id, table_name, record_id, action, changed_at, '
            'old_updated_at FROM pending_sync_changes ORDER BY id',
          )
          .get();
      final aggregates = <(String, String), _Aggregate>{};
      var maxPendingId = 0;
      for (final row in pendingRows) {
        final id = row.read<int>('id');
        maxPendingId = math.max(maxPendingId, id);
        final table = row.read<String>('table_name');
        if (_schema[table] == null) {
          continue;
        }
        final recordId = row.read<String>('record_id');
        final aggregate = aggregates.putIfAbsent((
          table,
          recordId,
        ), () => _Aggregate());
        aggregate.local = true;
        if (row.read<String>('action') == 'DELETE') {
          aggregate.deleteVersion = math.max(
            aggregate.deleteVersion,
            math.max(
              SyncSchema.versionOf(row.readNullable<String>('changed_at')),
              SyncSchema.versionOf(row.readNullable<String>('old_updated_at')) +
                  1,
            ),
          );
        }
      }

      if (fullUpload) {
        for (final table in SyncSchema.dependencyOrder) {
          final ids = await _db.customSelect('SELECT id FROM "$table"').get();
          for (final r in ids) {
            aggregates.putIfAbsent((
              table,
              r.read<String>('id'),
            ), () => _Aggregate());
          }
        }
      }

      if (aggregates.isEmpty) {
        if (maxPendingId > 0) {
          await _deletePending(maxPendingId);
        }
        return const <SyncFileName>[];
      }

      final rows = await _fetchRows(aggregates.keys);
      final versions = await _fetchVersions(aggregates.keys);
      final personal = await PersonalRows.load(_db);

      final upserts = <_Entry>[];
      final deletes = <_Entry>[];
      aggregates.forEach((k, aggregate) {
        final (table, id) = k;
        final row = rows[k];
        final known = versions[k];
        if (row != null) {
          if (personal.isPrivate(table, row)) {
            return; // stays on this device (personal account)
          }
          final version = SyncSchema.versionOf(row['updated_at']);
          // Rows edited here are this device's versions; rows that only
          // pass through a full upload keep the device that wrote them.
          final device =
              !aggregate.local &&
                  known != null &&
                  !known.deleted &&
                  known.version == version
              ? known.deviceId
              : _deviceId;
          upserts.add(
            _Entry(
              SyncChange(
                table: table,
                id: id,
                deleted: false,
                version: version,
                deviceId: device,
                row: row,
              ),
              _familyKey(table, row),
              _schema[table]!.rank,
            ),
          );
        } else {
          if (!aggregate.local) {
            return; // vanished during a full upload; nothing was captured
          }
          if (known != null && known.deleted) {
            return; // already a tombstone (e.g. deleted by replay)
          }
          final version = aggregate.deleteVersion > 0
              ? aggregate.deleteVersion
              : (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
          deletes.add(
            _Entry(
              SyncChange(
                table: table,
                id: id,
                deleted: true,
                version: version,
                deviceId: _deviceId,
              ),
              '$table:$id',
              _schema[table]!.rank,
            ),
          );
        }
      });

      upserts.sort((a, b) {
        final byRank = a.rank.compareTo(b.rank);
        if (byRank != 0) {
          return byRank;
        }
        final byFamily = a.family.compareTo(b.family);
        return byFamily != 0 ? byFamily : a.change.id.compareTo(b.change.id);
      });
      deletes.sort((a, b) {
        final byRank = b.rank.compareTo(a.rank);
        return byRank != 0 ? byRank : a.change.id.compareTo(b.change.id);
      });

      final chunks = _chunk([...upserts, ...deletes]);
      final vector = await _db.syncDao.getProgress()
        ..remove(_deviceId);
      final createdAt = (now ?? DateTime.now()).toUtc();
      var sequence = committed;
      final written = <SyncFileName>[];
      for (final chunk in chunks) {
        sequence++;
        final changes = [for (final e in chunk) e.change];
        final header = SyncFileHeader(
          kind: SyncFileKind.changes,
          deviceId: _deviceId,
          sequence: sequence,
          schemaVersion: _schema.schemaVersion,
          changeCount: changes.length,
          maxVersion: changes.map((c) => c.version).reduce(math.max),
          vector: vector,
          createdAt: createdAt,
        );
        final bytes = SyncFileCodec.encode(
          header: header,
          changes: changes,
          key: key,
        );
        await outbox.write(header.fileName, bytes);
        written.add(header.fileName);
        for (final change in changes) {
          await _db.syncDao.putVersion(
            SyncRowVersionsCompanion.insert(
              syncTable: change.table,
              rowId: change.id,
              version: change.version,
              deviceId: change.deviceId,
              deleted: Value(change.deleted),
              sequence: Value(change.deviceId == _deviceId ? sequence : null),
            ),
          );
        }
      }

      await _state.setOwnSequence(sequence);
      await _db.syncDao.setProgress(_deviceId, sequence);
      if (maxPendingId > 0) {
        await _deletePending(maxPendingId);
      }
      return written;
    });
  }

  Future<void> _deletePending(int maxId) {
    return _db.customStatement(
      'DELETE FROM pending_sync_changes WHERE id <= ?',
      [maxId],
    );
  }

  List<List<_Entry>> _chunk(List<_Entry> entries) {
    final chunks = <List<_Entry>>[];
    var current = <_Entry>[];
    String? lastFamily;
    for (final entry in entries) {
      final family = '${entry.change.deleted}:${entry.rank}:${entry.family}';
      if (current.length >= maxChangesPerFile && family != lastFamily) {
        chunks.add(current);
        current = <_Entry>[];
      }
      current.add(entry);
      lastFamily = family;
    }
    if (current.isNotEmpty) {
      chunks.add(current);
    }
    return chunks;
  }

  /// Rows that must travel in the same file: a split parent and its
  /// children, the two legs of a transfer.
  static String _familyKey(String table, Map<String, Object?> row) {
    final id = row['id'] as String;
    if (table != 'transactions') {
      return id;
    }
    final parent = row['parent_transaction_id'] as String?;
    if (parent != null) {
      return parent;
    }
    final counterpart = row['transfer_transaction_id'] as String?;
    if (counterpart != null && counterpart.compareTo(id) < 0) {
      return counterpart;
    }
    return id;
  }

  Future<Map<(String, String), Map<String, Object?>>> _fetchRows(
    Iterable<(String, String)> keys,
  ) async {
    final byTable = <String, List<String>>{};
    for (final (table, id) in keys) {
      byTable.putIfAbsent(table, () => []).add(id);
    }
    final result = <(String, String), Map<String, Object?>>{};
    for (final entry in byTable.entries) {
      final ids = entry.value;
      for (var i = 0; i < ids.length; i += 500) {
        final chunk = ids.sublist(i, math.min(i + 500, ids.length));
        final rows = await _db
            .customSelect(
              'SELECT * FROM "${entry.key}" WHERE id IN '
              '(${List.filled(chunk.length, '?').join(',')})',
              variables: [for (final id in chunk) Variable.withString(id)],
            )
            .get();
        for (final row in rows) {
          result[(entry.key, row.data['id'] as String)] = Map.of(row.data);
        }
      }
    }
    return result;
  }

  Future<Map<(String, String), SyncRowVersion>> _fetchVersions(
    Iterable<(String, String)> keys,
  ) async {
    final byTable = <String, List<String>>{};
    for (final (table, id) in keys) {
      byTable.putIfAbsent(table, () => []).add(id);
    }
    final result = <(String, String), SyncRowVersion>{};
    for (final entry in byTable.entries) {
      final ids = entry.value;
      for (var i = 0; i < ids.length; i += 500) {
        final chunk = ids.sublist(i, math.min(i + 500, ids.length));
        final query = _db.select(_db.syncRowVersions)
          ..where((t) => t.syncTable.equals(entry.key) & t.rowId.isIn(chunk));
        for (final v in await query.get()) {
          result[(v.syncTable, v.rowId)] = v;
        }
      }
    }
    return result;
  }
}

class _Aggregate {
  /// Captured by the triggers (as opposed to added by a full upload).
  bool local = false;

  /// Tombstone time of the latest captured delete (µs), 0 if none.
  int deleteVersion = 0;
}

class _Entry {
  final SyncChange change;
  final String family;
  final int rank;

  _Entry(this.change, this.family, this.rank);
}
