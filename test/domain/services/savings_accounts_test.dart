import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';

import '../../helpers/test_database.dart';

/// Savings and investment accounts outside the budget, and releasing money
/// that was budgeted for an account when it leaves the budget.
void main() {
  late TestDatabase t;
  late String savings;
  final october = DateTime.utc(2099, 10, 1);
  final november = DateTime.utc(2099, 11, 1);

  setUp(() async {
    t = TestDatabase();
    savings = await t.categoryId('Savings');
  });

  tearDown(() => t.close());

  Future<int> budgeted(DateTime month) async =>
      (await t.budgets.getBudgetByCategoryAndMonth(
        savings,
        CalendarDate.monthKey(month),
      ))?.budgeted ??
      0;

  group('account types', () {
    test('savings and investment accounts start outside the budget', () {
      expect(AccountType.savings.startsOffBudget, isTrue);
      expect(AccountType.investment.startsOffBudget, isTrue);
      expect(AccountType.checking.startsOffBudget, isFalse);
      expect(AccountType.cash.startsOffBudget, isFalse);
      expect(AccountType.credit.startsOffBudget, isFalse);
    });

    test('an unknown (newer) type reads as checking', () {
      final account = Account.fromJson({
        'id': 'a',
        'name': 'Future',
        'type': 'someNewType',
      });
      expect(account.type, AccountType.checking);
    });
  });

  group('releasing budgeted money', () {
    test('after the account leaves the budget, releasing its money fixes '
        'every month, oldest assignment first', () async {
      final reserve = await t.addAccount(
        name: 'Savings account',
        startingBalance: 1000000,
      );
      await t.budgeting.setCategoryBudgetedAmount(savings, 1000000, october);
      expect(await t.budgeting.calculateTBB(october), 0);

      await t.accounts.updateAccount(reserve.copyWith(onBudget: false));
      expect(await t.budgeting.calculateTBB(october), -1000000);

      final released = await t.budgeting.releaseFromCategory(
        savings,
        1000000,
        november,
      );
      expect(released, 1000000);
      expect(await budgeted(october), 0);
      expect(await t.budgeting.calculateTBB(october), 0);
      expect(await t.budgeting.calculateTBB(november), 0);
    });

    test('a second assignment of the same money stays visible', () async {
      await t.budgeting.setCategoryBudgetedAmount(savings, 1000000, october);
      await t.budgeting.setCategoryBudgetedAmount(savings, 1000000, november);

      await t.budgeting.releaseFromCategory(savings, 1000000, november);
      expect(await budgeted(october), 0);
      expect(await budgeted(november), 1000000);
    });

    test('spending that was covered stays covered', () async {
      final checking = await t.addAccount(startingBalance: 2000000);
      await t.budgeting.setCategoryBudgetedAmount(savings, 1000000, october);
      await t.addTransaction(
        accountId: checking.id,
        amount: -900000,
        categoryId: savings,
        date: DateTime.utc(2099, 10, 20),
      );
      await t.budgeting.setCategoryBudgetedAmount(savings, 900000, november);

      final released = await t.budgeting.releaseFromCategory(
        savings,
        1000000,
        november,
      );
      expect(released, 1000000);
      // October keeps what was spent in it; November gives up the rest.
      expect(await budgeted(october), 900000);
      expect(await budgeted(november), 0);
      expect(await t.budgeting.calculateCategoryAvailable(savings, october), 0);
      expect(
        await t.budgeting.calculateCategoryAvailable(savings, november),
        0,
      );
    });

    test('never more than is available; nothing without budgets', () async {
      final checking = await t.addAccount(startingBalance: 2000000);
      await t.budgeting.setCategoryBudgetedAmount(savings, 1000000, october);
      await t.addTransaction(
        accountId: checking.id,
        amount: -200000,
        categoryId: savings,
        date: DateTime.utc(2099, 11, 5),
      );

      expect(
        await t.budgeting.releaseFromCategory(savings, 2000000, november),
        800000,
      );
      expect(await budgeted(october), 200000);

      final stocks = await t.categoryId('Stocks & ETFs');
      expect(await t.budgeting.releaseFromCategory(stocks, 1000, november), 0);
    });
  });

  test('adding to a budget, and taking it back', () async {
    await t.budgeting.addToCategoryBudget(savings, 34000, november);
    await t.budgeting.addToCategoryBudget(savings, 1000, november);
    expect(await budgeted(november), 35000);
    await t.budgeting.addToCategoryBudget(savings, -35000, november);
    expect(await budgeted(november), 0);
  });
}
