import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('schema version should be 1', () {
    expect(database.schemaVersion, 1);
  });

  group('Database Tables Creation', () {
    test('should create accounts table and insert data', () async {
      final account = AccountsCompanion(
        id: const Value('acc_1'),
        name: const Value('Checking'),
        type: const Value('checking'),
        createdAt: Value(DateTime.now()),
      );
      await database.into(database.accounts).insert(account);
      final result = await database.select(database.accounts).get();
      expect(result.length, 1);
      expect(result.first.id, 'acc_1');
    });

    test('should create category_groups table and insert data', () async {
      final group = CategoryGroupsCompanion(
        id: const Value('grp_1'),
        name: const Value('Living'),
      );
      await database.into(database.categoryGroups).insert(group);
      final result = await database.select(database.categoryGroups).get();
      expect(result.length, 1);
      expect(result.first.id, 'grp_1');
    });

    test('should create categories table with foreign key', () async {
      // FK constraint requires group to exist
      await database.into(database.categoryGroups).insert(
        const CategoryGroupsCompanion(
          id: Value('grp_1'),
          name: Value('Living'),
        ),
      );

      final category = CategoriesCompanion(
        id: const Value('cat_1'),
        name: const Value('Groceries'),
        categoryGroupId: const Value('grp_1'),
      );
      await database.into(database.categories).insert(category);
      final result = await database.select(database.categories).get();
      expect(result.length, 1);
      expect(result.first.categoryGroupId, 'grp_1');
    });

    test('should create payees table', () async {
      final payee = PayeesCompanion(
        id: const Value('pay_1'),
        name: const Value('Supermarket'),
      );
      await database.into(database.payees).insert(payee);
      final result = await database.select(database.payees).get();
      expect(result.length, 1);
    });

    test('should create transactions table with FKs', () async {
      // Setup FKs
      await database.into(database.accounts).insert(
        const AccountsCompanion(
          id: Value('acc_1'),
          name: Value('Checking'),
          type: Value('checking'),
        ),
      );

      final tx = TransactionsCompanion(
        id: const Value('tx_1'),
        accountId: const Value('acc_1'),
        date: Value(DateTime.now()),
        amount: const Value(-50.0),
      );
      await database.into(database.transactions).insert(tx);
      final result = await database.select(database.transactions).get();
      expect(result.length, 1);
      expect(result.first.accountId, 'acc_1');
    });

    test('should create budgets table with FKs', () async {
       // Setup FKs
       await database.into(database.categoryGroups).insert(
        const CategoryGroupsCompanion(
          id: Value('grp_1'),
          name: Value('Living'),
        ),
      );
      await database.into(database.categories).insert(
        const CategoriesCompanion(
          id: Value('cat_1'),
          name: Value('Groceries'),
          categoryGroupId: Value('grp_1'),
        ),
      );

      final budget = BudgetsCompanion(
        id: const Value('bud_1'),
        categoryId: const Value('cat_1'),
        month: const Value('2023-01'),
        budgeted: const Value(100.0),
      );
      await database.into(database.budgets).insert(budget);
      final result = await database.select(database.budgets).get();
      expect(result.length, 1);
      expect(result.first.categoryId, 'cat_1');
    });

    test('should create scheduled_transactions table', () async {
       final sch = ScheduledTransactionsCompanion(
        id: const Value('sch_1'),
        autoApprove: const Value(false),
      );
      await database.into(database.scheduledTransactions).insert(sch);
      final result = await database.select(database.scheduledTransactions).get();
      expect(result.length, 1);
    });

    test('should create sync_log table', () async {
      final log = SyncLogCompanion(
        id: const Value('log_1'),
        deltaFilename: const Value('delta_1.json'),
      );
      await database.into(database.syncLog).insert(log);
      final result = await database.select(database.syncLog).get();
      expect(result.length, 1);
      expect(result.first.deltaFilename, 'delta_1.json');
    });
  });
}
