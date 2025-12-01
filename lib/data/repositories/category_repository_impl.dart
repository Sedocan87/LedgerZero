import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/categories_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoriesDao _categoriesDao;

  CategoryRepositoryImpl(this._categoriesDao);

  // Category methods

  @override
  Future<List<Category>> getAllCategories() async {
    try {
      Logger.debug('Fetching all categories');
      final categories = await _categoriesDao.getAllCategories();
      Logger.debug('Fetched ${categories.length} categories');
      return categories.map(_mapCategoryToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch categories', e, stackTrace);
      throw DatabaseException('Failed to fetch categories', e);
    }
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    try {
      Logger.debug('Fetching category with id: $id');
      final category = await _categoriesDao.getCategoryById(id);
      Logger.debug('Category found: ${category != null}');
      return category == null ? null : _mapCategoryToDomain(category);
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch category $id', e, stackTrace);
      throw DatabaseException('Failed to fetch category $id', e);
    }
  }

  @override
  Future<void> createCategory(Category category) async {
    try {
      Logger.debug('Creating category: ${category.name}');
      await _categoriesDao.insertCategory(_mapCategoryToCompanion(category));
      Logger.info('Category created successfully: ${category.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create category ${category.id}', e, stackTrace);
      throw DatabaseException('Failed to create category ${category.id}', e);
    }
  }

  @override
  Future<void> updateCategory(Category category) async {
    try {
      Logger.debug('Updating category: ${category.id}');
      await _categoriesDao.updateCategory(_mapCategoryToCompanion(category));
      Logger.info('Category updated successfully: ${category.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update category ${category.id}', e, stackTrace);
      throw DatabaseException('Failed to update category ${category.id}', e);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      Logger.debug('Deleting category: $id');
      await _categoriesDao.deleteCategory(id);
      Logger.info('Category deleted successfully: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete category $id', e, stackTrace);
      throw DatabaseException('Failed to delete category $id', e);
    }
  }

  @override
  Stream<List<Category>> watchAllCategories() {
    return _categoriesDao.watchAllCategories().map(
      (categories) {
        return categories.map(_mapCategoryToDomain).toList();
      },
    ).handleError((error, stackTrace) {
      Logger.error('Error in watchAllCategories stream', error, stackTrace);
      throw DatabaseException('Error watching categories', error);
    });
  }

  // CategoryGroup methods

  @override
  Future<List<CategoryGroup>> getAllCategoryGroups() async {
    try {
      Logger.debug('Fetching all category groups');
      final groups = await _categoriesDao.getAllCategoryGroups();
      Logger.debug('Fetched ${groups.length} category groups');
      return groups.map(_mapGroupToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch category groups', e, stackTrace);
      throw DatabaseException('Failed to fetch category groups', e);
    }
  }

  @override
  Future<CategoryGroup?> getCategoryGroupById(String id) async {
    try {
      Logger.debug('Fetching category group with id: $id');
      final group = await _categoriesDao.getCategoryGroupById(id);
      Logger.debug('Category group found: ${group != null}');
      return group == null ? null : _mapGroupToDomain(group);
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch category group $id', e, stackTrace);
      throw DatabaseException('Failed to fetch category group $id', e);
    }
  }

  @override
  Future<void> createCategoryGroup(CategoryGroup categoryGroup) async {
    try {
      Logger.debug('Creating category group: ${categoryGroup.name}');
      await _categoriesDao
          .insertCategoryGroup(_mapGroupToCompanion(categoryGroup));
      Logger.info('Category group created successfully: ${categoryGroup.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create category group ${categoryGroup.id}', e, stackTrace);
      throw DatabaseException('Failed to create category group ${categoryGroup.id}', e);
    }
  }

  @override
  Future<void> updateCategoryGroup(CategoryGroup categoryGroup) async {
    try {
      Logger.debug('Updating category group: ${categoryGroup.id}');
      await _categoriesDao
          .updateCategoryGroup(_mapGroupToCompanion(categoryGroup));
      Logger.info('Category group updated successfully: ${categoryGroup.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update category group ${categoryGroup.id}', e, stackTrace);
      throw DatabaseException('Failed to update category group ${categoryGroup.id}', e);
    }
  }

  @override
  Future<void> deleteCategoryGroup(String id) async {
    try {
      Logger.debug('Deleting category group: $id');
      await _categoriesDao.deleteCategoryGroup(id);
      Logger.info('Category group deleted successfully: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete category group $id', e, stackTrace);
      throw DatabaseException('Failed to delete category group $id', e);
    }
  }

  @override
  Stream<List<CategoryGroup>> watchAllCategoryGroups() {
    return _categoriesDao.watchAllCategoryGroups().map(
      (groups) {
        return groups.map(_mapGroupToDomain).toList();
      },
    ).handleError((error, stackTrace) {
      Logger.error('Error in watchAllCategoryGroups stream', error, stackTrace);
      throw DatabaseException('Error watching category groups', error);
    });
  }

  // Mappers

  Category _mapCategoryToDomain(db.Category c) {
    return Category(
      id: c.id,
      name: c.name,
      categoryGroupId: c.categoryGroupId,
      isHidden: c.isHidden,
      sortOrder: c.sortOrder,
      goalType: GoalType.fromName(c.goalType),
      targetAmount: c.targetAmount,
      targetDate: c.targetDate,
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
      goalType: Value(c.goalType?.toName()),
      targetAmount: Value(c.targetAmount),
      targetDate: Value(c.targetDate),
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
