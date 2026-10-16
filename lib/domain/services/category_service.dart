import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/reference_maintenance_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/rule_reference_cleanup.dart';

/// Thrown when a category group still holds categories and no target group
/// was given.
class CategoryGroupNotEmptyException implements Exception {
  const CategoryGroupNotEmptyException(this.categoryCount);

  final int categoryCount;

  @override
  String toString() => 'CategoryGroupNotEmptyException($categoryCount)';
}

/// Deletes categories and groups without breaking references.
class CategoryService {
  CategoryService({
    required this._categoryRepository,
    required this._maintenance,
    required this._ruleRepository,
    required this._unitOfWork,
  });

  final CategoryRepository _categoryRepository;
  final ReferenceMaintenanceRepository _maintenance;
  final RuleRepository _ruleRepository;
  final UnitOfWork _unitOfWork;

  /// Number of (non-deleted) transactions using [categoryId].
  Future<int> countTransactions(String categoryId) =>
      _maintenance.countTransactionsWithCategory(categoryId);

  /// Deletes category [id] in one unit of work.
  ///
  /// With [reassignTo]: its budgets are merged into the target's budget row
  /// of the same month (so To Be Budgeted is unchanged) and every reference
  /// (all transactions including soft-deleted ones, payee default
  /// categories, scheduled transactions, parsing rules, budget templates,
  /// rule actions) moves to the target.
  ///
  /// With `reassignTo: null`: its budgets are deleted (the money they held
  /// returns to To Be Budgeted) and its transactions become uncategorised
  /// (they then count towards To Be Budgeted as well); other references are
  /// cleared and rule actions setting it are removed.
  Future<void> deleteCategory(String id, {required String? reassignTo}) {
    if (reassignTo == id) {
      throw ArgumentError.value(reassignTo, 'reassignTo', 'same category');
    }
    return _unitOfWork.run(() async {
      await _maintenance.moveBudgets(id, reassignTo);
      await _maintenance.reassignCategoryReferences(id, reassignTo);
      await replaceRuleActionReferences(
        _ruleRepository,
        type: RuleActionType.setCategory,
        fromId: id,
        toId: reassignTo,
      );
      await _categoryRepository.deleteCategory(id);
    });
  }

  /// Number of categories in [groupId].
  Future<int> countCategoriesInGroup(String groupId) =>
      _maintenance.countCategoriesInGroup(groupId);

  /// Deletes group [groupId]. Its categories move to [moveCategoriesTo]
  /// (with their budgets and transactions); a group that still has
  /// categories cannot be deleted without a target.
  Future<void> deleteCategoryGroup(
    String groupId, {
    required String? moveCategoriesTo,
  }) {
    return _unitOfWork.run(() async {
      final count = await _maintenance.countCategoriesInGroup(groupId);
      if (count > 0) {
        if (moveCategoriesTo == null || moveCategoriesTo == groupId) {
          throw CategoryGroupNotEmptyException(count);
        }
        await _maintenance.moveCategoriesToGroup(groupId, moveCategoriesTo);
      }
      await _categoryRepository.deleteCategoryGroup(groupId);
    });
  }
}
