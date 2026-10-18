import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  test('available is exactly zero for 0.30 - 0.10 - 0.20', () async {
    final account = await t.addAccount();
    final groceries = await t.categoryId('Groceries');
    final month = DateTime.utc(2024, 3);

    await t.budgeting.setCategoryBudgetedAmount(groceries, 30, month);
    await t.addTransaction(
      accountId: account.id,
      amount: -10,
      categoryId: groceries,
      date: DateTime.utc(2024, 3, 5),
    );
    await t.addTransaction(
      accountId: account.id,
      amount: -20,
      categoryId: groceries,
      date: DateTime.utc(2024, 3, 6),
    );

    expect(await t.budgeting.calculateCategoryAvailable(groceries, month), 0);
    final batch = await t.budgeting.calculateBatchCategoryPerformance(month);
    expect(batch[groceries], {'activity': -30, 'available': 0});
  });

  test(
    'month boundaries are UTC calendar days (last day in, next out)',
    () async {
      final account = await t.addAccount();
      final groceries = await t.categoryId('Groceries');
      final march = DateTime.utc(2024, 3);

      for (final (day, amount) in [
        (DateTime.utc(2024, 2, 29), -1), // previous month
        (DateTime.utc(2024, 3, 1), -10), // first day
        (DateTime(2024, 3, 31, 23, 30), -100), // picked locally, last day
        (DateTime.utc(2024, 4, 1), -1000), // next month
      ]) {
        await t.addTransaction(
          accountId: account.id,
          amount: amount,
          categoryId: groceries,
          date: day,
        );
      }

      expect(
        await t.budgeting.calculateCategoryActivity(groceries, march),
        -110,
      );
      // February's overspending (-1) is reset at the month boundary and
      // charged to March's To Be Budgeted instead.
      expect(
        await t.budgeting.calculateCategoryAvailable(groceries, march),
        -110,
      );
      expect(await t.budgeting.calculateTBB(march), -1);
    },
  );

  test(
    'last-month and average spent budget net outflows only, never net refunds',
    () async {
      final account = await t.addAccount();
      final groceries = await t.categoryId('Groceries');
      final dining = await t.categoryId('Dining Out');
      final april = DateTime.utc(2024, 4);

      // Groceries: net spending of 25.00 in March.
      await t.addTransaction(
        accountId: account.id,
        amount: -4000,
        categoryId: groceries,
        date: DateTime.utc(2024, 3, 5),
      );
      await t.addTransaction(
        accountId: account.id,
        amount: 1500,
        categoryId: groceries,
        date: DateTime.utc(2024, 3, 9),
      );
      // Dining: a refund larger than the spending in March (net inflow).
      await t.addTransaction(
        accountId: account.id,
        amount: -1000,
        categoryId: dining,
        date: DateTime.utc(2024, 3, 2),
      );
      await t.addTransaction(
        accountId: account.id,
        amount: 3000,
        categoryId: dining,
        date: DateTime.utc(2024, 3, 20),
      );

      expect(await t.budgeting.getLastMonthSpent(groceries, april), 2500);
      expect(await t.budgeting.getLastMonthSpent(dining, april), 0);
      expect(await t.budgeting.getAverageSpent(groceries, 1, april), 2500);
      expect(await t.budgeting.getAverageSpent(dining, 1, april), 0);
    },
  );

  test('TBB uses integer sums', () async {
    final account = await t.addAccount();
    final rent = await t.categoryId('Rent/Mortgage');
    final month = DateTime.utc(2024, 3);
    await t.addTransaction(
      accountId: account.id,
      amount: 10,
      date: DateTime.utc(2024, 3, 2),
    );
    await t.addTransaction(
      accountId: account.id,
      amount: 20,
      date: DateTime.utc(2024, 3, 3),
    );
    await t.budgeting.setCategoryBudgetedAmount(rent, 30, month);
    expect(await t.budgeting.calculateTBB(month), 0);
  });

  group('deterministic ids (D7)', () {
    test('budget rows get the id of budget:<category>:<yyyy-MM>', () async {
      final groceries = await t.categoryId('Groceries');
      final rent = await t.categoryId('Rent/Mortgage');
      final month = DateTime.utc(2024, 3, 17);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 100, month);
      await t.budgeting.moveMoney(groceries, rent, 40, month);
      await t.budgeting.initializeMonthBudgets(DateTime.utc(2024, 4));

      final march = await t.budgets.getBudgetsForMonth('2024-03');
      for (final b in march) {
        expect(b.id, DeterministicId.budgetForKey(b.categoryId!, '2024-03'));
      }
      expect(
        march.firstWhere((b) => b.categoryId == rent).id,
        DeterministicId.budget(rent, month),
      );
      final april = await t.budgets.getBudgetsForMonth('2024-04');
      expect(april, isNotEmpty);
      for (final b in april) {
        expect(b.id, DeterministicId.budgetForKey(b.categoryId!, '2024-04'));
      }
    });

    test('seeded default categories are identical on every device', () async {
      final other = TestDatabase();
      addTearDown(other.close);
      final mine = {
        for (final c in await t.categories.getAllCategories()) c.id: c.name,
      };
      final theirs = {
        for (final c in await other.categories.getAllCategories()) c.id: c.name,
      };
      expect(mine, theirs);
      final groups = await t.categories.getAllCategoryGroups();
      expect(
        groups.map((g) => g.id),
        containsAll([DeterministicId.defaultGroup('Immediate Obligations')]),
      );
      expect(
        mine.keys,
        contains(
          DeterministicId.defaultCategory('Immediate Obligations', 'Groceries'),
        ),
      );
    });
  });

  test(
    'moveMoney is atomic: a failing target leaves the source unchanged',
    () async {
      final groceries = await t.categoryId('Groceries');
      final month = DateTime.utc(2024, 3);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 100, month);
      await expectLater(
        t.budgeting.moveMoney(groceries, 'missing-category', 40, month),
        throwsA(anything),
      );
      final budget = await t.budgets.getBudgetByCategoryAndMonth(
        groceries,
        '2024-03',
      );
      expect(budget!.budgeted, 100);
      expect(await t.budgeting.calculateTBB(month), -100);
    },
  );
}
