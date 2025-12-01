import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';

enum AutoAssignRule {
  underfunded,
  averageSpent,
  lastMonthSpent,
  lastMonthBudgeted,
}

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

    final totalIncome = await _transactionRepository.getIncomeSumByDateRange(
      startOfTime,
      nextMonthStart.subtract(const Duration(milliseconds: 1)),
    );

    // 3. Calculate Total Budgeted
    final targetMonthString = DateFormat('yyyy-MM').format(targetMonth);
    final totalBudgeted = await _budgetRepository.getTotalBudgetedByMonthRange(targetMonthString);

    return totalIncome - totalBudgeted;
  }

  /// Calculates total income for a specific [month].
  ///
  /// Income is defined as transactions with a positive amount and a null categoryId.
  Future<double> calculateTotalIncomeForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));

    return await _transactionRepository.getIncomeSumByDateRange(
      startOfMonth,
      endOfMonth,
    );
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

    return await _transactionRepository.getExpenseSumByCategoryAndDateRange(
      categoryId,
      startOfMonth,
      endOfMonth,
    );
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
    final totalActivity = await _transactionRepository.getExpenseSumByCategoryAndDateRange(
      categoryId,
      startOfTime,
      endOfTargetMonth,
    );

    // 3. Fetch all budgets
    final targetMonthString = DateFormat('yyyy-MM').format(month);
    final totalBudgeted = await _budgetRepository.getTotalBudgetedByCategoryAndMonthRange(
      categoryId,
      targetMonthString,
    );

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

  /// Creates a snapshot of the budget for a specific [month].
  ///
  /// Calculates `activity` and `available` for all categories for the given month
  /// and updates the Budget records in the database.
  /// This freezes the calculated values into the database for that month.
  Future<void> createBudgetSnapshot(DateTime month) async {
    final monthString = DateFormat('yyyy-MM').format(month);
    final allCategories = await _categoryRepository.getAllCategories();

    await Future.wait(allCategories.map((category) async {
      final activity = await calculateCategoryActivity(category.id, month);
      final available = await calculateCategoryAvailable(category.id, month);

      final existingBudget =
          await _budgetRepository.getBudgetByCategoryAndMonth(category.id, monthString);

      if (existingBudget != null) {
        final updatedBudget = existingBudget.copyWith(
          activity: activity,
          available: available,
          updatedAt: DateTime.now(),
        );
        await _budgetRepository.updateBudget(updatedBudget);
      } else {
        // If budget doesn't exist, we create it.
        // Assuming budgeted is 0 if it didn't exist.
        final newBudget = Budget(
          id: const Uuid().v4(),
          categoryId: category.id,
          month: monthString,
          budgeted: 0.0,
          activity: activity,
          available: available,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _budgetRepository.createBudget(newBudget);
      }
    }));
  }

  /// Calculates the target amount to budget for a category for the given month based on its goal.
  Future<double> calculateGoalTarget(Category category, DateTime month) async {
    if (category.goalType == null || category.targetAmount == null) {
      return 0.0;
    }

    final targetAmount = category.targetAmount!;
    final prevMonth = DateTime(month.year, month.month - 1, 1);

    switch (category.goalType!) {
      case GoalType.monthlyFunding:
        return targetAmount;

      case GoalType.targetBalance:
        final priorAvailable = await calculateCategoryAvailable(category.id, prevMonth);
        final needed = targetAmount - priorAvailable;
        return needed > 0 ? needed : 0.0;

      case GoalType.targetBalanceByDate:
        if (category.targetDate == null) {
          return 0.0;
        }

        // Calculate months remaining, inclusive of current month and target month
        final monthsDiff = _monthsDifference(month, category.targetDate!);
        // If target date is in the past or this month, monthsDiff <= 0.
        // We want to treat "this month" as 1 month remaining.
        int monthsRemaining = monthsDiff + 1;

        if (monthsRemaining <= 0) {
          monthsRemaining = 1;
        }

        final priorAvailable = await calculateCategoryAvailable(category.id, prevMonth);
        final needed = targetAmount - priorAvailable;

        if (needed <= 0) {
          return 0.0;
        }

        return needed / monthsRemaining;
    }
  }

  /// Calculates the funded percentage for a category's goal in a specific month.
  /// Returns a value between 0.0 and 1.0 (or higher if overfunded).
  Future<double> calculateFundedPercentage(Category category, DateTime month) async {
    if (category.goalType == null || category.targetAmount == null || category.targetAmount == 0) {
      return 0.0;
    }

    final target = await calculateGoalTarget(category, month);
    if (target == 0.0) {
      return 1.0; // Goal met or no target needed
    }

    final monthString = DateFormat('yyyy-MM').format(month);
    final budget = await _budgetRepository.getBudgetByCategoryAndMonth(category.id, monthString);
    final budgeted = budget?.budgeted ?? 0.0;

    return budgeted / target;
  }

  /// Calculates the average spending for a category over the last [months] count (excluding current month).
  Future<double> getAverageSpent(String categoryId, int months, DateTime referenceMonth) async {
    final currentMonthStart = DateTime(referenceMonth.year, referenceMonth.month, 1);
    final endDate = currentMonthStart.subtract(const Duration(milliseconds: 1));
    final startDate = DateTime(referenceMonth.year, referenceMonth.month - months, 1);

    final transactions = await _transactionRepository.getTransactionsByDateRange(startDate, endDate);

    final totalSpent = transactions
        .where((t) => t.categoryId == categoryId)
        .fold<double>(0.0, (double sum, Transaction t) => sum + t.amount);

    return (totalSpent / months).abs();
  }

  /// Gets the spending in the previous month.
  Future<double> getLastMonthSpent(String categoryId, DateTime currentMonth) async {
    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    final activity = await calculateCategoryActivity(categoryId, prevMonth);
    return activity.abs();
  }

  /// Gets the budgeted amount in the previous month.
  Future<double> getLastMonthBudgeted(String categoryId, DateTime currentMonth) async {
    final prevMonthString = DateFormat('yyyy-MM').format(DateTime(currentMonth.year, currentMonth.month - 1, 1));
    final budget = await _budgetRepository.getBudgetByCategoryAndMonth(categoryId, prevMonthString);
    return budget?.budgeted ?? 0.0;
  }

  /// Automatically assigns budget to a category based on a rule.
  Future<void> autoAssign(String categoryId, DateTime month, AutoAssignRule rule) async {
    double amount = 0.0;

    switch (rule) {
      case AutoAssignRule.underfunded:
        final category = await _categoryRepository.getCategoryById(categoryId);
        if (category != null) {
          amount = await calculateGoalTarget(category, month);
        }
        break;
      case AutoAssignRule.averageSpent:
        amount = await getAverageSpent(categoryId, 3, month); // Default to 3 months average
        break;
      case AutoAssignRule.lastMonthSpent:
        amount = await getLastMonthSpent(categoryId, month);
        break;
      case AutoAssignRule.lastMonthBudgeted:
        amount = await getLastMonthBudgeted(categoryId, month);
        break;
    }

    await setCategoryBudgetedAmount(categoryId, amount, month);
  }

  int _monthsDifference(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + to.month - from.month;
  }
}
