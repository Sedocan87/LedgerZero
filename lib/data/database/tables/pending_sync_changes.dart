import 'package:drift/drift.dart';

/// Local changes to synced tables, written by the sync triggers
/// (`AppDatabase._createSyncTriggersForTable`). The sync engine turns them
/// into an encrypted change file and deletes them.
@TableIndex(
  name: 'idx_pending_sync_record',
  columns: {#targetTableName, #recordId},
)
class PendingSyncChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Renamed to avoid conflict with Table.tableName
  TextColumn get targetTableName => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get action => text()(); // INSERT, UPDATE, DELETE
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();

  /// DELETE only: the deleted row's `updated_at` (raw), so the tombstone's
  /// timestamp is never older than the last edit it deletes (schema v17).
  TextColumn get oldUpdatedAt => text().nullable()();
}
