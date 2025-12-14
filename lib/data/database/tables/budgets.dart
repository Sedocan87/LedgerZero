import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';

@TableIndex(name: 'idx_budgets_month', columns: {#month})
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get month => text()(); // Format: YYYY-MM
  RealColumn get budgeted => real().withDefault(const Constant(0.0))();
  RealColumn get activity => real().withDefault(const Constant(0.0))();
  RealColumn get available => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, month},
  ];
}
