import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';

@TableIndex(name: 'idx_budgets_month', columns: {#month})
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get month => text()(); // Format: YYYY-MM
  /// Amount assigned to the category for the month, in minor units.
  /// Activity and available are always computed from transactions.
  IntColumn get budgeted => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, month},
  ];
}
