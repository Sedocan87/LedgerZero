import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';

/// Today's calendar day (UTC midnight of the local day), kept current: it
/// re-evaluates itself at midnight and whenever a screen reports that the
/// app was resumed ([refresh]), so the default month moves on after the
/// 1st even if the process has been alive for weeks.
class TodayController extends StateNotifier<DateTime> {
  TodayController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(CalendarDate.today(now: (clock ?? DateTime.now)())) {
    _armMidnight();
  }

  final DateTime Function() _clock;
  Timer? _timer;

  /// Re-reads the clock (call on app resume).
  void refresh() {
    final today = CalendarDate.today(now: _clock());
    if (today != state) {
      state = today;
    }
    _armMidnight();
  }

  void _armMidnight() {
    _timer?.cancel();
    final now = _clock();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      refresh,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final todayProvider = StateNotifierProvider<TodayController, DateTime>(
  (ref) => TodayController(),
);

/// The current calendar month (first day, UTC midnight), from
/// [todayProvider].
final currentMonthProvider = Provider<DateTime>(
  (ref) => CalendarDate.startOfMonthUtc(ref.watch(todayProvider)),
);

/// Makes a month [StateProvider] follow the calendar: when the current
/// month changes (midnight on the 1st, or the app resumes in a new month)
/// and the selection still shows the month that was current, it moves to
/// the new one. A month the user navigated to is left alone.
// StateProviderRef is the only ref with `controller`; the deprecation is
// about Riverpod 3, which this app does not use yet.
// ignore: deprecated_member_use
DateTime followCurrentMonth(StateProviderRef<DateTime> ref) {
  ref.listen(currentMonthProvider, (previous, next) {
    if (previous == null || ref.controller.state == previous) {
      ref.controller.state = next;
    }
  });
  return ref.read(currentMonthProvider);
}

/// State for the selected month in the budget screen, as the first day of
/// the month at UTC midnight. Defaults to the current month and follows it
/// ([followCurrentMonth]).
final selectedBudgetMonthProvider = StateProvider<DateTime>(followCurrentMonth);

/// Provider for budget screen search query.
final budgetSearchQueryProvider = StateProvider<String>((ref) => '');

/// "To Be Budgeted" (minor units) of [month] (first day of the month, UTC).
///
/// Recomputed whenever the ledger changes (transactions, budgets, accounts),
/// so no screen has to invalidate it by hand.
final tbbProvider = FutureProvider.autoDispose.family<int, DateTime>((
  ref,
  month,
) {
  ref.watch(ledgerChangesProvider);
  return ref.watch(budgetingServiceProvider).calculateTBB(month);
});

/// Income of a budget month, shown under To Be Budgeted.
///
/// All amounts are minor units.
class MonthIncome {
  /// Inflows that reached To Be Budgeted in the month.
  final int received;

  /// Occurrences of recurring income into To Be Budgeted that are still to
  /// come in the month. Informational only: TBB counts them once they
  /// arrive.
  final int expected;

  /// The first of those occurrences, or null when [expected] is zero.
  final DateTime? nextExpectedDate;

  /// Whether any recurring income (salary) is set up, whatever its account
  /// or category.
  final bool hasRecurringIncome;

  const MonthIncome({
    required this.received,
    required this.expected,
    required this.nextExpectedDate,
    required this.hasRecurringIncome,
  });
}

/// [MonthIncome] of [month] (first day of the month, UTC).
final monthIncomeProvider = FutureProvider.autoDispose
    .family<MonthIncome, DateTime>((ref, month) async {
      ref.watch(ledgerChangesProvider);
      final today = ref.watch(todayProvider);
      final schedules = await ref.watch(scheduledTransactionsProvider.future);
      final accounts = await ref.watch(accountsProvider.future);
      final received = await ref
          .watch(budgetingServiceProvider)
          .calculateTotalIncomeForMonth(month);

      final onBudgetAccountIds = {
        for (final a in accounts)
          if (a.onBudget) a.id,
      };
      final start = CalendarDate.startOfMonthUtc(month);
      final end = CalendarDate.endOfMonthUtc(month);
      var hasRecurringIncome = false;
      var expected = 0;
      DateTime? nextExpectedDate;
      for (final s in schedules) {
        final amount = s.amount ?? 0;
        if (amount <= 0 || s.isFinished) {
          continue;
        }
        hasRecurringIncome = true;
        // Like the generated transactions: only uncategorised inflows of
        // on-budget accounts reach To Be Budgeted.
        if (s.categoryId != null || !onBudgetAccountIds.contains(s.accountId)) {
          continue;
        }
        // Only occurrences still to come: one whose date has passed is
        // either booked already (then it counts as received) or overdue,
        // not expected.
        final dates = s
            .occurrencesBetween(start, end)
            .where((d) => !d.isBefore(today))
            .toList();
        if (dates.isEmpty) {
          continue;
        }
        expected += amount * dates.length;
        if (nextExpectedDate == null ||
            dates.first.isBefore(nextExpectedDate)) {
          nextExpectedDate = dates.first;
        }
      }

      return MonthIncome(
        received: received,
        expected: expected,
        nextExpectedDate: nextExpectedDate,
        hasRecurringIncome: hasRecurringIncome,
      );
    });

/// What "Fill like (previous month)" would budget in [month] (category ->
/// amount, minor units). Empty unless [month] is the current or a later
/// month, nothing is budgeted in it yet and the month before has budgets.
final newMonthOfferProvider = FutureProvider.autoDispose
    .family<Map<String, int>, DateTime>((ref, month) async {
      ref.watch(ledgerChangesProvider);
      final current = ref.watch(currentMonthProvider);
      if (month.isBefore(current)) {
        return const {};
      }
      final budgeting = ref.watch(budgetingServiceProvider);
      if (!await budgeting.isMonthEmpty(month)) {
        return const {};
      }
      return budgeting.planFill(
        month,
        await budgeting.budgetsOfPreviousMonth(month),
      );
    });

/// Money the month before [month] left unassigned that is still in To Be
/// Budgeted (minor units; 0 when there is none to offer). Only for the
/// current month, and only when the month before was budgeted at all: a
/// new account's starting balance counts in every month and is not a
/// leftover.
final leftoverProvider = FutureProvider.autoDispose.family<int, DateTime>((
  ref,
  month,
) async {
  ref.watch(ledgerChangesProvider);
  if (month != ref.watch(currentMonthProvider)) {
    return 0;
  }
  final previous = DateTime.utc(month.year, month.month - 1, 1);
  final budgeting = ref.watch(budgetingServiceProvider);
  if (await budgeting.isMonthEmpty(previous)) {
    return 0;
  }
  final left = await budgeting.calculateTBB(previous);
  final now = await budgeting.calculateTBB(month);
  return math.max(0, math.min(left, now));
});

/// The saved budget templates (invalidated when one is saved or deleted).
final budgetTemplatesProvider =
    FutureProvider.autoDispose<List<BudgetTemplate>>(
      (ref) => ref.watch(budgetingServiceProvider).getAllTemplates(),
    );

/// ViewModel for a single category row in the budget screen.
///
/// All amounts are minor units.
class BudgetCategoryViewModel {
  final Category category;
  final int budgeted;
  final int activity;
  final int available;
  final int goalTarget;

  const BudgetCategoryViewModel({
    required this.category,
    required this.budgeted,
    required this.activity,
    required this.available,
    required this.goalTarget,
  });
}

/// Id of the pseudo-group that collects hidden categories with money.
const hiddenBudgetGroupId = 'budget.hidden-categories';

/// ViewModel for a category group section in the budget screen.
class BudgetGroupViewModel {
  final CategoryGroup group;
  final List<BudgetCategoryViewModel> categories;

  /// The collapsed "Hidden categories" section: hidden categories that
  /// still have money budgeted or available (it counts in To Be Budgeted,
  /// so it must stay reachable). [group] is a placeholder; the screen
  /// shows a localised title.
  final bool isHiddenGroup;

  const BudgetGroupViewModel({
    required this.group,
    required this.categories,
    this.isHiddenGroup = false,
  });

  const BudgetGroupViewModel.hidden(this.categories)
    : group = const CategoryGroup(id: hiddenBudgetGroupId, name: ''),
      isHiddenGroup = true;
}

/// Provider that builds the list of budget groups and categories with their
/// calculated amounts. Hidden categories are left out, except those that
/// still have money budgeted or available (or activity) in the month: they
/// form a last, collapsed "Hidden categories" section.
final budgetViewModelProvider =
    FutureProvider.autoDispose<List<BudgetGroupViewModel>>((ref) async {
      final month = ref.watch(selectedBudgetMonthProvider);
      final searchQuery = ref.watch(budgetSearchQueryProvider).toLowerCase();

      // Recompute after every ledger write (transactions, budgets, moves,
      // category changes).
      ref.watch(ledgerChangesProvider);

      // Stays loading until the category streams have data (no flash of
      // an empty budget).
      final groups = await ref.watch(categoryGroupsProvider.future);
      final categories = await ref.watch(categoriesProvider.future);

      final budgetingService = ref.watch(budgetingServiceProvider);
      final budgetRepository = ref.watch(budgetRepositoryProvider);
      final monthString = CalendarDate.monthKey(month);

      // Batch fetch budgets for the month to avoid N+1 queries
      final budgets = await budgetRepository.getBudgetsForMonth(monthString);
      final budgetMap = {for (var b in budgets) b.categoryId: b};

      // Batch fetch performance data (Activity, Available) to avoid N+1 queries
      final performanceData = await budgetingService
          .calculateBatchCategoryPerformance(month);

      // Batch fetch goal targets
      final goalTargets = await budgetingService.calculateBatchGoalTargets(
        month,
        categories,
      );

      // Sort groups by sortOrder
      final sortedGroups = List<CategoryGroup>.from(groups)
        ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

      BudgetCategoryViewModel viewModelOf(Category category) {
        final catPerf = performanceData[category.id];
        return BudgetCategoryViewModel(
          category: category,
          budgeted: budgetMap[category.id]?.budgeted ?? 0,
          activity: catPerf?['activity'] ?? 0,
          available: catPerf?['available'] ?? 0,
          goalTarget: goalTargets[category.id] ?? 0,
        );
      }

      bool matchesSearch(Category c) =>
          searchQuery.isEmpty || c.name.toLowerCase().contains(searchQuery);

      final List<BudgetGroupViewModel> result = [];

      for (final group in sortedGroups) {
        var groupCategories = categories
            .where((c) => c.categoryGroupId == group.id && !c.isHidden)
            .toList();

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          groupCategories = groupCategories
              .where((c) => c.name.toLowerCase().contains(searchQuery))
              .toList();
        }

        // Skip group if no categories match (and we are searching)
        if (searchQuery.isNotEmpty && groupCategories.isEmpty) {
          continue;
        }

        groupCategories.sort(
          (a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0),
        );

        result.add(
          BudgetGroupViewModel(
            group: group,
            categories: groupCategories.map(viewModelOf).toList(),
          ),
        );
      }

      // Hidden categories with money: their budgets and balances still
      // count towards To Be Budgeted, so they stay visible, collapsed.
      final hiddenWithMoney =
          [
                for (final c in categories)
                  if (c.isHidden && matchesSearch(c)) viewModelOf(c),
              ]
              .where(
                (vm) =>
                    vm.budgeted != 0 || vm.available != 0 || vm.activity != 0,
              )
              .toList()
            ..sort((a, b) => a.category.name.compareTo(b.category.name));
      if (hiddenWithMoney.isNotEmpty) {
        result.add(BudgetGroupViewModel.hidden(hiddenWithMoney));
      }

      return result;
    });
