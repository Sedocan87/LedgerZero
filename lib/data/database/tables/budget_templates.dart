import 'package:drift/drift.dart';

class BudgetTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get data => text()(); // JSON Map<String, double>
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
