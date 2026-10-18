import 'package:ledger_zero/domain/entities/budget.dart';

/// Repository interface for managing [Budget] entities.
abstract class BudgetRepository {
  /// Retrieves all budgets.
  Future<List<Budget>> getAllBudgets();

  /// Retrieves a budget by its unique identifier.
  Future<Budget?> getBudgetById(String id);

  /// Retrieves a budget for a specific category and month.
  Future<Budget?> getBudgetByCategoryAndMonth(String categoryId, String month);

  /// Retrieves all budgets for a specific month.
  Future<List<Budget>> getBudgetsForMonth(String month);

  /// Creates a new budget.
  Future<void> createBudget(Budget budget);

  /// Updates an existing budget.
  Future<void> updateBudget(Budget budget);

  /// Deletes a budget by its unique identifier.
  Future<void> deleteBudget(String id);

  /// Watches all budgets for a specific month.
  Stream<List<Budget>> watchBudgetsForMonth(String month);

  /// Calculates total budgeted amount (minor units) across all categories up to (and including) [endMonth].
  Future<int> getTotalBudgetedByMonthRange(String endMonth);

  /// Calculates total budgeted amount (minor units) for a specific category up to (and including) [endMonth].
  Future<int> getTotalBudgetedByCategoryAndMonthRange(
    String categoryId,
    String endMonth,
  );

  /// Calculates total budgeted amount (minor units) for all categories up to (and including) [endMonth].
  /// Returns a map where key is categoryId and value is the sum.
  Future<Map<String, int>> getAllTimeBudgetedSumsUpToMonth(String endMonth);

  /// Every budget row with `month <= endMonth` (optionally of one
  /// category), for the month-by-month rollover.
  Future<List<Budget>> getBudgetsUpToMonth(
    String endMonth, {
    String? categoryId,
  });

  /// Total budgeted (minor units) in all months after [endMonth].
  Future<int> getTotalBudgetedAfterMonth(String endMonth);

  /// Category activity per month: `yyyy-MM` -> (categoryId -> signed sum,
  /// minor units) of the categorised activity rows (on-budget accounts,
  /// split lines included) dated before [endExclusive], optionally of one
  /// category. Months without activity are absent.
  Future<Map<String, Map<String, int>>> getMonthlyCategoryActivity(
    DateTime endExclusive, {
    String? categoryId,
  });

  /// accountId -> date of the account's earliest non-deleted transaction.
  Future<Map<String, DateTime>> getFirstTransactionDates();
}
