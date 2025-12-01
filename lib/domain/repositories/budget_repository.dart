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

  /// Calculates total budgeted amount across all categories up to (and including) [endMonth].
  Future<double> getTotalBudgetedByMonthRange(String endMonth);

  /// Calculates total budgeted amount for a specific category up to (and including) [endMonth].
  Future<double> getTotalBudgetedByCategoryAndMonthRange(String categoryId, String endMonth);
}
