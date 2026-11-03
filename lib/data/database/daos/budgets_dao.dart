import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
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

  Future<Budget?> getBudgetByCategoryAndMonth(
    String categoryId,
    String month,
  ) =>
      (select(budgets)..where(
            (tbl) =>
                tbl.categoryId.equals(categoryId) & tbl.month.equals(month),
          ))
          .getSingleOrNull();

  Future<List<Budget>> getBudgetsForMonth(String month) =>
      (select(budgets)..where((tbl) => tbl.month.equals(month))).get();

  Stream<List<Budget>> watchBudgetsForMonth(String month) =>
      (select(budgets)..where((tbl) => tbl.month.equals(month))).watch();

  Future<int> getTotalBudgetedByMonthRange(String endMonth) {
    final budgeted = budgets.budgeted.sum();
    final query = selectOnly(budgets)
      ..where(budgets.month.isSmallerOrEqualValue(endMonth))
      ..addColumns([budgeted]);

    return query.map((row) => row.read(budgeted) ?? 0).getSingle();
  }

  Future<int> getTotalBudgetedByCategoryAndMonthRange(
    String categoryId,
    String endMonth,
  ) {
    final budgeted = budgets.budgeted.sum();
    final query = selectOnly(budgets)
      ..where(
        budgets.categoryId.equals(categoryId) &
            budgets.month.isSmallerOrEqualValue(endMonth),
      )
      ..addColumns([budgeted]);

    return query.map((row) => row.read(budgeted) ?? 0).getSingle();
  }

  Future<Map<String, int>> getBudgetedSumsByMonthRange(String endMonth) async {
    final budgeted = budgets.budgeted.sum();
    final query = selectOnly(budgets)
      ..where(budgets.month.isSmallerOrEqualValue(endMonth))
      ..addColumns([budgets.categoryId, budgeted])
      ..groupBy([budgets.categoryId]);

    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(budgets.categoryId) != null)
          row.read(budgets.categoryId)!: row.read(budgeted) ?? 0,
    };
  }

  /// Every budget row with `month <= endMonth` (optionally of one
  /// category), for the month-by-month rollover.
  Future<List<Budget>> getBudgetsUpToMonth(
    String endMonth, {
    String? categoryId,
  }) {
    return (select(budgets)..where((tbl) {
          final inRange = tbl.month.isSmallerOrEqualValue(endMonth);
          return categoryId == null
              ? inRange
              : inRange & tbl.categoryId.equals(categoryId);
        }))
        .get();
  }

  /// Budgeted per month (`yyyy-MM` -> sum in minor units) of the months
  /// after [endMonth]. Months without budget rows are absent.
  Future<Map<String, int>> getBudgetedSumsByMonthAfter(String endMonth) async {
    final budgeted = budgets.budgeted.sum();
    final query = selectOnly(budgets)
      ..where(budgets.month.isBiggerThanValue(endMonth))
      ..addColumns([budgets.month, budgeted])
      ..groupBy([budgets.month]);
    return {
      for (final row in await query.get())
        if (row.read(budgets.month) != null)
          row.read(budgets.month)!: row.read(budgeted) ?? 0,
    };
  }

  // The queries below read the transactions table: they are the budget
  // side's view of category activity, money arriving in To Be Budgeted and
  // account history, grouped the way the rollover and To Be Budgeted need
  // it. Their row filters mirror [TransactionsDao.getCategoryActivitySums]
  // (activity rows), [TransactionsDao.getReadyToAssignSum] (ready-to-assign
  // rows) and the account balance rows; keep them in step.

  /// Category activity per calendar month: `yyyy-MM` -> (categoryId ->
  /// signed sum in minor units) of the categorised activity rows dated
  /// before [endExclusive], optionally of one category. Months without
  /// activity are absent.
  Future<Map<String, Map<String, int>>> getMonthlyCategoryActivitySums(
    DateTime endExclusive, {
    String? categoryId,
  }) async {
    final transactions = attachedDatabase.transactions;
    final month = transactions.date.strftime('%Y-%m');
    final amount = transactions.amount.sum();
    var where =
        transactions.date.isSmallerThanValue(endExclusive.toUtc()) &
        transactions.isDeleted.equals(false) &
        transactions.categoryId.isNotNull() &
        _inBudgetAccount &
        (transactions.transferAccountId.isNull() | _transferAcrossBudget);
    if (categoryId != null) {
      where = where & transactions.categoryId.equals(categoryId);
    }
    final query = selectOnly(transactions)
      ..where(where)
      ..addColumns([month, transactions.categoryId, amount])
      ..groupBy([month, transactions.categoryId]);
    final result = <String, Map<String, int>>{};
    for (final row in await query.get()) {
      final m = row.read(month);
      final c = row.read(transactions.categoryId);
      if (m == null || c == null) {
        continue;
      }
      result.putIfAbsent(m, () => {})[c] = row.read(amount) ?? 0;
    }
    return result;
  }

  /// Money arriving in To Be Budgeted per calendar month: `yyyy-MM` ->
  /// sum (minor units) of the positive ready-to-assign rows (non-deleted,
  /// uncategorised, on-budget account, not a split parent, transfer legs
  /// only when the other account is off-budget) with
  /// `start <= date < endExclusive`. Outflows are left out. Months without
  /// such rows are absent.
  Future<Map<String, int>> getMonthlyReadyToAssignInflows(
    DateTime start,
    DateTime endExclusive,
  ) async {
    final transactions = attachedDatabase.transactions;
    final month = transactions.date.strftime('%Y-%m');
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(
        transactions.date.isBiggerOrEqualValue(start.toUtc()) &
            transactions.date.isSmallerThanValue(endExclusive.toUtc()) &
            transactions.isDeleted.equals(false) &
            transactions.categoryId.isNull() &
            transactions.amount.isBiggerThanValue(0) &
            _inBudgetAccount &
            (transactions.transferAccountId.isNull() | _transferAcrossBudget) &
            _isNotSplitParent,
      )
      ..addColumns([month, amount])
      ..groupBy([month]);
    return {
      for (final row in await query.get())
        if (row.read(month) != null) row.read(month)!: row.read(amount) ?? 0,
    };
  }

  /// accountId -> date of the account's earliest non-deleted transaction
  /// (accounts without transactions are absent).
  Future<Map<String, DateTime>> getFirstTransactionDates() async {
    final transactions = attachedDatabase.transactions;
    final first = transactions.date.min();
    final query = selectOnly(transactions)
      ..where(transactions.isDeleted.equals(false))
      ..addColumns([transactions.accountId, first])
      ..groupBy([transactions.accountId]);
    return {
      for (final row in await query.get())
        if (row.read(transactions.accountId) != null && row.read(first) != null)
          row.read(transactions.accountId)!: row.read(first)!,
    };
  }

  /// The row of table `transactions` belongs to an on-budget account (same
  /// condition as in [TransactionsDao]).
  static const CustomExpression<bool> _inBudgetAccount = CustomExpression(
    'transactions.account_id IN '
    '(SELECT id FROM accounts WHERE on_budget = 1)',
  );

  /// The row of table `transactions` is not a split parent (same condition
  /// as in [TransactionsDao]).
  static const CustomExpression<bool> _isNotSplitParent = CustomExpression(
    'NOT ${TransactionsDao.splitParentCondition}',
  );

  /// The row is a transfer leg whose other account is off-budget.
  static const CustomExpression<bool> _transferAcrossBudget = CustomExpression(
    'transactions.transfer_account_id IN '
    '(SELECT id FROM accounts WHERE on_budget = 0)',
  );
}
