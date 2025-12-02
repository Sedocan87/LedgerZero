import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/budgets.dart';

part 'budgets_dao.g.dart';

@DriftAccessor(tables: [Budgets])
class BudgetsDao extends DatabaseAccessor<AppDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(super.db);

  Future<List<Budget>> getAllBudgets() => select(budgets).get();

  Future<Budget?> getBudgetById(String id) =>
      (select(budgets)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertBudget(BudgetsCompanion budget) =>
      into(budgets).insert(budget);

  Future<bool> updateBudget(BudgetsCompanion budget) =>
      update(budgets).replace(budget);

  Future<int> deleteBudget(String id) =>
      (delete(budgets)..where((tbl) => tbl.id.equals(id))).go();

  Future<Budget?> getBudgetByCategoryAndMonth(String categoryId, String month) =>
      (select(budgets)
            ..where(
                (tbl) => tbl.categoryId.equals(categoryId) & tbl.month.equals(month)))
          .getSingleOrNull();

  Future<List<Budget>> getBudgetsForMonth(String month) =>
      (select(budgets)..where((tbl) => tbl.month.equals(month))).get();

  Stream<List<Budget>> watchBudgetsForMonth(String month) =>
      (select(budgets)..where((tbl) => tbl.month.equals(month))).watch();

  Future<double> getTotalBudgetedByMonthRange(String endMonth) {
    final budgeted = budgets.budgeted.sum();
    final query = selectOnly(budgets)
      ..where(budgets.month.isSmallerOrEqualValue(endMonth))
      ..addColumns([budgeted]);

    return query.map((row) => row.read(budgeted) ?? 0.0).getSingle();
  }

  Future<double> getTotalBudgetedByCategoryAndMonthRange(
      String categoryId, String endMonth) {
    final budgeted = budgets.budgeted.sum();
    final query = selectOnly(budgets)
      ..where(budgets.categoryId.equals(categoryId) &
          budgets.month.isSmallerOrEqualValue(endMonth))
      ..addColumns([budgeted]);

    return query.map((row) => row.read(budgeted) ?? 0.0).getSingle();
  }

  Future<Map<String, double>> getBudgetedSumsByMonthRange(String endMonth) async {
    final budgeted = budgets.budgeted.sum();
    final query = selectOnly(budgets)
      ..where(budgets.month.isSmallerOrEqualValue(endMonth))
      ..addColumns([budgets.categoryId, budgeted])
      ..groupBy([budgets.categoryId]);

    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(budgets.categoryId) != null)
          row.read(budgets.categoryId)!: row.read(budgeted) ?? 0.0
    };
  }
}
