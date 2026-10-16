import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/pending_sync_changes.dart';
import 'package:ledger_zero/data/database/tables/sync_tables.dart';

part 'sync_dao.g.dart';

/// Local sync bookkeeping (see `sync_tables.dart`).
@DriftAccessor(
  tables: [
    SyncDeviceProgress,
    SyncKv,
    SyncRowVersions,
    SyncConflicts,
    SyncQuarantine,
    PendingSyncChanges,
  ],
)
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  // --- key-value ---

  Future<String?> getValue(String key) async {
    final row = await (select(
      syncKv,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) {
    return into(
      syncKv,
    ).insertOnConflictUpdate(SyncKvCompanion.insert(key: key, value: value));
  }

  Future<void> deleteValue(String key) {
    return (delete(syncKv)..where((t) => t.key.equals(key))).go();
  }

  // --- per-device high-water marks ---

  Future<Map<String, int>> getProgress() async {
    final rows = await select(syncDeviceProgress).get();
    return {for (final r in rows) r.deviceId: r.lastSequence};
  }

  Future<void> setProgress(String deviceId, int sequence) {
    return into(syncDeviceProgress).insertOnConflictUpdate(
      SyncDeviceProgressCompanion.insert(
        deviceId: deviceId,
        lastSequence: Value(sequence),
      ),
    );
  }

  Future<void> clearProgress() => delete(syncDeviceProgress).go();

  // --- row versions / tombstones ---

  Future<SyncRowVersion?> getVersion(String table, String rowId) {
    return (select(syncRowVersions)
          ..where((t) => t.syncTable.equals(table) & t.rowId.equals(rowId)))
        .getSingleOrNull();
  }

  Future<void> putVersion(SyncRowVersionsCompanion version) {
    return into(syncRowVersions).insertOnConflictUpdate(version);
  }

  Future<void> deleteVersion(String table, String rowId) {
    return (delete(
      syncRowVersions,
    )..where((t) => t.syncTable.equals(table) & t.rowId.equals(rowId))).go();
  }

  /// All tombstones (for snapshots).
  Future<List<SyncRowVersion>> getTombstones() {
    return (select(
      syncRowVersions,
    )..where((t) => t.deleted.equals(true))).get();
  }

  /// Deletes tombstones whose version is older than [cutoffMicros].
  Future<int> pruneTombstones(int cutoffMicros) {
    return (delete(syncRowVersions)..where(
          (t) =>
              t.deleted.equals(true) &
              t.version.isSmallerThanValue(cutoffMicros),
        ))
        .go();
  }

  // --- conflicts ---

  Future<int> addConflict(SyncConflictsCompanion conflict) {
    return into(syncConflicts).insert(conflict);
  }

  Stream<List<SyncConflict>> watchConflicts() {
    return (select(syncConflicts)..orderBy([
          (t) =>
              OrderingTerm(expression: t.resolvedAt, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<List<SyncConflict>> getConflicts() => select(syncConflicts).get();

  Future<SyncConflict?> getConflict(int id) {
    return (select(
      syncConflicts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> deleteConflict(int id) {
    return (delete(syncConflicts)..where((t) => t.id.equals(id))).go();
  }

  /// Keeps the newest [keep] conflicts.
  Future<void> trimConflicts(int keep) {
    return customStatement(
      'DELETE FROM sync_conflicts WHERE id NOT IN '
      '(SELECT id FROM sync_conflicts ORDER BY id DESC LIMIT $keep)',
    );
  }

  // --- quarantine ---

  Future<List<SyncQuarantineData>> getQuarantine() {
    return (select(
      syncQuarantine,
    )..orderBy([(t) => OrderingTerm(expression: t.firstSeen)])).get();
  }

  Stream<List<SyncQuarantineData>> watchQuarantine() {
    return (select(
      syncQuarantine,
    )..orderBy([(t) => OrderingTerm(expression: t.firstSeen)])).watch();
  }

  Future<SyncQuarantineData?> getQuarantined(String filename) {
    return (select(
      syncQuarantine,
    )..where((t) => t.filename.equals(filename))).getSingleOrNull();
  }

  Future<void> putQuarantine(SyncQuarantineCompanion entry) {
    return into(syncQuarantine).insertOnConflictUpdate(entry);
  }

  Future<void> deleteQuarantine(String filename) {
    return (delete(
      syncQuarantine,
    )..where((t) => t.filename.equals(filename))).go();
  }

  Future<void> clearQuarantine() => delete(syncQuarantine).go();

  // --- pending local changes ---

  /// Number of local changes not yet written to a change file.
  ///
  /// The sync triggers write `pending_sync_changes` behind drift's back, so
  /// the query also re-runs whenever any synced table changes.
  Stream<int> watchPendingCount() {
    final synced = AppDatabase.syncedTables.toSet();
    return customSelect(
      'SELECT COUNT(*) AS c FROM pending_sync_changes',
      readsFrom: {
        pendingSyncChanges,
        for (final t in attachedDatabase.allTables)
          if (synced.contains(t.actualTableName)) t,
      },
    ).map((row) => row.read<int>('c')).watchSingle();
  }

  Future<int> pendingCount() async {
    final count = pendingSyncChanges.id.count();
    final query = selectOnly(pendingSyncChanges)..addColumns([count]);
    return (await query.map((row) => row.read(count) ?? 0).getSingle());
  }
}
