import 'package:drift/drift.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/category_groups.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';

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

  /// Creates, renames, hides or shows the payment categories of the credit
  /// cards (all accounts, or only [accountId]) so they match the accounts,
  /// and creates the "Credit Card Payments" group when one is needed.
  ///
  /// A shared, on-budget credit account gets the category
  /// `DeterministicId.cardPayment(accountId)` in the group
  /// `DeterministicId.cardPaymentGroup`, named like the account, hidden
  /// while the account is closed. An account that stops being a budget card
  /// (off budget, personal, another type) keeps its category, hidden. Rows
  /// that already match are not written. Idempotent.
  ///
  /// [stampedAt] replaces the current time as `updated_at` (and
  /// `created_at` of new rows): the start-up self-heal passes a fixed old
  /// time, so two phones healing the same rows write identical rows and any
  /// real edit is newer and wins under last-writer-wins. The group is
  /// always stamped with `AppDatabase.seedTimestamp`, like the seeded
  /// default groups. Returns the number of categories written.
  Future<int> syncCardPaymentCategories({
    String? accountId,
    DateTime? stampedAt,
  }) {
    return transaction(() async {
      final accounts = attachedDatabase.accounts;
      final query = select(accounts);
      if (accountId != null) {
        query.where((a) => a.id.equals(accountId));
      }
      final now = (stampedAt ?? DateTime.now()).toUtc();
      final groupId = DeterministicId.cardPaymentGroup;
      var groupReady = false;
      Future<void> ensureGroup() async {
        if (groupReady) {
          return;
        }
        groupReady = true;
        if (await getCategoryGroupById(groupId) != null) {
          return;
        }
        await into(categoryGroups).insert(
          CategoryGroupsCompanion.insert(
            id: groupId,
            name: attachedDatabase.seedNameOf(CardPayments.groupEnglishName),
            // First, as in YNAB.
            sortOrder: const Value(-1),
            createdAt: Value(AppDatabase.seedTimestamp),
            updatedAt: Value(AppDatabase.seedTimestamp),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }

      var written = 0;
      for (final account in await query.get()) {
        final id = DeterministicId.cardPayment(account.id);
        final existing = await getCategoryById(id);
        final budgetCard =
            account.type == 'credit' &&
            account.onBudget &&
            account.ownerId == null;
        if (existing == null && !budgetCard) {
          continue;
        }
        final hidden = !budgetCard || account.isClosed;
        if (existing == null) {
          await ensureGroup();
          await into(categories).insert(
            CategoriesCompanion.insert(
              id: id,
              name: account.name,
              categoryGroupId: Value(groupId),
              isHidden: Value(hidden),
              sortOrder: const Value(0),
              icon: const Value('credit_card'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrIgnore,
          );
          written++;
        } else if (existing.name != account.name ||
            existing.categoryGroupId != groupId ||
            existing.isHidden != hidden) {
          await ensureGroup();
          await (update(categories)..where((c) => c.id.equals(id))).write(
            CategoriesCompanion(
              name: Value(account.name),
              categoryGroupId: Value(groupId),
              isHidden: Value(hidden),
              updatedAt: Value(now),
            ),
          );
          written++;
        }
      }
      return written;
    });
  }
}
