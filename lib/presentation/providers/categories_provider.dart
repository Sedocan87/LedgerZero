import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

class CategoryGroupWithCategories {
  final CategoryGroup group;
  final List<Category> categories;

  const CategoryGroupWithCategories({
    required this.group,
    required this.categories,
  });
}

final categoryGroupsStreamProvider = StreamProvider<List<CategoryGroup>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategoryGroups();
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategories();
});

final categoryGroupsWithCategoriesProvider =
    Provider.autoDispose<AsyncValue<List<CategoryGroupWithCategories>>>((ref) {
      final groupsAsync = ref.watch(categoryGroupsStreamProvider);
      final categoriesAsync = ref.watch(categoriesStreamProvider);

      // If any are loading, return loading
      if (groupsAsync.isLoading || categoriesAsync.isLoading) {
        return const AsyncValue.loading();
      }

      // If any error, return error
      if (groupsAsync.hasError) {
        return AsyncValue.error(groupsAsync.error!, groupsAsync.stackTrace!);
      }
      if (categoriesAsync.hasError) {
        return AsyncValue.error(
          categoriesAsync.error!,
          categoriesAsync.stackTrace!,
        );
      }

      final groups = groupsAsync.valueOrNull ?? [];
      final categories = categoriesAsync.valueOrNull ?? [];

      // Sort groups by sortOrder
      final sortedGroups = List<CategoryGroup>.from(groups)
        ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

      final result = sortedGroups.map((group) {
        final groupCategories =
            categories.where((c) => c.categoryGroupId == group.id).toList()
              ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

        return CategoryGroupWithCategories(
          group: group,
          categories: groupCategories,
        );
      }).toList();

      return AsyncValue.data(result);
    });
