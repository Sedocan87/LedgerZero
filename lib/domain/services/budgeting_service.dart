import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/budget.dart';

/// Service responsible for core budgeting calculations.
class BudgetingService {
  final TransactionRepository _transactionRepository;
  final BudgetRepository _budgetRepository;
  final CategoryRepository _categoryRepository;

  BudgetingService({
    required TransactionRepository transactionRepository,
    required BudgetRepository budgetRepository,
    required CategoryRepository categoryRepository,
  }) : _transactionRepository = transactionRepository,
       _budgetRepository = budgetRepository,
       _categoryRepository = categoryRepository;

  /// Calculates the "To Be Budgeted" (TBB) amount up to the end of the specified [targetMonth].
  ///
  /// TBB = Total Income (positive transactions, null category)
  ///       - Total Budgeted (sum of all budget allocations)
  ///       (both up to the end of the target month)
  Future<double> calculateTBB(DateTime targetMonth) async {
    // 1. Calculate end of the target month for transaction filtering
    // We want all transactions strictly before the start of the next month
    final nextMonthStart = DateTime(targetMonth.year, targetMonth.month + 1, 1);

    // 2. Fetch all transactions up to the end of the target month
    // We start from a very old date (Unix epoch) to capture all history
    final startOfTime = DateTime.fromMillisecondsSinceEpoch(0);
    final transactions = await _transactionRepository.getTransactionsByDateRange(
      startOfTime,
      nextMonthStart.subtract(const Duration(milliseconds: 1)),
    );

    // 3. Calculate Total Income
    // Income is defined as transactions with a positive amount and a null categoryId.
    final totalIncome = transactions
        .where((t) => t.amount > 0 && t.categoryId == null)
        .fold<double>(0.0, (double sum, Transaction t) => sum + t.amount);

    // 4. Fetch all budgets
    final allBudgets = await _budgetRepository.getAllBudgets();

    // 5. Calculate Total Budgeted
    // Filter budgets where month <= targetMonth (formatted as YYYY-MM)
    final targetMonthString = DateFormat('yyyy-MM').format(targetMonth);

    final totalBudgeted = allBudgets
        .where((b) => b.month.compareTo(targetMonthString) <= 0)
        .fold<double>(0.0, (double sum, Budget b) => sum + b.budgeted);

    return totalIncome - totalBudgeted;
  }

  /// Calculates total income for a specific [month].
  ///
  /// Income is defined as transactions with a positive amount and a null categoryId.
  Future<double> calculateTotalIncomeForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));

    final transactions = await _transactionRepository.getTransactionsByDateRange(
      startOfMonth,
      endOfMonth,
    );

    return transactions
        .where((t) => t.amount > 0 && t.categoryId == null)
        .fold<double>(0.0, (double sum, Transaction t) => sum + t.amount);
  }

  /// Calculates total budgeted amount for a specific [month].
  Future<double> calculateTotalBudgetedForMonth(DateTime month) async {
    final monthString = DateFormat('yyyy-MM').format(month);
    final budgets = await _budgetRepository.getBudgetsForMonth(monthString);

    return budgets.fold<double>(0.0, (double sum, Budget b) => sum + b.budgeted);
  }

  /// Calculates the activity (spending) for a specific [categoryId] in a specific [month].
  ///
  /// Activity is the sum of all transactions for this category in the month.
  /// Usually negative for outflows/spending.
  Future<double> calculateCategoryActivity(String categoryId, DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));

    final transactions = await _transactionRepository.getTransactionsByDateRange(
      startOfMonth,
      endOfMonth,
    );

    return transactions
        .where((t) => t.categoryId == categoryId)
        .fold<double>(0.0, (double sum, Transaction t) => sum + t.amount);
  }

  /// Calculates the available amount for a specific [categoryId] up to the end of [month].
  ///
  /// Available = Total Budgeted (all time up to month) + Total Activity (all time up to month).
  /// This automatically handles positive carry-over and negative rollover (overspending).
  Future<double> calculateCategoryAvailable(String categoryId, DateTime month) async {
    // 1. Calculate end of the target month
    final nextMonthStart = DateTime(month.year, month.month + 1, 1);
    final endOfTargetMonth = nextMonthStart.subtract(const Duration(milliseconds: 1));
    final startOfTime = DateTime.fromMillisecondsSinceEpoch(0);

    // 2. Fetch all transactions for this category up to end of target month
    // Note: Optimization would be to have getTransactionsByCategoryAndDateRange in repository
    final allTransactions = await _transactionRepository.getTransactionsByDateRange(
      startOfTime,
      endOfTargetMonth,
    );

    final totalActivity = allTransactions
        .where((t) => t.categoryId == categoryId)
        .fold<double>(0.0, (double sum, Transaction t) => sum + t.amount);

    // 3. Fetch all budgets
    // Note: Optimization would be to have getBudgetsByCategory in repository
    final allBudgets = await _budgetRepository.getAllBudgets();
    final targetMonthString = DateFormat('yyyy-MM').format(month);

    final totalBudgeted = allBudgets
        .where((b) => b.categoryId == categoryId && b.month.compareTo(targetMonthString) <= 0)
        .fold<double>(0.0, (double sum, Budget b) => sum + b.budgeted);

    return totalBudgeted + totalActivity;
  }

  /// Assigns a budgeted amount to a specific category for a specific month.
  ///
  /// If a budget already exists, updates it. Otherwise, creates a new one.
  Future<void> setCategoryBudgetedAmount(String categoryId, double amount, DateTime month) async {
    final monthString = DateFormat('yyyy-MM').format(month);
    final existingBudget = await _budgetRepository.getBudgetByCategoryAndMonth(categoryId, monthString);

    if (existingBudget != null) {
      final updatedBudget = existingBudget.copyWith(
        budgeted: amount,
        updatedAt: DateTime.now(),
      );
      await _budgetRepository.updateBudget(updatedBudget);
    } else {
      final newBudget = Budget(
        id: const Uuid().v4(),
        categoryId: categoryId,
        month: monthString,
        budgeted: amount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _budgetRepository.createBudget(newBudget);
    }
  }

  /// Moves money from one category to another in a specific month.
  ///
  /// Reduces the budgeted amount in [fromCategoryId] and increases it in [toCategoryId].
  Future<void> moveMoney(String fromCategoryId, String toCategoryId, double amount, DateTime month) async {
    final monthString = DateFormat('yyyy-MM').format(month);

    // Get source budget
    var fromBudget = await _budgetRepository.getBudgetByCategoryAndMonth(fromCategoryId, monthString);
    if (fromBudget == null) {
      // Create if doesn't exist (assuming 0 budgeted initially)
      fromBudget = Budget(
        id: const Uuid().v4(),
        categoryId: fromCategoryId,
        month: monthString,
        budgeted: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _budgetRepository.createBudget(fromBudget);
    }

    // Get destination budget
    var toBudget = await _budgetRepository.getBudgetByCategoryAndMonth(toCategoryId, monthString);
    if (toBudget == null) {
      toBudget = Budget(
        id: const Uuid().v4(),
        categoryId: toCategoryId,
        month: monthString,
        budgeted: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _budgetRepository.createBudget(toBudget);
    }

    // Update amounts
    final updatedFromBudget = fromBudget.copyWith(
      budgeted: fromBudget.budgeted - amount,
      updatedAt: DateTime.now(),
    );
    final updatedToBudget = toBudget.copyWith(
      budgeted: toBudget.budgeted + amount,
      updatedAt: DateTime.now(),
    );

    // Save changes
    await _budgetRepository.updateBudget(updatedFromBudget);
    await _budgetRepository.updateBudget(updatedToBudget);
  }

  /// Initializes budget entries for a new month for all active categories.
  ///
  /// Ensures that a Budget entity exists for every category for the given month.
  Future<void> initializeMonthBudgets(DateTime month) async {
    final monthString = DateFormat('yyyy-MM').format(month);
    final allCategories = await _categoryRepository.getAllCategories();

    for (final category in allCategories) {
      // Check if budget already exists
      final existingBudget = await _budgetRepository.getBudgetByCategoryAndMonth(category.id, monthString);
      if (existingBudget == null) {
        final newBudget = Budget(
          id: const Uuid().v4(),
          categoryId: category.id,
          month: monthString,
          budgeted: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _budgetRepository.createBudget(newBudget);
      }
    }
  }
}
