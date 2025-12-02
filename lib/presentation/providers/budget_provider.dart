import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/presentation/providers/categories_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

/// State for the selected month in the budget screen.
/// Defaults to the current month.
final selectedBudgetMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Provider for budget screen search query.
final budgetSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for "To Be Budgeted" amount for the selected month.
final tbbProvider = FutureProvider.autoDispose<double>((ref) async {
  final month = ref.watch(selectedBudgetMonthProvider);
  final budgetingService = ref.watch(budgetingServiceProvider);

  // Calculate TBB
  return budgetingService.calculateTBB(month);
});

/// ViewModel for a single category row in the budget screen.
class BudgetCategoryViewModel {
  final Category category;
  final double budgeted;
  final double activity;
  final double available;

  const BudgetCategoryViewModel({
    required this.category,
    required this.budgeted,
    required this.activity,
    required this.available,
  });
}

/// ViewModel for a category group section in the budget screen.
class BudgetGroupViewModel {
  final CategoryGroup group;
  final List<BudgetCategoryViewModel> categories;

  const BudgetGroupViewModel({
    required this.group,
    required this.categories,
  });
}

/// Provider that builds the list of budget groups and categories with their calculated amounts.
final budgetViewModelProvider = FutureProvider.autoDispose<List<BudgetGroupViewModel>>((ref) async {
  final month = ref.watch(selectedBudgetMonthProvider);
  final searchQuery = ref.watch(budgetSearchQueryProvider).toLowerCase();

  // Wait for category data streams to load.
  // This ensures the provider stays in 'loading' state until data is ready,
  // preventing UI flash of empty state.
  final groups = await ref.watch(categoryGroupsStreamProvider.future);
  final categories = await ref.watch(categoriesStreamProvider.future);

  final budgetingService = ref.watch(budgetingServiceProvider);
  final budgetRepository = ref.watch(budgetRepositoryProvider);
  final dateFormat = DateFormat('yyyy-MM');
  final monthString = dateFormat.format(month);

  // Batch fetch budgets for the month to avoid N+1 queries
  final budgets = await budgetRepository.getBudgetsForMonth(monthString);
  final budgetMap = { for (var b in budgets) b.categoryId: b };

  // Batch fetch performance data (Activity, Available) to avoid N+1 queries
  final performanceData = await budgetingService.calculateBatchCategoryPerformance(month);

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
      groupCategories = groupCategories.where((c) => c.name.toLowerCase().contains(searchQuery)).toList();
    }

    // Skip group if no categories match (and we are searching)
    if (searchQuery.isNotEmpty && groupCategories.isEmpty) {
      continue;
    }

    groupCategories.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    final categoryViewModels = groupCategories.map((category) {
      // Get budgeted amount from batch fetched map
      final budget = budgetMap[category.id];
      final budgeted = budget?.budgeted ?? 0.0;

      // Get calculated activity and available from batch data
      final catPerf = performanceData[category.id];
      final activity = catPerf?['activity'] ?? 0.0;
      final available = catPerf?['available'] ?? 0.0;

      return BudgetCategoryViewModel(
        category: category,
        budgeted: budgeted,
        activity: activity,
        available: available,
      );
    }).toList();

    result.add(BudgetGroupViewModel(
      group: group,
      categories: categoryViewModels,
    ));
  }

  return result;
});

/// Provider that returns a flat list of category IDs in the order they appear in the budget screen.
/// Used for keyboard navigation.
final budgetOrderedCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final viewModels = await ref.watch(budgetViewModelProvider.future);
  return viewModels
      .expand((group) => group.categories.map((c) => c.category.id))
      .toList();
});
