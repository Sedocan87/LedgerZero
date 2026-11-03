import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/report_note.dart';
import 'package:ledger_zero/domain/entities/spending.dart';
import 'package:ledger_zero/domain/extensions/transaction_extensions.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
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

/// The budget currency (Settings). Amounts in different currencies are
/// never added up, so the net worth report counts the accounts in this
/// currency only.
final reportCurrencyProvider = Provider<String>(
  (ref) => ref.watch(settingsProvider.select((s) => s.currency)),
);

/// The spending rows of the selected range (one grouped query), shared by
/// every spending report so they all use one definition of "spent"
/// ([Spending]).
final _reportSpendingRowsProvider =
    FutureProvider.autoDispose<List<SpendingRow>>((ref) async {
      ref.watch(ledgerChangesProvider);
      final range = ref.watch(reportDateRangeProvider);
      final transactionRepo = ref.watch(transactionRepositoryProvider);
      final bounds = reportQueryBounds(range);
      return transactionRepo.getSpendingRows(bounds.start, bounds.endExclusive);
    });

/// Provider for Spending by Category data.
/// Returns a Map of Category Name -> spent amount (positive minor units).
/// Uncategorised outflows are listed as "Uncategorized" (unless a category
/// filter is set).
final spendingByCategoryProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) async {
    final rows = await ref.watch(_reportSpendingRowsProvider.future);
    final categoryFilter = ref.watch(reportCategoryFilterProvider);
    final categoryRepo = ref.watch(categoryRepositoryProvider);
    final l10n = ref.watch(appLocalizationsProvider);

    final spent = Spending(rows, categoryFilter: categoryFilter).byCategory;
    final categories = await categoryRepo.getAllCategories();
    final categoryNameMap = {for (var c in categories) c.id: c.name};

    final result = <String, int>{};
    for (final entry in spent.entries) {
      final name = entry.key == null
          ? l10n.uncategorized
          : (categoryNameMap[entry.key] ?? l10n.unknown);
      result[name] = (result[name] ?? 0) + entry.value;
    }
    return result;
  },
);

/// Provider for Income vs Expense History.
/// Returns a list of ChartSeries (Income, Expense) with one point per month.
/// Expenses are [Spending.byMonth] (the same figure as Spending Trends and
/// the home dashboard).
final incomeVsExpenseHistoryProvider =
    FutureProvider.autoDispose<List<ChartSeries>>((ref) async {
      ref.watch(ledgerChangesProvider);
      final range = ref.watch(reportDateRangeProvider);
      final rows = await ref.watch(_reportSpendingRowsProvider.future);
      final transactionRepo = ref.watch(transactionRepositoryProvider);
      final l10n = ref.watch(appLocalizationsProvider);
      final bounds = reportQueryBounds(range);

      // A split counts through its children, never twice; off-budget
      // accounts are not part of income and spending.
      final transactions = await transactionRepo.getTransactionsByDateRange(
        bounds.start,
        bounds.endExclusive,
        excludeSplitParents: true,
        onBudgetOnly: true,
      );

      // Income: uncategorised inflows that are not transfers (they flow
      // into To Be Budgeted).
      final incomePoints = <DateTime, int>{};
      for (var t in transactions) {
        if (t.isTransfer || t.amount <= 0 || t.categoryId != null) {
          continue;
        }
        final monthDate = CalendarDate.startOfMonthUtc(t.date);
        incomePoints[monthDate] = (incomePoints[monthDate] ?? 0) + t.amount;
      }
      final expensePoints = {
        for (final entry in Spending(rows).byMonth.entries)
          CalendarDate.parseMonthKey(entry.key): entry.value,
      };

      final sortedDates = {...incomePoints.keys, ...expensePoints.keys}.toList()
        ..sort();

      return [
        ChartSeries(
          name: l10n.reportIncomeSeries,
          kind: ChartSeriesKind.income,
          points: [
            for (final date in sortedDates)
              TimeSeriesPoint(date, incomePoints[date] ?? 0),
          ],
        ),
        ChartSeries(
          name: l10n.reportExpenseSeries,
          kind: ChartSeriesKind.expense,
          points: [
            for (final date in sortedDates)
              TimeSeriesPoint(date, expensePoints[date] ?? 0),
          ],
        ),
      ];
    });

/// Household net worth in the budget currency ([reportCurrencyProvider]):
/// one point at the range start (before its first day), then one at the
/// end of every month (the last one at the range end). Computed from one
/// balance sum and one grouped-by-month SQL query, so no transaction rows
/// are loaded into memory.
///
/// * Accounts in other currencies are left out
///   ([netWorthOtherCurrenciesProvider] names them).
/// * A starting balance counts from the day the account exists: the
///   earlier of its creation and its first transaction, as for To Be
///   Budgeted (an account without a creation time always counts).
/// * The partner's personal accounts have no transactions here, only the
///   balance their phone shared. A transfer between one of them and a
///   shared account reaches this phone as the shared leg only; that leg is
///   left out and the partner's account is counted at its shared balance
///   minus what those transfers brought in (from the day it exists), so a
///   transfer inside the household never moves net worth.
final netWorthHistoryProvider = FutureProvider.autoDispose<List<ChartSeries>>((
  ref,
) async {
  ref.watch(ledgerChangesProvider);
  final range = ref.watch(reportDateRangeProvider);
  final currency = ref.watch(reportCurrencyProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final l10n = ref.watch(appLocalizationsProvider);
  final bounds = reportQueryBounds(range);

  final accounts = [
    for (final a in await accountRepo.getAllAccounts())
      if (a.currency == currency) a,
  ];
  final partnerIds = {
    for (final a in accounts)
      if (a.isPartners) a.id,
  };
  final legs = await transactionRepo.getTransferLegTotals(partnerIds);
  final firstDates = await budgetRepo.getFirstTransactionDates();

  // What each account adds besides its transactions here, and from when.
  final openings = <({DateTime? from, int amount})>[];
  for (final a in accounts) {
    final leg = a.isPartners ? legs[a.id] : null;
    final amount = a.isPartners
        ? a.balance + (leg?.sum ?? 0)
        : a.startingBalance;
    final first = a.isPartners ? leg?.first : firstDates[a.id];
    final created = a.createdAt?.toUtc();
    final from = created == null
        ? null
        : (first != null && first.isBefore(created) ? first : created);
    openings.add((from: from, amount: amount));
  }
  int openingBefore(DateTime endExclusive) => openings.fold<int>(
    0,
    (sum, o) =>
        o.from == null || o.from!.isBefore(endExclusive) ? sum + o.amount : sum,
  );

  var changes = await transactionRepo.getBalanceChangeSum(
    bounds.start,
    currency: currency,
    excludeTransfersTo: partnerIds,
  );
  final monthly = await transactionRepo.getMonthlyBalanceChanges(
    bounds.start,
    bounds.endExclusive,
    currency: currency,
    excludeTransfersTo: partnerIds,
  );

  final rangeEnd = CalendarDate.normalize(range.end);
  final points = <TimeSeriesPoint>[
    TimeSeriesPoint(bounds.start, openingBefore(bounds.start) + changes),
  ];
  var month = CalendarDate.startOfMonthUtc(bounds.start);
  while (!month.isAfter(rangeEnd)) {
    changes += monthly[CalendarDate.monthKey(month)] ?? 0;
    final nextMonth = CalendarDate.endOfMonthUtc(month);
    final end = nextMonth.isAfter(bounds.endExclusive)
        ? bounds.endExclusive
        : nextMonth;
    final lastDay = end.subtract(const Duration(days: 1));
    points.add(TimeSeriesPoint(lastDay, openingBefore(end) + changes));
    month = nextMonth;
  }

  return [
    ChartSeries(
      name: l10n.netWorth,
      kind: ChartSeriesKind.netWorth,
      points: points,
    ),
  ];
});

/// The currencies (sorted codes) of the accounts the net worth report
/// leaves out because they are not in the budget currency.
final netWorthOtherCurrenciesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
      ref.watch(ledgerChangesProvider);
      final currency = ref.watch(reportCurrencyProvider);
      final accountRepo = ref.watch(accountRepositoryProvider);
      final others = {
        for (final a in await accountRepo.getAllAccounts())
          if (a.currency != currency) a.currency,
      };
      return others.toList()..sort();
    });

/// Provider for Spending Trends (Monthly Spending Totals).
/// Returns a Map of month start (UTC) -> total spent (positive minor units):
/// [Spending.byMonth] (only months that spent something).
final spendingTrendsProvider = FutureProvider.autoDispose<Map<DateTime, int>>((
  ref,
) async {
  final rows = await ref.watch(_reportSpendingRowsProvider.future);
  final categoryFilter = ref.watch(reportCategoryFilterProvider);
  return {
    for (final entry in Spending(
      rows,
      categoryFilter: categoryFilter,
    ).byMonth.entries)
      CalendarDate.parseMonthKey(entry.key): entry.value,
  };
});

/// The whole calendar months Budget vs Actual covers: from the first day of
/// the month the selected range starts in to the last day of the month it
/// ends in (inclusive days). Budgets are monthly, so both sides compare the
/// same whole months.
final budgetVsActualMonthsProvider = Provider<DateTimeRange>((ref) {
  final range = ref.watch(reportDateRangeProvider);
  return DateTimeRange(
    start: CalendarDate.startOfMonthUtc(range.start),
    end: CalendarDate.endOfMonthUtc(
      range.end,
    ).subtract(const Duration(days: 1)),
  );
});

/// Provider for Budget vs Actual data over [budgetVsActualMonthsProvider].
///
/// "Actual" is category activity (refunds net, clamped at zero), not the
/// spending figure of the other reports: a categorised transfer to an
/// off-budget account (e.g. "Stocks & ETFs" into the brokerage account)
/// uses up the category's budget, so it counts here although it is not
/// spending.
final budgetVsActualProvider =
    FutureProvider.autoDispose<List<BudgetVsActualItem>>((ref) async {
      ref.watch(ledgerChangesProvider);
      final months = ref.watch(budgetVsActualMonthsProvider);
      final categoryFilter = ref.watch(reportCategoryFilterProvider);
      final budgetRepo = ref.watch(budgetRepositoryProvider);
      final transactionRepo = ref.watch(transactionRepositoryProvider);
      final categoryRepo = ref.watch(categoryRepositoryProvider);
      final l10n = ref.watch(appLocalizationsProvider);

      final budgetedMap = <String, int>{}; // CategoryId -> Total Budgeted
      var current = months.start;
      while (!current.isAfter(months.end)) {
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

      // Activity over the same whole months.
      final expenseMap = await transactionRepo.getCategoryActivitySums(
        months.start,
        CalendarDate.endOfMonthUtc(months.end),
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
        final actual = spentOf(expenseMap[catId] ?? 0);

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
/// Returns list of (Payee Name, spent amount in positive minor units):
/// [Spending.byPayee], i.e. each payee's net (refunds included) per month,
/// clamped at zero; transfers are not payments.
final topPayeesProvider =
    FutureProvider.autoDispose<List<MapEntry<String, int>>>((ref) async {
      final rows = await ref.watch(_reportSpendingRowsProvider.future);
      final payeeRepo = ref.watch(payeeRepositoryProvider);
      final l10n = ref.watch(appLocalizationsProvider);

      final payees = await payeeRepo.getAllPayees();
      final payeeNameMap = {for (var p in payees) p.id: p.name};

      final payeeTotals = <String, int>{};
      for (final entry in Spending(rows).byPayee.entries) {
        final payeeName = entry.key != null
            ? (payeeNameMap[entry.key!] ?? l10n.unknown)
            : l10n.transactionNoPayee;
        payeeTotals[payeeName] = (payeeTotals[payeeName] ?? 0) + entry.value;
      }

      final sortedList = payeeTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedList.take(10).toList();
    });
