import 'package:drift/drift.dart' hide isNull;
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

  test('schema version should be 14', () {
    expect(database.schemaVersion, 14);
  });

  group('Database Tables Creation & Defaults', () {
    test(
      'should create accounts table with default values and new columns',
      () async {
        final account = AccountsCompanion(
          id: const Value('acc_1'),
          name: const Value('Checking'),
          type: const Value('checking'),
          createdAt: Value(DateTime.now()),
        );
        await database.into(database.accounts).insert(account);
        final result = await database.select(database.accounts).getSingle();

        expect(result.id, 'acc_1');
        expect(result.currency, 'USD'); // Default
        expect(result.startingBalance, 0.0); // Default
        expect(result.currentBalance, 0.0); // Default
        expect(result.isClosed, false); // Default (0 -> false)
        expect(result.color, isNull);
        expect(result.icon, isNull);
        expect(result.notes, isNull);
      },
    );

    test(
      'should create categories table with default values and new columns',
      () async {
        await database
            .into(database.categoryGroups)
            .insert(
              const CategoryGroupsCompanion(
                id: Value('grp_1'),
                name: Value('Living'),
              ),
            );

        const category = CategoriesCompanion(
          id: Value('cat_1'),
          name: Value('Groceries'),
          categoryGroupId: Value('grp_1'),
        );
        await database.into(database.categories).insert(category);
        final result = await (database.select(
          database.categories,
        )..where((tbl) => tbl.id.equals('cat_1'))).getSingle();

        expect(result.isHidden, false); // Default
        expect(result.goalType, isNull);
        expect(result.targetAmount, isNull);
        expect(result.targetDate, isNull);
      },
    );

    test('should create transactions table with default values', () async {
      await database
          .into(database.accounts)
          .insert(
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
      final result = await database.select(database.transactions).getSingle();

      expect(result.cleared, 0); // Default
      expect(result.approved, true); // Default
    });

    test('should create budgets table with default values', () async {
      await database
          .into(database.categoryGroups)
          .insert(
            const CategoryGroupsCompanion(
              id: Value('grp_1'),
              name: Value('Living'),
            ),
          );
      await database
          .into(database.categories)
          .insert(
            const CategoriesCompanion(
              id: Value('cat_1'),
              name: Value('Groceries'),
              categoryGroupId: Value('grp_1'),
            ),
          );

      const budget = BudgetsCompanion(
        id: Value('bud_1'),
        categoryId: Value('cat_1'),
        month: Value('2023-01'),
      );
      await database.into(database.budgets).insert(budget);
      final result = await database.select(database.budgets).getSingle();

      expect(result.budgeted, 0.0); // Default
      expect(result.activity, 0.0); // Default
      expect(result.available, 0.0); // Default
    });

    test('should create scheduled_transactions with default values', () async {
      const sch = ScheduledTransactionsCompanion(id: Value('sch_1'));
      await database.into(database.scheduledTransactions).insert(sch);
      final result = await database
          .select(database.scheduledTransactions)
          .getSingle();

      expect(result.autoApprove, false); // Default
    });
  });

  group('Database Indexes', () {
    test('should have expected indexes', () async {
      // Query sqlite_master to verify indexes exist
      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
          .get();

      final indexNames = indexes.map((row) => row.read<String>('name')).toSet();

      expect(indexNames, contains('idx_transactions_account'));
      expect(indexNames, contains('idx_transactions_date'));
      expect(indexNames, contains('idx_transactions_category'));
      expect(indexNames, contains('idx_budgets_month'));
      expect(indexNames, contains('idx_sync_log_applied'));
    });
  });
}
