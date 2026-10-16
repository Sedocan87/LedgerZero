import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/report_note.dart';
import 'package:ledger_zero/domain/extensions/transaction_extensions.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';

/// Budgeted vs. spent amounts (minor units) of one category.
class BudgetVsActualItem {
  final String categoryName;
  final int budgeted;
  final int actual;

  BudgetVsActualItem({
    required this.categoryName,
    required this.budgeted,
    required this.actual,
  });
}

/// Half-open UTC query bounds `[start, endExclusive)` for a report range
/// whose `start` and `end` are inclusive calendar days.
({DateTime start, DateTime endExclusive}) reportQueryBounds(
  DateTimeRange range,
) => (
  start: CalendarDate.fromLocalPick(range.start),
  endExclusive: CalendarDate.endOfDayUtc(range.end),
);

/// Provider for the selected date range in reports.
///
/// `start` and `end` are inclusive calendar days (UTC midnight).
/// Defaults to the current year.
final reportDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final year = CalendarDate.today().year;
  return DateTimeRange(
    start: DateTime.utc(year, 1, 1),
    end: DateTime.utc(year, 12, 31),
  );
});

/// Provider for the selected categories filter in reports.
/// If empty, all categories are included.
final reportCategoryFilterProvider = StateProvider<Set<String>>((ref) => {});

/// Provider for Spending by Category data.
/// Returns a Map of Category Name -> spent amount (positive minor units).
final spendingByCategoryProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) async {
    ref.watch(ledgerChangesProvider);
    final range = ref.watch(reportDateRangeProvider);
    final categoryFilter = ref.watch(reportCategoryFilterProvider);
    final transactionRepo = ref.watch(transactionRepositoryProvider);
    final categoryRepo = ref.watch(categoryRepositoryProvider);
    final l10n = ref.watch(appLocalizationsProvider);
    final bounds = reportQueryBounds(range);

    // Get expenses by category ID
    final expenseMap = await transactionRepo.getCategoryActivitySums(
      bounds.start,
      bounds.endExclusive,
    );

    // Get all categories to map IDs to Names
    final categories = await categoryRepo.getAllCategories();
    final categoryNameMap = {for (var c in categories) c.id: c.name};

    final result = <String, int>{};
    for (var entry in expenseMap.entries) {
      // Apply filter
      if (categoryFilter.isNotEmpty && !categoryFilter.contains(entry.key)) {
        continue;
      }

      final name = categoryNameMap[entry.key] ?? l10n.unknown;
      // Expense sums are sums of signed amounts (negative for outflow).
      // We take absolute value for the chart.
      final amount = entry.value.abs();

      if (amount > 0) {
        result[name] = (result[name] ?? 0) + amount;
      }
    }

    return result;
  },
);

/// Provider for Income vs Expense History.
/// Returns a list of ChartSeries (Income, Expense) with one point per month.
final incomeVsExpenseHistoryProvider =
    FutureProvider.autoDispose<List<ChartSeries>>((ref) async {
      ref.watch(ledgerChangesProvider);
      final range = ref.watch(reportDateRangeProvider);
      final transactionRepo = ref.watch(transactionRepositoryProvider);
      final l10n = ref.watch(appLocalizationsProvider);
      final bounds = reportQueryBounds(range);

      // A split counts through its children (categories), never twice.
      final transactions = await transactionRepo.getTransactionsByDateRange(
        bounds.start,
        bounds.endExclusive,
        excludeSplitParents: true,
      );

      // Group by month (minor units)
      final incomePoints = <DateTime, int>{};
      final expensePoints = <DateTime, int>{};

      for (var t in transactions) {
        if (t.isTransfer) {
          continue; // Skip transfers
        }

        final monthDate = CalendarDate.startOfMonthUtc(t.date);

        // Income: uncategorised inflows (they flow into To Be Budgeted).
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
        expenseSeriesPoints.add(
          TimeSeriesPoint(date, netExpense < 0 ? 0 : netExpense),
        );
      }

      return [
        ChartSeries(
          name: l10n.reportIncomeSeries,
          kind: ChartSeriesKind.income,
          points: incomeSeriesPoints,
        ),
        ChartSeries(
          name: l10n.reportExpenseSeries,
          kind: ChartSeriesKind.expense,
          points: expenseSeriesPoints,
        ),
      ];
    });

/// Net worth (sum of all account balances) over the range: one point at
/// the range start, then one at the end of every month (the last one at the
/// range end). Computed from one balance sum and one grouped-by-month SQL
/// query, so no transaction rows are loaded into memory.
final netWorthHistoryProvider = FutureProvider.autoDispose<List<ChartSeries>>((
  ref,
) async {
  ref.watch(ledgerChangesProvider);
  final range = ref.watch(reportDateRangeProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final l10n = ref.watch(appLocalizationsProvider);
  final bounds = reportQueryBounds(range);

  final accounts = await accountRepo.getAllAccounts();
  var balance = accounts.fold<int>(0, (sum, a) => sum + a.startingBalance);
  balance += await transactionRepo.getBalanceChangeSum(bounds.start);
  final monthly = await transactionRepo.getMonthlyBalanceChanges(
    bounds.start,
    bounds.endExclusive,
  );

  final rangeEnd = CalendarDate.normalize(range.end);
  final points = <TimeSeriesPoint>[TimeSeriesPoint(bounds.start, balance)];
  var month = CalendarDate.startOfMonthUtc(bounds.start);
  while (!month.isAfter(rangeEnd)) {
    balance += monthly[CalendarDate.monthKey(month)] ?? 0;
    final lastDay = CalendarDate.endOfMonthUtc(
      month,
    ).subtract(const Duration(days: 1));
    points.add(
      TimeSeriesPoint(lastDay.isAfter(rangeEnd) ? rangeEnd : lastDay, balance),
    );
    month = CalendarDate.endOfMonthUtc(month);
  }

  return [
    ChartSeries(
      name: l10n.netWorth,
      kind: ChartSeriesKind.netWorth,
      points: points,
    ),
  ];
});

/// Provider for Spending Trends (Monthly Spending Totals).
/// Returns a Map of month start (UTC) -> total spent (positive minor units).
final spendingTrendsProvider = FutureProvider.autoDispose<Map<DateTime, int>>((
  ref,
) async {
  ref.watch(ledgerChangesProvider);
  final range = ref.watch(reportDateRangeProvider);
  final categoryFilter = ref.watch(reportCategoryFilterProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final bounds = reportQueryBounds(range);

  // A split counts through its children (categories), never twice.
  final transactions = await transactionRepo.getTransactionsByDateRange(
    bounds.start,
    bounds.endExclusive,
    excludeSplitParents: true,
  );
  final trends = <DateTime, int>{};

  for (var t in transactions) {
    if (t.isTransfer) {
      continue;
    }

    if (categoryFilter.isNotEmpty &&
        (t.categoryId == null || !categoryFilter.contains(t.categoryId))) {
      continue;
    }

    final isIncome = t.amount > 0 && t.categoryId == null;
    if (!isIncome) {
      final monthDate = CalendarDate.startOfMonthUtc(t.date);
      trends[monthDate] = (trends[monthDate] ?? 0) + t.amount;
    }
  }

  return {
    for (final entry in trends.entries)
      entry.key: entry.value < 0 ? -entry.value : 0,
  };
});

/// Provider for Budget vs Actual data.
final budgetVsActualProvider =
    FutureProvider.autoDispose<List<BudgetVsActualItem>>((ref) async {
      ref.watch(ledgerChangesProvider);
      final range = ref.watch(reportDateRangeProvider);
      final categoryFilter = ref.watch(reportCategoryFilterProvider);
      final budgetRepo = ref.watch(budgetRepositoryProvider);
      final transactionRepo = ref.watch(transactionRepositoryProvider);
      final categoryRepo = ref.watch(categoryRepositoryProvider);
      final l10n = ref.watch(appLocalizationsProvider);
      final bounds = reportQueryBounds(range);

      // Since budgets are stored monthly, we iterate through months in the range
      final endMonth = CalendarDate.startOfMonthUtc(range.end);

      final budgetedMap = <String, int>{}; // CategoryId -> Total Budgeted

      var current = CalendarDate.startOfMonthUtc(range.start);
      while (!current.isAfter(endMonth)) {
        final budgets = await budgetRepo.getBudgetsForMonth(
          CalendarDate.monthKey(current),
        );

        for (var b in budgets) {
          if (b.categoryId != null) {
            budgetedMap[b.categoryId!] =
                (budgetedMap[b.categoryId!] ?? 0) + b.budgeted;
          }
        }

        current = CalendarDate.endOfMonthUtc(current);
      }

      // Actual spending (Expenses)
      final expenseMap = await transactionRepo.getCategoryActivitySums(
        bounds.start,
        bounds.endExclusive,
      );

      final categories = await categoryRepo.getAllCategories();
      final categoryNameMap = {for (var c in categories) c.id: c.name};

      final allCategoryIds = {...budgetedMap.keys, ...expenseMap.keys};
      final items = <BudgetVsActualItem>[];

      for (var catId in allCategoryIds) {
        if (categoryFilter.isNotEmpty && !categoryFilter.contains(catId)) {
          continue;
        }

        final budgeted = budgetedMap[catId] ?? 0;
        final actual = (expenseMap[catId] ?? 0).abs(); // Spending is negative

        if (budgeted > 0 || actual > 0) {
          items.add(
            BudgetVsActualItem(
              categoryName: categoryNameMap[catId] ?? l10n.unknown,
              budgeted: budgeted,
              actual: actual,
            ),
          );
        }
      }

      // Sort by highest budgeted
      items.sort((a, b) => b.budgeted.compareTo(a.budgeted));

      return items;
    });

/// Provider for Report Notes in the selected range.
final reportNotesListProvider = FutureProvider.autoDispose<List<ReportNote>>((
  ref,
) async {
  final range = ref.watch(reportDateRangeProvider);
  final noteRepo = ref.watch(reportNoteRepositoryProvider);

  final allNotes = await noteRepo
      .getAllNotes(); // Optimized query would be better but get all is fine for now

  final startKey = CalendarDate.monthKey(range.start);
  final endKey = CalendarDate.monthKey(range.end);

  // Filter notes by month key yyyy-MM (keys compare lexicographically)
  return allNotes.where((note) {
    try {
      final key = CalendarDate.monthKey(CalendarDate.parseMonthKey(note.date));
      return key.compareTo(startKey) >= 0 && key.compareTo(endKey) <= 0;
    } catch (_) {
      return false;
    }
  }).toList();
});

/// Provider for Top Payees.
/// Returns list of (Payee Name, spent amount in positive minor units).
final topPayeesProvider =
    FutureProvider.autoDispose<List<MapEntry<String, int>>>((ref) async {
      ref.watch(ledgerChangesProvider);
      final range = ref.watch(reportDateRangeProvider);
      final transactionRepo = ref.watch(transactionRepositoryProvider);
      final payeeRepo = ref.watch(payeeRepositoryProvider);
      final l10n = ref.watch(appLocalizationsProvider);
      final bounds = reportQueryBounds(range);

      // A split counts through its children (categories), never twice.
      final transactions = await transactionRepo.getTransactionsByDateRange(
        bounds.start,
        bounds.endExclusive,
        excludeSplitParents: true,
      );
      final payees = await payeeRepo.getAllPayees();
      final payeeNameMap = {for (var p in payees) p.id: p.name};

      final payeeTotals = <String, int>{};

      for (var t in transactions) {
        if (t.isTransfer) {
          continue;
        }

        // Only count outflows (spending)
        if (t.amount < 0) {
          final payeeName = t.payeeId != null
              ? (payeeNameMap[t.payeeId!] ?? l10n.unknown)
              : l10n.transactionNoPayee;
          payeeTotals[payeeName] =
              (payeeTotals[payeeName] ?? 0) + t.amount.abs();
        }
      }

      final sortedList = payeeTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedList.take(10).toList();
    });
