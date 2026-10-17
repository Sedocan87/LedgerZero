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

/// State for the selected month in the budget screen, as the first day of
/// the month at UTC midnight. Defaults to the current month.
final selectedBudgetMonthProvider = StateProvider<DateTime>((ref) {
  return CalendarDate.startOfMonthUtc(CalendarDate.today());
});

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
        final dates = s.occurrencesBetween(start, end);
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
      final current = CalendarDate.startOfMonthUtc(CalendarDate.today());
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
  if (month != CalendarDate.startOfMonthUtc(CalendarDate.today())) {
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

/// ViewModel for a category group section in the budget screen.
class BudgetGroupViewModel {
  final CategoryGroup group;
  final List<BudgetCategoryViewModel> categories;

  const BudgetGroupViewModel({required this.group, required this.categories});
}

/// Provider that builds the list of budget groups and categories with their calculated amounts.
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

      final List<BudgetGroupViewModel> result = [];

      for (final group in sortedGroups) {
        var groupCategories = categories
            .where((c) => c.categoryGroupId == group.id)
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

        final categoryViewModels = groupCategories.map((category) {
          // Get budgeted amount from batch fetched map
          final budget = budgetMap[category.id];
          final budgeted = budget?.budgeted ?? 0;

          // Get calculated activity and available from batch data
          final catPerf = performanceData[category.id];
          final activity = catPerf?['activity'] ?? 0;
          final available = catPerf?['available'] ?? 0;

          // Get calculated goal target
          final goalTarget = goalTargets[category.id] ?? 0;

          return BudgetCategoryViewModel(
            category: category,
            budgeted: budgeted,
            activity: activity,
            available: available,
            goalTarget: goalTarget,
          );
        }).toList();

        result.add(
          BudgetGroupViewModel(group: group, categories: categoryViewModels),
        );
      }

      return result;
    });
