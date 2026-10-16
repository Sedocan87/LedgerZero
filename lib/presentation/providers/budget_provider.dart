import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

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
