import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/budget.dart';

/// Service responsible for core budgeting calculations.
class BudgetingService {
  final TransactionRepository _transactionRepository;
  final BudgetRepository _budgetRepository;

  BudgetingService({
    required TransactionRepository transactionRepository,
    required BudgetRepository budgetRepository,
  }) : _transactionRepository = transactionRepository,
       _budgetRepository = budgetRepository;

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
}
