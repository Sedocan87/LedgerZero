import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/analytics_data.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';

/// Service responsible for calculating financial analytics and reports.
class AnalyticsService {
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;

  AnalyticsService({
    required AccountRepository accountRepository,
    required TransactionRepository transactionRepository,
  })  : _accountRepository = accountRepository,
        _transactionRepository = transactionRepository;

  /// Calculates the current net worth and breakdown of assets vs liabilities.
  Future<AssetLiabilityBreakdown> calculateNetWorth() async {
    final accounts = await _accountRepository.getAllAccounts();

    double totalAssets = 0.0;
    double totalLiabilities = 0.0;

    for (final account in accounts) {
      // We categorize based on AccountType, regardless of the sign of the balance.
      // Typically, asset accounts hold positive value and liability accounts hold negative value.
      switch (account.type) {
        case AccountType.checking:
        case AccountType.savings:
        case AccountType.cash:
          totalAssets += account.currentBalance;
          break;
        case AccountType.credit:
          totalLiabilities += account.currentBalance;
          break;
      }
    }

    return AssetLiabilityBreakdown(
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: totalAssets + totalLiabilities,
    );
  }

  /// Calculates spending statistics for the given date range.
  ///
  /// [start] and [end] define the inclusive range.
  Future<SpendingStats> calculateSpendingStats(DateTime start, DateTime end) async {
    // Ensure accurate duration calculation including the last day
    // e.g. Jan 1 to Jan 1 is 1 day.
    // Difference between Jan 2 00:00 and Jan 1 00:00 is 1 day.
    final duration = end.difference(start);
    final days = duration.inDays + 1; // +1 to include the start day itself if end is same day

    if (days <= 0) {
      return const SpendingStats(
        averageDailySpending: 0,
        averageWeeklySpending: 0,
        averageMonthlySpending: 0,
        totalSpending: 0,
      );
    }

    // Get total expenses. Expenses are typically negative numbers.
    // We want the magnitude of spending, so we might want to flip the sign or return negative.
    // Usually "Spending" implies a positive magnitude of outflow.
    // getExpenseSumsByDateRange returns a Map<CategoryId, Sum>.
    final expenseMap = await _transactionRepository.getExpenseSumsByDateRange(start, end);

    // Sum all category expenses.
    // Assuming database returns negative values for expenses.
    double totalExpense = 0.0;
    for (final amount in expenseMap.values) {
      totalExpense += amount;
    }

    // If totalExpense is -500, spending is 500.
    // We will treat "Spending" as a positive magnitude for statistics.
    final totalSpending = totalExpense.abs();

    return SpendingStats(
      averageDailySpending: totalSpending / days,
      averageWeeklySpending: totalSpending / (days / 7.0),
      averageMonthlySpending: totalSpending / (days / 30.0), // Approximation
      totalSpending: totalSpending,
    );
  }

  /// Generates a comparison between the specified [year] and the previous year.
  Future<YearlyComparisonData> getYearOverYearComparison(int year) async {
    final currentYearSummary = await _calculateYearlySummary(year);
    final previousYearSummary = await _calculateYearlySummary(year - 1);

    return YearlyComparisonData(
      currentYear: currentYearSummary,
      previousYear: previousYearSummary,
    );
  }

  Future<YearlySummary> _calculateYearlySummary(int year) async {
    final start = DateTime(year, 1, 1);
    // End of year: Dec 31 23:59:59...
    // But repos usually take start/end.
    final end = DateTime(year, 12, 31, 23, 59, 59);

    final income = await _transactionRepository.getIncomeSumByDateRange(start, end);
    final expenseMap = await _transactionRepository.getExpenseSumsByDateRange(start, end);

    double totalExpense = 0.0;
    for (final amount in expenseMap.values) {
      totalExpense += amount;
    }

    // Net Savings = Income + Expenses (since expenses are negative)
    final netSavings = income + totalExpense;

    return YearlySummary(
      year: year,
      income: income,
      expense: totalExpense, // Keeping original sign (negative)
      netSavings: netSavings,
    );
  }
}
