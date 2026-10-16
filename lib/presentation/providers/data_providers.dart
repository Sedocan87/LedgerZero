import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

// The app-wide lookup data (accounts, categories, category groups, payees).
//
// Every concept has exactly one provider, declared here. They live for the
// unlocked session (not autoDispose): they are small, used on most screens,
// and backed by Drift streams, so they always reflect the database. They are
// rebuilt when the database connection changes (unlock, restore).
//
// Use them to *display* data. Event handlers that need a record by id read
// it through the repository instead (`await repo.getXById(id)`), so their
// correctness never depends on a stream being alive.

/// All accounts (open and closed).
final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

/// All categories (including hidden ones).
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategories();
});

/// All category groups.
final categoryGroupsProvider = StreamProvider<List<CategoryGroup>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategoryGroups();
});

/// All payees.
final payeesProvider = StreamProvider<List<Payee>>((ref) {
  return ref.watch(payeeRepositoryProvider).watchAllPayees();
});

/// Account id -> name.
final accountMapProvider = Provider<AsyncValue<Map<String, String>>>((ref) {
  return ref
      .watch(accountsProvider)
      .whenData((list) => {for (final a in list) a.id: a.name});
});

/// Category id -> name.
final categoryMapProvider = Provider<AsyncValue<Map<String, String>>>((ref) {
  return ref
      .watch(categoriesProvider)
      .whenData((list) => {for (final c in list) c.id: c.name});
});

/// Payee id -> name.
final payeeMapProvider = Provider<AsyncValue<Map<String, String>>>((ref) {
  return ref
      .watch(payeesProvider)
      .whenData((list) => {for (final p in list) p.id: p.name});
});

/// A category group with its categories (sorted by sort order).
class CategoryGroupWithCategories {
  final CategoryGroup group;
  final List<Category> categories;

  const CategoryGroupWithCategories({
    required this.group,
    required this.categories,
  });
}

int _groupOrder(CategoryGroup a, CategoryGroup b) =>
    (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0);

int _categoryOrder(Category a, Category b) =>
    (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0);

AsyncValue<List<CategoryGroupWithCategories>> _grouped(
  Ref ref, {
  required bool includeHidden,
}) {
  final groupsAsync = ref.watch(categoryGroupsProvider);
  final categoriesAsync = ref.watch(categoriesProvider);

  if (groupsAsync.hasError) {
    return AsyncValue.error(groupsAsync.error!, groupsAsync.stackTrace!);
  }
  if (categoriesAsync.hasError) {
    return AsyncValue.error(
      categoriesAsync.error!,
      categoriesAsync.stackTrace!,
    );
  }
  final groups = groupsAsync.valueOrNull;
  final categories = categoriesAsync.valueOrNull;
  if (groups == null || categories == null) {
    return const AsyncValue.loading();
  }

  final sortedGroups = List<CategoryGroup>.from(groups)..sort(_groupOrder);
  return AsyncValue.data([
    for (final group in sortedGroups)
      CategoryGroupWithCategories(
        group: group,
        categories:
            categories
                .where(
                  (c) =>
                      c.categoryGroupId == group.id &&
                      (includeHidden || !c.isHidden),
                )
                .toList()
              ..sort(_categoryOrder),
      ),
  ]);
}

/// Every category group (sorted) with all its categories, hidden included
/// (category management).
final categoryGroupsWithCategoriesProvider =
    Provider<AsyncValue<List<CategoryGroupWithCategories>>>(
      (ref) => _grouped(ref, includeHidden: true),
    );

/// Visible categories by (sorted) category group (pickers).
final categoryHierarchyProvider =
    Provider<AsyncValue<Map<CategoryGroup, List<Category>>>>((ref) {
      return _grouped(
        ref,
        includeHidden: false,
      ).whenData((list) => {for (final g in list) g.group: g.categories});
    });
