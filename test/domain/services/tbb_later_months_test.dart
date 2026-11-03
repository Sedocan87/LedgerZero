// To Be Budgeted of a month when later months are budgeted too: a later
// month's budgets are paid first from the money arriving in the later
// months, and only the rest is held back from the earlier month
// (docs/BUDGETING_RULES.md, "Money assigned ahead").
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';

import '../../helpers/test_database.dart';
import 'ledger_test_helpers.dart';

void main() {
  late TestDatabase t;
  late String checking;
  late String rent;
  late String groceries;

  DateTime month(int year, int m) => DateTime.utc(year, m);
  final oct = month(2024, 10);
  final nov = month(2024, 11);
  final dec = month(2024, 12);

  setUp(() async {
    t = TestDatabase();
    rent = await t.categoryId('Rent/Mortgage');
    groceries = await t.categoryId('Groceries');
    checking = (await t.addAccount(name: 'Checking')).id;
  });
  tearDown(() => t.close());

  Future<void> income(int amount, DateTime day) =>
      t.addTransaction(accountId: checking, amount: amount, date: day);

  Future<void> expectTbb(Map<DateTime, int> expected) async {
    for (final MapEntry(key: m, value: tbb) in expected.entries) {
      expect(
        await t.budgeting.calculateTBB(m),
        tbb,
        reason: 'TBB of ${CalendarDate.monthKey(m)}',
      );
      await expectLedgerInvariant(t, m);
    }
  }

  test('each month budgeting its own income: both months show 0', () async {
    final jan = month(2024, 1);
    final feb = month(2024, 2);
    await income(300000, jan);
    await t.budgeting.setCategoryBudgetedAmount(rent, 300000, jan);
    await income(300000, feb);
    await t.budgeting.setCategoryBudgetedAmount(rent, 300000, feb);

    expect(await t.budgeting.calculateHeldForLaterMonths(jan), 0);
    await expectTbb({jan: 0, feb: 0});
  });

  test('budgeting ahead with no income in the later month takes it from '
      'this month, and the later month is not short', () async {
    await income(100000, oct);
    await expectTbb({oct: 100000});
    await t.budgeting.setCategoryBudgetedAmount(rent, 100000, nov);

    expect(await t.budgeting.calculateHeldForLaterMonths(oct), 100000);
    await expectTbb({oct: 0, nov: 0, dec: 0});
  });

  test('a partly funded later month takes only the rest', () async {
    await income(100000, oct);
    await income(40000, nov.add(const Duration(days: 4)));
    await t.budgeting.setCategoryBudgetedAmount(rent, 100000, nov);

    // November's 1,000: 400 from its own income, 600 from October.
    expect(await t.budgeting.calculateHeldForLaterMonths(oct), 60000);
    await expectTbb({oct: 40000, nov: 40000});
  });

  test('money arriving later does not pay an earlier later month', () async {
    await income(100000, oct);
    await t.budgeting.setCategoryBudgetedAmount(rent, 50000, nov);
    await income(200000, dec);
    await t.budgeting.setCategoryBudgetedAmount(rent, 50000, dec);

    // November needs 500 from October; December's income comes too late
    // for it (and covers December's own 500).
    expect(await t.budgeting.calculateHeldForLaterMonths(oct), 50000);
    expect(await t.budgeting.calculateHeldForLaterMonths(nov), 0);
    await expectTbb({oct: 50000, nov: 50000, dec: 200000});
  });

  test('without budgets in later months nothing changes', () async {
    await income(100000, oct);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, oct);
    // Later rows without later budgets: October is not affected.
    await t.addTransaction(accountId: checking, amount: -20000, date: nov);
    await t.addTransaction(accountId: checking, amount: 50000, date: dec);

    expect(await t.budgeting.calculateHeldForLaterMonths(oct), 0);
    await expectTbb({oct: 70000, nov: 50000, dec: 100000});
  });

  test(
    'outflows and overspending of a later month stay in that month',
    () async {
      await income(100000, oct);
      await t.budgeting.setCategoryBudgetedAmount(rent, 100000, oct);
      await income(100000, nov);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 100000, nov);
      // November: 300 spent without a category, groceries overspent by 200.
      await t.addTransaction(
        accountId: checking,
        amount: -30000,
        date: nov.add(const Duration(days: 2)),
      );
      await t.addTransaction(
        accountId: checking,
        amount: -120000,
        categoryId: groceries,
        date: nov.add(const Duration(days: 3)),
      );

      expect(await t.budgeting.calculateHeldForLaterMonths(oct), 0);
      // November pays its 300 and, in December, its 200 overspending.
      await expectTbb({oct: 0, nov: -30000, dec: -50000});

      // Budgeting 100 in December, where no money arrives, holds back only
      // that 100 from October (it has nothing for it either).
      await t.budgeting.setCategoryBudgetedAmount(rent, 10000, dec);
      expect(await t.budgeting.calculateHeldForLaterMonths(oct), 10000);
      await expectTbb({oct: -10000, nov: -40000, dec: -60000});
    },
  );

  test('assigning more than there is still shows in every month', () async {
    await income(100000, oct);
    await t.budgeting.setCategoryBudgetedAmount(rent, 80000, oct);
    await income(50000, nov);
    await t.budgeting.setCategoryBudgetedAmount(rent, 90000, nov);

    // November is 400 short of its income; October has 200 for it.
    await expectTbb({oct: -20000, nov: -20000});
  });

  test('a starting balance of an account that starts in a later month pays '
      'that month\'s budgets', () async {
    final thisMonth = CalendarDate.startOfMonthUtc(CalendarDate.today());
    final lastMonth = DateTime.utc(thisMonth.year, thisMonth.month - 1);
    await income(50000, lastMonth);
    await t.budgeting.setCategoryBudgetedAmount(rent, 50000, lastMonth);
    // Opened this month with 1,000, all of it budgeted this month.
    await t.addAccount(name: 'Savings', startingBalance: 100000);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 100000, thisMonth);

    expect(await t.budgeting.calculateHeldForLaterMonths(lastMonth), 0);
    await expectTbb({lastMonth: 0, thisMonth: 0});
  });

  test('twelve months of normal use: every past month shows 0', () async {
    final dining = await t.categoryId('Dining Out');
    final months = [for (var m = 1; m <= 12; m++) month(2024, m)];
    for (final m in months) {
      await income(300000, m);
      await t.budgeting.setCategoryBudgetedAmount(rent, 150000, m);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 100000, m);
      await t.budgeting.setCategoryBudgetedAmount(dining, 50000, m);
      await t.addTransaction(
        accountId: checking,
        amount: -150000,
        categoryId: rent,
        date: m.add(const Duration(days: 2)),
      );
      await t.addTransaction(
        accountId: checking,
        amount: -90000,
        categoryId: groceries,
        date: m.add(const Duration(days: 10)),
      );
    }
    // Every month's budgets are paid by its own income, so no month holds
    // anything back for the later ones (January used to show -33,000).
    await expectTbb({for (final m in months) m: 0});
    // Groceries keeps 100 a month, dining 500: rolled over all year.
    expect(
      await t.budgeting.calculateCategoryAvailable(groceries, months.last),
      120000,
    );
    expect(
      await t.budgeting.calculateCategoryAvailable(dining, months.last),
      600000,
    );
  });
}
