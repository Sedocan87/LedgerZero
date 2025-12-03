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
    final isIncome = t.amount > 0 && t.categoryId == null;

    if (isIncome) {
      incomePoints[monthDate] = (incomePoints[monthDate] ?? 0) + t.amount;
    } else {
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

    // Only add one point per day
    final date = DateTime(t.date.year, t.date.month, t.date.day);
    if (lastDate != date) {
      points.add(TimeSeriesPoint(date, currentBalance));
      lastDate = date;
    } else {
      points.removeLast();
      points.add(TimeSeriesPoint(date, currentBalance));
    }
  }

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

/// Provider for Spending Trends (Monthly Spending Totals).
/// Returns a Map of Month Start Date -> Total Expense Amount.
final spendingTrendsProvider = FutureProvider<Map<DateTime, double>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);

  final transactions = await transactionRepo.getTransactionsByDateRange(range.start, range.end);
  final trends = <DateTime, double>{};

  DateTime toMonthStart(DateTime date) => DateTime(date.year, date.month, 1);

  for (var t in transactions) {
     if (t.isTransfer) {
       continue;
     }

     final isIncome = t.amount > 0 && t.categoryId == null;
     if (!isIncome) {
        final monthDate = toMonthStart(t.date);
        trends[monthDate] = (trends[monthDate] ?? 0) + t.amount;
     }
  }

  final result = <DateTime, double>{};
  for (var entry in trends.entries) {
     if (entry.value < 0) {
        result[entry.key] = entry.value.abs();
     } else {
        result[entry.key] = 0.0;
     }
  }
  return result;
});

/// Provider for Top Payees.
/// Returns list of (Payee Name, Amount).
final topPayeesProvider = FutureProvider<List<MapEntry<String, double>>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final payeeRepo = ref.watch(payeeRepositoryProvider);

  final transactions = await transactionRepo.getTransactionsByDateRange(range.start, range.end);
  final payees = await payeeRepo.getAllPayees();
  final payeeNameMap = {for (var p in payees) p.id: p.name};

  final payeeTotals = <String, double>{};

  for (var t in transactions) {
    if (t.isTransfer) {
      continue;
    }

    // Only count outflows (spending)
    if (t.amount < 0) {
      final payeeName = t.payeeId != null ? (payeeNameMap[t.payeeId!] ?? 'Unknown') : 'No Payee';
      payeeTotals[payeeName] = (payeeTotals[payeeName] ?? 0) + t.amount.abs();
    }
  }

  final sortedList = payeeTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sortedList.take(10).toList();
});
