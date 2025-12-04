import 'package:drift/drift.dart';

class PendingSyncChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Renamed to avoid conflict with Table.tableName
  TextColumn get targetTableName => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get action => text()(); // INSERT, UPDATE, DELETE
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();
}
