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
      await database.into(database.categoryGroups).insert(
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
      final result = await database.select(database.categories).get();
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
      await database.into(database.accounts).insert(
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
        amount: const Value(-10.0),
        payeeId: const Value('non_existent_payee'),
      );

      try {
        await database.into(database.transactions).insert(invalidTransaction);
        fail('Should have thrown an exception due to FK constraint');
      } catch (e) {
        expect(e.toString(), contains('FOREIGN KEY constraint failed'));
      }

      // 2. Insert valid payee and then transaction (Should Succeed)
      await database.into(database.payees).insert(
        const PayeesCompanion(
          id: Value('payee_1'),
          name: Value('Target'),
        ),
      );

      final validTransaction = TransactionsCompanion(
        id: const Value('tx_valid'),
        accountId: const Value('acc_1'),
        date: Value(DateTime.now()),
        amount: const Value(-10.0),
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
        amount: const Value(-20.0),
        payeeId: const Value(null),
      );

      await database.into(database.transactions).insert(nullPayeeTransaction);
    });
  });
}
