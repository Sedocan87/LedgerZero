import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

// Re-export payeesProvider from payee_provider.dart
export 'package:ledger_zero/presentation/providers/payee_provider.dart' show payeesProvider, suggestedPayeesProvider;

// Consolidated global data providers to be used across the app
// to avoid duplicate StreamProviders in individual screens.

/// Provides a stream of all accounts.
final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

/// Provides a stream of all categories.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategories();
});

/// Provides a stream of all category groups.
final categoryGroupsProvider = StreamProvider<List<CategoryGroup>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategoryGroups();
});

/// Provides a structured map of CategoryGroup -> List<Category>
final categoryHierarchyProvider = Provider<AsyncValue<Map<CategoryGroup, List<Category>>>>((ref) {
  final categoriesAsync = ref.watch(categoriesProvider);
  final groupsAsync = ref.watch(categoryGroupsProvider);

  if (categoriesAsync.isLoading || groupsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (categoriesAsync.hasError) {
    return AsyncValue.error(categoriesAsync.error!, categoriesAsync.stackTrace!);
  }
  if (groupsAsync.hasError) {
    return AsyncValue.error(groupsAsync.error!, groupsAsync.stackTrace!);
  }

  final categories = categoriesAsync.value ?? [];
  final groups = groupsAsync.value ?? [];

  final map = <CategoryGroup, List<Category>>{};

  // Sort groups by sortOrder
  final sortedGroups = List<CategoryGroup>.from(groups)
    ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

  for (final group in sortedGroups) {
    final groupCategories = categories
        .where((c) => c.categoryGroupId == group.id && !(c.isHidden))
        .toList();
    // Sort categories by sortOrder
    groupCategories.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    map[group] = groupCategories;
  }

  return AsyncValue.data(map);
});
