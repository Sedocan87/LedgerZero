import 'package:drift/drift.dart';

@TableIndex(name: 'idx_sync_log_applied', columns: {#appliedAt})
class SyncLog extends Table {
  TextColumn get id => text()();
  TextColumn get deltaFilename => text().unique().nullable()();
  TextColumn get action => text().nullable()(); // INSERT, UPDATE, DELETE

  // Renamed getter to avoid conflict with Table.tableName
  TextColumn get targetTableName => text().named('table_name').nullable()();

  TextColumn get recordId => text().nullable()();
  DateTimeColumn get appliedAt => dateTime().nullable()();
  TextColumn get deviceUuid => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
