import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/daos/categories_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoriesDao _categoriesDao;

  CategoryRepositoryImpl(this._categoriesDao);

  // Category methods

  @override
  Future<List<Category>> getAllCategories() async {
    final categories = await _categoriesDao.getAllCategories();
    return categories.map(_mapCategoryToDomain).toList();
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    final category = await _categoriesDao.getCategoryById(id);
    return category == null ? null : _mapCategoryToDomain(category);
  }

  @override
  Future<void> createCategory(Category category) async {
    await _categoriesDao.insertCategory(_mapCategoryToCompanion(category));
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _categoriesDao.updateCategory(_mapCategoryToCompanion(category));
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _categoriesDao.deleteCategory(id);
  }

  @override
  Stream<List<Category>> watchAllCategories() {
    return _categoriesDao.watchAllCategories().map(
          (categories) => categories.map(_mapCategoryToDomain).toList(),
        );
  }

  // CategoryGroup methods

  @override
  Future<List<CategoryGroup>> getAllCategoryGroups() async {
    final groups = await _categoriesDao.getAllCategoryGroups();
    return groups.map(_mapGroupToDomain).toList();
  }

  @override
  Future<CategoryGroup?> getCategoryGroupById(String id) async {
    final group = await _categoriesDao.getCategoryGroupById(id);
    return group == null ? null : _mapGroupToDomain(group);
  }

  @override
  Future<void> createCategoryGroup(CategoryGroup categoryGroup) async {
    await _categoriesDao
        .insertCategoryGroup(_mapGroupToCompanion(categoryGroup));
  }

  @override
  Future<void> updateCategoryGroup(CategoryGroup categoryGroup) async {
    await _categoriesDao
        .updateCategoryGroup(_mapGroupToCompanion(categoryGroup));
  }

  @override
  Future<void> deleteCategoryGroup(String id) async {
    await _categoriesDao.deleteCategoryGroup(id);
  }

  @override
  Stream<List<CategoryGroup>> watchAllCategoryGroups() {
    return _categoriesDao.watchAllCategoryGroups().map(
          (groups) => groups.map(_mapGroupToDomain).toList(),
        );
  }

  // Mappers

  Category _mapCategoryToDomain(db.Category c) {
    return Category(
      id: c.id,
      name: c.name,
      categoryGroupId: c.categoryGroupId,
      isHidden: c.isHidden,
      sortOrder: c.sortOrder,
      createdAt: c.createdAt,
    );
  }

  db.CategoriesCompanion _mapCategoryToCompanion(Category c) {
    return db.CategoriesCompanion(
      id: Value(c.id),
      name: Value(c.name),
      categoryGroupId: Value(c.categoryGroupId),
      isHidden: Value(c.isHidden),
      sortOrder: Value(c.sortOrder),
      createdAt: Value(c.createdAt),
    );
  }

  CategoryGroup _mapGroupToDomain(db.CategoryGroup g) {
    return CategoryGroup(
      id: g.id,
      name: g.name,
      sortOrder: g.sortOrder,
      createdAt: g.createdAt,
    );
  }

  db.CategoryGroupsCompanion _mapGroupToCompanion(CategoryGroup g) {
    return db.CategoryGroupsCompanion(
      id: Value(g.id),
      name: Value(g.name),
      sortOrder: Value(g.sortOrder),
      createdAt: Value(g.createdAt),
    );
  }
}
