import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';

/// Repository interface for managing [Category] and [CategoryGroup] entities.
abstract class CategoryRepository {
  // Category methods

  /// Retrieves all categories.
  Future<List<Category>> getAllCategories();

  /// Retrieves a category by its unique identifier.
  Future<Category?> getCategoryById(String id);

  /// Creates a new category.
  Future<void> createCategory(Category category);

  /// Updates an existing category.
  Future<void> updateCategory(Category category);

  /// Deletes a category by its unique identifier.
  Future<void> deleteCategory(String id);

  /// Watches all categories for changes.
  Stream<List<Category>> watchAllCategories();

  // CategoryGroup methods

  /// Retrieves all category groups.
  Future<List<CategoryGroup>> getAllCategoryGroups();

  /// Retrieves a category group by its unique identifier.
  Future<CategoryGroup?> getCategoryGroupById(String id);

  /// Creates a new category group.
  Future<void> createCategoryGroup(CategoryGroup categoryGroup);

  /// Updates an existing category group.
  Future<void> updateCategoryGroup(CategoryGroup categoryGroup);

  /// Deletes a category group by its unique identifier.
  Future<void> deleteCategoryGroup(String id);

  /// Watches all category groups for changes.
  Stream<List<CategoryGroup>> watchAllCategoryGroups();

  /// Brings the credit-card payment categories in line with the accounts
  /// (see `CardPayments`): creates missing ones, renames, hides and shows
  /// them. [stampedAt] is the `updated_at` of the rows it writes (the
  /// start-up self-heal passes [cardPaymentHealStamp]). Idempotent.
  Future<void> syncCardPaymentCategories({DateTime? stampedAt});
}

/// The `updated_at` of rows written by the start-up self-heal of the
/// payment categories: fixed and old, so two phones healing at the same
/// time write identical rows and every real edit wins under
/// last-writer-wins (like `BudgetingService.automaticFillStamp`).
final DateTime cardPaymentHealStamp = DateTime.utc(2024);
