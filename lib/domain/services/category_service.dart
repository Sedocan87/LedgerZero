import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/category_icon_resolver.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/reference_maintenance_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/rule_reference_cleanup.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

/// Thrown when a category group still holds categories and no target group
/// was given.
class CategoryGroupNotEmptyException implements Exception {
  const CategoryGroupNotEmptyException(this.categoryCount);

  final int categoryCount;

  @override
  String toString() => 'CategoryGroupNotEmptyException($categoryCount)';
}

/// Thrown when a credit card's payment category (or its group) would be
/// deleted, or another category moved into that group, while the card is
/// an open budget card (see `CardPayments`).
class PaymentCategoryProtectedException implements Exception {
  const PaymentCategoryProtectedException(this.id);

  /// The category or group.
  final String id;

  @override
  String toString() => 'PaymentCategoryProtectedException($id)';
}

/// Deletes categories and groups without breaking references.
class CategoryService {
  CategoryService({
    required this._categoryRepository,
    required this._maintenance,
    required this._ruleRepository,
    required this._unitOfWork,
    UndoService? undoService,
    AccountRepository? accountRepository,
  }) : // A named parameter cannot be a private initializing formal.
       // ignore: prefer_initializing_formals
       _undoService = undoService,
       // ignore: prefer_initializing_formals
       _accountRepository = accountRepository;

  /// For the protection of payment categories; without it (sync conflict
  /// resolution, which applies what the other phone decided) nothing is
  /// protected.
  final AccountRepository? _accountRepository;

  /// The ids of the payment categories whose card is an open budget card.
  Future<Set<String>> _activePaymentCategoryIds() async {
    final accounts = await _accountRepository?.getAllAccounts();
    return {
      for (final a in accounts ?? const <Account>[])
        if (CardPayments.isActive(a)) CardPayments.categoryId(a.id),
    };
  }

  final CategoryRepository _categoryRepository;
  final ReferenceMaintenanceRepository _maintenance;
  final RuleRepository _ruleRepository;
  final UnitOfWork _unitOfWork;

  /// Cleared after a delete: recorded transaction snapshots may reference
  /// the deleted entity, and undoing them would fail on a foreign key.
  final UndoService? _undoService;

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
  ///
  /// The payment category of an open budget card cannot be deleted
  /// ([PaymentCategoryProtectedException]); nor can money and transactions
  /// be moved into one.
  Future<void> deleteCategory(String id, {required String? reassignTo}) async {
    if (reassignTo == id) {
      throw ArgumentError.value(reassignTo, 'reassignTo', 'same category');
    }
    final protected = await _activePaymentCategoryIds();
    if (protected.contains(id)) {
      throw PaymentCategoryProtectedException(id);
    }
    if (reassignTo != null && protected.contains(reassignTo)) {
      throw PaymentCategoryProtectedException(reassignTo);
    }
    return _unitOfWork
        .run(() async {
          await _maintenance.moveBudgets(id, reassignTo);
          await _maintenance.reassignCategoryReferences(id, reassignTo);
          await replaceRuleActionReferences(
            _ruleRepository,
            type: RuleActionType.setCategory,
            fromId: id,
            toId: reassignTo,
          );
          await _categoryRepository.deleteCategory(id);
        })
        .whenComplete(() => _undoService?.clear());
  }

  /// Number of categories in [groupId].
  Future<int> countCategoriesInGroup(String groupId) =>
      _maintenance.countCategoriesInGroup(groupId);

  /// Deletes group [groupId]. Its categories move to [moveCategoriesTo]
  /// (with their budgets and transactions); a group that still has
  /// categories cannot be deleted without a target. The "Credit Card
  /// Payments" group cannot be deleted while it holds the payment category
  /// of an open budget card, and no other group's categories move into it
  /// ([PaymentCategoryProtectedException]).
  Future<void> deleteCategoryGroup(
    String groupId, {
    required String? moveCategoriesTo,
  }) async {
    if (moveCategoriesTo == CardPayments.groupId) {
      throw PaymentCategoryProtectedException(moveCategoriesTo!);
    }
    if (groupId == CardPayments.groupId) {
      final protected = await _activePaymentCategoryIds();
      final inGroup = await _categoryRepository.getAllCategories();
      if (inGroup.any(
        (c) => c.categoryGroupId == groupId && protected.contains(c.id),
      )) {
        throw PaymentCategoryProtectedException(groupId);
      }
    }
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

  /// Adds the default group [englishGroup] (a key of
  /// [DefaultCategories.groups]) with its categories, named by [nameOf] (the
  /// app language), after the existing groups. Ids are the deterministic
  /// default ids, so rows that already exist (added on another device, or
  /// seeded) are kept and nothing is duplicated.
  Future<void> addDefaultGroup(
    String englishGroup,
    String Function(String englishName) nameOf,
  ) {
    final names = DefaultCategories.groups[englishGroup];
    if (names == null) {
      throw ArgumentError.value(englishGroup, 'englishGroup');
    }
    return _unitOfWork.run(() async {
      final now = DateTime.now().toUtc();
      final groupId = DeterministicId.defaultGroup(englishGroup);
      final groups = await _categoryRepository.getAllCategoryGroups();
      if (!groups.any((g) => g.id == groupId)) {
        final lastSort = groups
            .map((g) => g.sortOrder ?? 0)
            .fold<int>(-1, (a, b) => a > b ? a : b);
        await _categoryRepository.createCategoryGroup(
          CategoryGroup(
            id: groupId,
            name: nameOf(englishGroup),
            sortOrder: lastSort + 1,
            createdAt: now,
          ),
        );
      }
      for (final (index, name) in names.indexed) {
        final id = DeterministicId.defaultCategory(englishGroup, name);
        if (await _categoryRepository.getCategoryById(id) == null) {
          await _categoryRepository.createCategory(
            Category(
              id: id,
              name: nameOf(name),
              categoryGroupId: groupId,
              icon: CategoryIconResolver.keyForDefault(name),
              sortOrder: index,
              createdAt: now,
            ),
          );
        }
      }
    });
  }
}
