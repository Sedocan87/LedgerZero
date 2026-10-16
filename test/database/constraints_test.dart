import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    // Enable foreign keys for in-memory database
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Foreign Key Constraints', () {
    test('Categories should enforce FK on categoryGroupId', () async {
      // 1. Try to insert a category with a non-existent group ID (Should Fail)
      const invalidCategory = CategoriesCompanion(
        id: Value('cat_invalid'),
        name: Value('Invalid Group Cat'),
        categoryGroupId: Value('non_existent_group'),
      );

      try {
        await database.into(database.categories).insert(invalidCategory);
        fail('Should have thrown an exception due to FK constraint');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }

      // 2. Insert valid group and then category (Should Succeed)
      await database
          .into(database.categoryGroups)
          .insert(
            const CategoryGroupsCompanion(
              id: Value('group_1'),
              name: Value('Valid Group'),
            ),
          );

      const validCategory = CategoriesCompanion(
        id: Value('cat_valid'),
        name: Value('Valid Group Cat'),
        categoryGroupId: Value('group_1'),
      );

      await database.into(database.categories).insert(validCategory);
      // Verify specifically that the inserted category exists
      final result = await (database.select(
        database.categories,
      )..where((tbl) => tbl.id.equals('cat_valid'))).get();
      expect(result.length, 1);
      expect(result.first.id, 'cat_valid');

      // 3. Insert category with null group ID (Should Succeed as it is nullable)
      const nullGroupCategory = CategoriesCompanion(
        id: Value('cat_null_group'),
        name: Value('Null Group Cat'),
        categoryGroupId: Value(null),
      );

      await database.into(database.categories).insert(nullGroupCategory);
    });

    test('Transactions should enforce FK on payeeId', () async {
      // Create a valid account first (required for transaction)
      await database
          .into(database.accounts)
          .insert(
            const AccountsCompanion(
              id: Value('acc_1'),
              name: Value('Checking'),
              type: Value('checking'),
            ),
          );

      // 1. Try to insert transaction with non-existent payee (Should Fail)
      final invalidTransaction = TransactionsCompanion(
        id: const Value('tx_invalid'),
        accountId: const Value('acc_1'),
        date: Value(DateTime.now()),
        amount: const Value(-1000),
        payeeId: const Value('non_existent_payee'),
      );

      try {
        await database.into(database.transactions).insert(invalidTransaction);
        fail('Should have thrown an exception due to FK constraint');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }

      // 2. Insert valid payee and then transaction (Should Succeed)
      await database
          .into(database.payees)
          .insert(
            const PayeesCompanion(id: Value('payee_1'), name: Value('Target')),
          );

      final validTransaction = TransactionsCompanion(
        id: const Value('tx_valid'),
        accountId: const Value('acc_1'),
        date: Value(DateTime.now()),
        amount: const Value(-1000),
        payeeId: const Value('payee_1'),
      );

      await database.into(database.transactions).insert(validTransaction);
      final result = await database.select(database.transactions).get();
      expect(result.where((t) => t.id == 'tx_valid').length, 1);

      // 3. Insert transaction with null payee (Should Succeed)
      final nullPayeeTransaction = TransactionsCompanion(
        id: const Value('tx_null_payee'),
        accountId: const Value('acc_1'),
        date: Value(DateTime.now()),
        amount: const Value(-2000),
        payeeId: const Value(null),
      );

      await database.into(database.transactions).insert(nullPayeeTransaction);
    });

    test('Transactions should enforce FK on categoryId', () async {
      await database
          .into(database.accounts)
          .insert(
            const AccountsCompanion(
              id: Value('acc_1'),
              name: Value('Checking'),
              type: Value('checking'),
            ),
          );

      // Fail invalid category
      try {
        await database
            .into(database.transactions)
            .insert(
              TransactionsCompanion(
                id: const Value('tx_inv_cat'),
                accountId: const Value('acc_1'),
                date: Value(DateTime.now()),
                amount: const Value(-1000),
                categoryId: const Value('non_existent_cat'),
              ),
            );
        fail('Should fail due to invalid categoryId');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }

      // Allow null category
      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion(
              id: const Value('tx_null_cat'),
              accountId: const Value('acc_1'),
              date: Value(DateTime.now()),
              amount: const Value(-1000),
              categoryId: const Value(null),
            ),
          );
    });

    test('Transactions should enforce FK on transferAccountId', () async {
      await database
          .into(database.accounts)
          .insert(
            const AccountsCompanion(
              id: Value('acc_1'),
              name: Value('Checking'),
              type: Value('checking'),
            ),
          );

      // Fail invalid transfer account
      try {
        await database
            .into(database.transactions)
            .insert(
              TransactionsCompanion(
                id: const Value('tx_inv_transfer'),
                accountId: const Value('acc_1'),
                date: Value(DateTime.now()),
                amount: const Value(-1000),
                transferAccountId: const Value('non_existent_acc'),
              ),
            );
        fail('Should fail due to invalid transferAccountId');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }

      // Allow valid transfer account
      await database
          .into(database.accounts)
          .insert(
            const AccountsCompanion(
              id: Value('acc_2'),
              name: Value('Savings'),
              type: Value('savings'),
            ),
          );

      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion(
              id: const Value('tx_valid_transfer'),
              accountId: const Value('acc_1'),
              date: Value(DateTime.now()),
              amount: const Value(-10000),
              transferAccountId: const Value('acc_2'),
            ),
          );
    });

    test('Payees should enforce FK on autoCategoryId', () async {
      // Fail invalid autoCategoryId
      try {
        await database
            .into(database.payees)
            .insert(
              const PayeesCompanion(
                id: Value('pay_inv_cat'),
                name: Value('Payee'),
                autoCategoryId: Value('non_existent_cat'),
              ),
            );
        fail('Should fail due to invalid autoCategoryId');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }

      // Allow valid category
      await database
          .into(database.categoryGroups)
          .insert(
            const CategoryGroupsCompanion(id: Value('grp_1'), name: Value('G')),
          );
      await database
          .into(database.categories)
          .insert(
            const CategoriesCompanion(
              id: Value('cat_1'),
              name: Value('C'),
              categoryGroupId: Value('grp_1'),
            ),
          );

      await database
          .into(database.payees)
          .insert(
            const PayeesCompanion(
              id: Value('pay_valid'),
              name: Value('Payee'),
              autoCategoryId: Value('cat_1'),
            ),
          );
    });

    test('Budgets should enforce FK on categoryId', () async {
      // Fail invalid category
      try {
        await database
            .into(database.budgets)
            .insert(
              const BudgetsCompanion(
                id: Value('bud_inv'),
                categoryId: Value('non_existent_cat'),
                month: Value('2023-01'),
              ),
            );
        fail('Should fail due to invalid categoryId');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }
    });

    test('ScheduledTransactions should enforce FKs', () async {
      // Fail invalid accountId
      try {
        await database
            .into(database.scheduledTransactions)
            .insert(
              const ScheduledTransactionsCompanion(
                id: Value('sch_inv_acc'),
                accountId: Value('non_existent_acc'),
              ),
            );
        fail('Should fail due to invalid accountId');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }

      // Fail invalid payeeId
      try {
        await database
            .into(database.scheduledTransactions)
            .insert(
              const ScheduledTransactionsCompanion(
                id: Value('sch_inv_pay'),
                payeeId: Value('non_existent_payee'),
              ),
            );
        fail('Should fail due to invalid payeeId');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }

      // Fail invalid categoryId
      try {
        await database
            .into(database.scheduledTransactions)
            .insert(
              const ScheduledTransactionsCompanion(
                id: Value('sch_inv_cat'),
                categoryId: Value('non_existent_cat'),
              ),
            );
        fail('Should fail due to invalid categoryId');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }
    });
  });

  group('Unique Constraints', () {
    test('Budgets should enforce UNIQUE(categoryId, month)', () async {
      await database
          .into(database.categoryGroups)
          .insert(
            const CategoryGroupsCompanion(id: Value('grp_1'), name: Value('G')),
          );
      await database
          .into(database.categories)
          .insert(
            const CategoriesCompanion(
              id: Value('cat_1'),
              name: Value('C'),
              categoryGroupId: Value('grp_1'),
            ),
          );

      // Insert first budget
      await database
          .into(database.budgets)
          .insert(
            const BudgetsCompanion(
              id: Value('bud_1'),
              categoryId: Value('cat_1'),
              month: Value('2023-01'),
            ),
          );

      // Try insert duplicate (cat_1, 2023-01)
      try {
        await database
            .into(database.budgets)
            .insert(
              const BudgetsCompanion(
                id: Value('bud_2'), // different ID
                categoryId: Value('cat_1'),
                month: Value('2023-01'),
              ),
            );
        fail('Should fail due to UNIQUE(categoryId, month)');
      } catch (e) {
        expect(e.toString(), contains('UNIQUE constraint failed'));
      }
    });
  });
}
