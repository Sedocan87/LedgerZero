import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/category_groups.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, CategoryGroups])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  // Category methods
  Future<List<Category>> getAllCategories() => select(categories).get();

  Future<Category?> getCategoryById(String id) =>
      (select(categories)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  Future<bool> updateCategory(CategoriesCompanion category) =>
      update(categories).replace(category);

  Future<int> deleteCategory(String id) =>
      (delete(categories)..where((tbl) => tbl.id.equals(id))).go();

  Stream<List<Category>> watchAllCategories() => select(categories).watch();

  // CategoryGroup methods
  Future<List<CategoryGroup>> getAllCategoryGroups() =>
      select(categoryGroups).get();

  Future<CategoryGroup?> getCategoryGroupById(String id) => (select(
    categoryGroups,
  )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertCategoryGroup(CategoryGroupsCompanion group) =>
      into(categoryGroups).insert(group);

  Future<bool> updateCategoryGroup(CategoryGroupsCompanion group) =>
      update(categoryGroups).replace(group);

  Future<int> deleteCategoryGroup(String id) =>
      (delete(categoryGroups)..where((tbl) => tbl.id.equals(id))).go();

  Stream<List<CategoryGroup>> watchAllCategoryGroups() =>
      select(categoryGroups).watch();
}
