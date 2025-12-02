import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/extensions/transaction_extensions.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
import 'package:ledger_zero/app/theme.dart';

/// Provider for the selected date range in reports.
/// Defaults to the current year.
final reportDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, 1, 1);
  final end = DateTime(now.year, 12, 31, 23, 59, 59);
  return DateTimeRange(start: start, end: end);
});

/// Provider for Spending by Category data.
/// Returns a Map of Category Name -> Amount.
final spendingByCategoryProvider = FutureProvider<Map<String, double>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);

  // Get expenses by category ID
  final expenseMap = await transactionRepo.getExpenseSumsByDateRange(range.start, range.end);

  // Get all categories to map IDs to Names
  final categories = await categoryRepo.getAllCategories();
  final categoryNameMap = {for (var c in categories) c.id: c.name};

  final result = <String, double>{};
  for (var entry in expenseMap.entries) {
    final name = categoryNameMap[entry.key] ?? 'Unknown';
    // Expense sums are sums of signed amounts (negative for outflow).
    // We take absolute value for the chart.
    final amount = entry.value.abs();

    if (amount > 0) {
       result[name] = (result[name] ?? 0) + amount;
    }
  }

  return result;
});

/// Provider for Income vs Expense History.
/// Returns a list of ChartSeries (Income, Expense).
final incomeVsExpenseHistoryProvider = FutureProvider<List<ChartSeries>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);

  final transactions = await transactionRepo.getTransactionsByDateRange(range.start, range.end);

  // Group by Month
  final incomePoints = <DateTime, double>{};
  final expensePoints = <DateTime, double>{};

  // Helper to normalize date to month start
  DateTime toMonthStart(DateTime date) => DateTime(date.year, date.month, 1);

  for (var t in transactions) {
    if (t.isTransfer) {
      continue; // Skip transfers
    }

    final monthDate = toMonthStart(t.date);

    // Income is defined as positive amount with no category (To Be Budgeted)
    // per project memory.
    final isIncome = t.amount > 0 && t.categoryId == null;

    if (isIncome) {
      incomePoints[monthDate] = (incomePoints[monthDate] ?? 0) + t.amount;
    } else {
      // Everything else is treated as Expense (or refund reducing expense)
      // We sum the signed amounts. Expenses are negative, refunds are positive.
      // Net result for the month: -200 (expense) + 50 (refund) = -150.
      // We want to plot 150. So we subtract the signed amount (or add absolute of negative).
      // Ideally: sum += t.amount. Then plot sum.abs().
      // But we can just accumulate t.amount and flip sign at the end.
      expensePoints[monthDate] = (expensePoints[monthDate] ?? 0) + t.amount;
    }
  }

  // Convert to sorted lists
  final sortedDates = {...incomePoints.keys, ...expensePoints.keys}.toList()
    ..sort();

  final incomeSeriesPoints = <TimeSeriesPoint>[];
  final expenseSeriesPoints = <TimeSeriesPoint>[];

  for (var date in sortedDates) {
    incomeSeriesPoints.add(TimeSeriesPoint(date, incomePoints[date] ?? 0));
    // Flip sign for expense points (Negative sum becomes Positive value)
    // If net positive (more refunds than expenses), show as 0 or negative expense?
    // Showing 0 is safer for "Expense" chart.
    final netExpense = -(expensePoints[date] ?? 0);
    expenseSeriesPoints.add(TimeSeriesPoint(date, netExpense < 0 ? 0 : netExpense));
  }

  return [
    ChartSeries(
      name: 'Income',
      color: AppColors.primaryLight,
      points: incomeSeriesPoints,
    ),
    ChartSeries(
      name: 'Expenses',
      color: AppColors.errorLight,
      points: expenseSeriesPoints,
    ),
  ];
});

/// Provider for Net Worth History.
final netWorthHistoryProvider = FutureProvider<List<ChartSeries>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);

  final accounts = await accountRepo.getAllAccounts();
  // Fetch all transactions to calculate running balance correctly from start
  final allTransactions = await transactionRepo.getAllTransactions();

  // Sort transactions by date
  allTransactions.sort((a, b) => a.date.compareTo(b.date));

  // Calculate total starting balance
  double currentBalance = accounts.fold(0.0, (sum, a) => sum + a.startingBalance);

  final points = <TimeSeriesPoint>[];

  // Apply transactions before range start
  final transactionsBefore = allTransactions.where((t) => t.date.isBefore(range.start));
  for (var t in transactionsBefore) {
    currentBalance += t.amount;
  }

  // Initial point at start of range
  points.add(TimeSeriesPoint(range.start, currentBalance));

  final transactionsInRange = allTransactions.where((t) =>
    !t.date.isBefore(range.start) && !t.date.isAfter(range.end)
  ).toList();

  DateTime? lastDate;

  for (var t in transactionsInRange) {
    currentBalance += t.amount;

    // Only add one point per day (last balance of the day)
    final date = DateTime(t.date.year, t.date.month, t.date.day);
    if (lastDate != date) {
      points.add(TimeSeriesPoint(date, currentBalance));
      lastDate = date;
    } else {
      // Update last point value
      points.removeLast();
      points.add(TimeSeriesPoint(date, currentBalance));
    }
  }

  // Ensure we have a point at the end if no transactions recently
  if (points.isNotEmpty && points.last.date.isBefore(range.end)) {
    points.add(TimeSeriesPoint(range.end, currentBalance));
  } else if (points.isEmpty) {
     points.add(TimeSeriesPoint(range.end, currentBalance));
  }

  return [
    ChartSeries(
      name: 'Net Worth',
      color: AppColors.tertiaryLight,
      points: points,
    ),
  ];
});
