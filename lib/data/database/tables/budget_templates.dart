import 'package:drift/drift.dart';

class BudgetTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// JSON object mapping categoryId -> budgeted amount in minor units
  /// (`int`). Rows written before schema v15 held major-unit doubles and are
  /// converted by the v15 migration.
  TextColumn get data => text()();
  TextColumn get createdAt => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
