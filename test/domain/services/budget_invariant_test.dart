// The budget identity (decision D3) on a real database:
//
//   SUM over categories of available(M) + TBB(M) + budgeted after M
//     == SUM of on-budget account balances counting transactions up to
//        end of M (a starting balance counts once the account exists)
//
// plus targeted regression tests for the ledger-math findings.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../helpers/test_database.dart';
import '../../helpers/l10n_override.dart';
import 'ledger_test_helpers.dart';

void main() {
  late TestDatabase t;
  late TransactionService service;

  final jan = DateTime.utc(2024, 1, 1);
  final feb = DateTime.utc(2024, 2, 1);

  setUp(() {
    t = TestDatabase();
    service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: UndoService(),
      unitOfWork: t.unitOfWork,
      ruleMatchingService: RuleMatchingService(
        t.payees,
        t.transactions,
        t.rules,
      ),
    );
  });

  tearDown(() => t.close());

  /// SUM(available) over all categories at the end of [month].
  Future<int> sumAvailable(DateTime month) async {
    var total = 0;
    for (final category in await t.categories.getAllCategories()) {
      total += await t.budgeting.calculateCategoryAvailable(category.id, month);
    }
    return total;
  }

  Future<void> expectInvariant(DateTime month) async {
    final available = await sumAvailable(month);
    final tbb = await t.budgeting.calculateTBB(month);
    final after = await t.budgets.getTotalBudgetedAfterMonth(
      CalendarDate.monthKey(month),
    );
    expect(
      available + tbb + after,
      await onBudgetBalancesThrough(t, month),
      reason:
          'invariant at ${CalendarDate.monthKey(month)} '
          '(available $available, TBB $tbb, budgeted after $after)',
    );
  }

  test('invariant holds for a full two-month scenario', () async {
    final groceries = await t.categoryId('Groceries');
    final dining = await t.categoryId('Dining Out');
    final fun = await t.categoryId('Fun Money');

    final checking = (await t.addAccount(
      name: 'Checking',
      startingBalance: 100000,
    )).id;
    final savings = (await t.addAccount(name: 'Savings')).id;
    final card = (await t.addAccount(
      name: 'Card',
      type: AccountType.credit,
      startingBalance: -30000,
    )).id;

    Future<String> save(TransactionInput input) async =>
        (await service.save(input)).id;

    // January.
    await save(
      TransactionInput(
        accountId: checking,
        date: DateTime.utc(2024, 1, 2),
        amount: 200000,
        newPayeeName: 'Employer',
      ),
    );
    await save(
      TransactionInput(
        accountId: checking,
        date: DateTime.utc(2024, 1, 5),
        amount: -15000,
        categoryId: groceries,
        cleared: TransactionClearStatus.cleared,
      ),
    );
    await save(
      TransactionInput(
        accountId: card,
        date: DateTime.utc(2024, 1, 6),
        amount: -8000,
        categoryId: dining,
      ),
    );
    await save(
      TransactionInput(
        accountId: checking,
        date: DateTime.utc(2024, 1, 10),
        amount: -50000,
        transferAccountId: savings,
      ),
    );
    // Income split: part to be budgeted, part refunds a category.
    await save(
      TransactionInput(
        accountId: checking,
        date: DateTime.utc(2024, 1, 15),
        amount: 100000,
        splits: [
          const SplitLineInput(amount: 70000),
          SplitLineInput(amount: 30000, categoryId: fun),
        ],
      ),
    );
    // Expense split.
    await save(
      TransactionInput(
        accountId: checking,
        date: DateTime.utc(2024, 1, 20),
        amount: -12000,
        splits: [
          SplitLineInput(amount: -7000, categoryId: groceries),
          SplitLineInput(amount: -5000, categoryId: dining),
        ],
      ),
    );
    // Soft-deleted row: must not count anywhere.
    await t.addTransaction(
      accountId: checking,
      date: DateTime.utc(2024, 1, 21),
      amount: -99900,
      categoryId: groceries,
      isDeleted: true,
    );
    await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
    await t.budgeting.setCategoryBudgetedAmount(dining, 10000, jan);

    // February.
    await save(
      TransactionInput(
        accountId: checking,
        date: DateTime.utc(2024, 2, 3),
        amount: -2000,
      ),
    );
    await save(
      TransactionInput(
        accountId: savings,
        date: DateTime.utc(2024, 2, 4),
        amount: -10000,
        transferAccountId: checking,
      ),
    );
    await save(
      TransactionInput(
        accountId: checking,
        date: DateTime.utc(2024, 2, 5),
        amount: -20000,
        transferAccountId: card,
      ),
    );
    await save(
      TransactionInput(
        accountId: card,
        date: DateTime.utc(2024, 2, 7),
        amount: -4500,
        categoryId: groceries,
      ),
    );
    // Reconciliation adjustment (uncategorised).
    await service.reconcile(
      accountId: checking,
      statementDate: DateTime.utc(2024, 2, 10),
      statementBalance: 80000,
      adjustmentMemo: 'Adjustment',
      clearedBalanceUpTo: (id, day) =>
          t.accounts.getClearedBalance(id, upTo: day),
    );
    await t.budgeting.setCategoryBudgetedAmount(groceries, 15000, feb);
    await t.budgeting.setCategoryBudgetedAmount(fun, 5000, feb);

    await expectInvariant(jan);
    await expectInvariant(feb);

    // Hand-computed TBB for January:
    // starting balances 1000 - 300 = 700; ready-to-assign rows: income
    // 2000 + uncategorised split line 700 = 2700; budgeted 300 in January
    // and 200 in February (assigned ahead, so not available in January).
    expect(
      await t.budgeting.calculateTBB(jan),
      70000 + 270000 - 30000 - 20000,
    );
    // Income for January excludes the split parent and the transfer.
    expect(await t.budgeting.calculateTotalIncomeForMonth(jan), 270000);
    // Spending for January: 150 + 80 + 70 + 50 (split lines, not parent).
    expect(await t.budgeting.calculateTotalSpendingForMonth(jan), -35000);
  });

  group('TBB rule (finding 1)', () {
    test('a transfer between accounts does not change TBB', () async {
      final checking = (await t.addAccount(name: 'Checking')).id;
      final savings = (await t.addAccount(name: 'Savings')).id;
      await t.addTransaction(accountId: checking, amount: 100000, date: jan);
      final before = await t.budgeting.calculateTBB(jan);
      await service.save(
        TransactionInput(
          accountId: checking,
          date: jan,
          amount: -50000,
          transferAccountId: savings,
        ),
      );
      expect(await t.budgeting.calculateTBB(jan), before);
      await expectInvariant(jan);
    });

    test('an uncategorised outflow reduces TBB', () async {
      final checking = (await t.addAccount(name: 'Checking')).id;
      await t.addTransaction(accountId: checking, amount: 100000, date: jan);
      await t.addTransaction(accountId: checking, amount: -2500, date: jan);
      expect(await t.budgeting.calculateTBB(jan), 97500);
      await expectInvariant(jan);
    });

    test(
      'starting balances are budgetable (credit debt reduces TBB)',
      () async {
        await t.addAccount(name: 'Checking', startingBalance: 50000);
        await t.addAccount(
          name: 'Card',
          type: AccountType.credit,
          startingBalance: -20000,
        );
        final thisMonth = CalendarDate.startOfMonthUtc(CalendarDate.today());
        expect(await t.budgeting.calculateTBB(thisMonth), 30000);
        await expectInvariant(thisMonth);
      },
    );

    test('a starting balance counts from the month the account was created '
        'in, or from its first transaction if earlier (B9)', () async {
      final checking = (await t.addAccount(
        name: 'Checking',
        startingBalance: 50000,
      )).id;
      final thisMonth = CalendarDate.startOfMonthUtc(CalendarDate.today());
      final lastMonth = DateTime.utc(thisMonth.year, thisMonth.month - 1, 1);
      // Before the account existed: nothing of it.
      expect(await t.budgeting.calculateTBB(jan), 0);
      expect(await t.budgeting.calculateTBB(lastMonth), 0);
      expect(await t.budgeting.calculateTBB(thisMonth), 50000);
      await expectInvariant(jan);

      // Backdated history moves the start back to that month.
      await t.addTransaction(accountId: checking, amount: -1000, date: feb);
      expect(await t.budgeting.calculateTBB(jan), 0);
      expect(await t.budgeting.calculateTBB(feb), 49000);
      expect(await t.budgeting.calculateTBB(lastMonth), 49000);
      await expectInvariant(jan);
      await expectInvariant(feb);
      await expectInvariant(thisMonth);
    });

    test('a reconciliation adjustment flows into TBB', () async {
      final checking = (await t.addAccount(
        name: 'Checking',
        startingBalance: 10000,
      )).id;
      await service.reconcile(
        accountId: checking,
        statementDate: jan,
        statementBalance: 9000,
        adjustmentMemo: 'Adjustment',
        clearedBalanceUpTo: (id, day) =>
            t.accounts.getClearedBalance(id, upTo: day),
      );
      expect(await t.budgeting.calculateTBB(jan), 9000);
      await expectInvariant(jan);
    });
  });

  group('future months (B1)', () {
    late String groceries;
    late String rent;
    final mar = DateTime.utc(2024, 3, 1);

    setUp(() async {
      groceries = await t.categoryId('Groceries');
      rent = await t.categoryId('Rent/Mortgage');
      final checking = (await t.addAccount(name: 'Checking')).id;
      await t.addTransaction(accountId: checking, amount: 100000, date: jan);
    });

    test('money assigned in the next month leaves this month\'s TBB', () async {
      expect(await t.budgeting.calculateTBB(jan), 100000);
      await t.budgeting.setCategoryBudgetedAmount(rent, 100000, feb);
      expect(await t.budgeting.calculateTBB(jan), 0);
      // The next month is not short: the money was there.
      expect(await t.budgeting.calculateTBB(feb), 0);
      expect(await t.budgeting.calculateTBB(mar), 0);
      await expectInvariant(jan);
      await expectInvariant(feb);
      await expectInvariant(mar);
    });

    test('assigning more than there is shows in every month', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 60000, jan);
      await t.budgeting.setCategoryBudgetedAmount(rent, 60000, feb);
      expect(await t.budgeting.calculateTBB(jan), -20000);
      expect(await t.budgeting.calculateTBB(feb), -20000);
      await expectInvariant(jan);
      await expectInvariant(feb);
    });

    test('income of the next month is only available there', () async {
      final checking = (await t.accounts.getAllAccounts()).single.id;
      await t.addTransaction(accountId: checking, amount: 50000, date: feb);
      await t.budgeting.setCategoryBudgetedAmount(rent, 120000, feb);
      expect(await t.budgeting.calculateTBB(jan), -20000);
      expect(await t.budgeting.calculateTBB(feb), 30000);
      await expectInvariant(jan);
      await expectInvariant(feb);
    });
  });

  group('overspending (B5)', () {
    late String groceries;
    late String dining;
    late String checking;
    final mar = DateTime.utc(2024, 3, 1);

    setUp(() async {
      groceries = await t.categoryId('Groceries');
      dining = await t.categoryId('Dining Out');
      checking = (await t.addAccount(name: 'Checking')).id;
      await t.addTransaction(accountId: checking, amount: 100000, date: jan);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await t.addTransaction(
        accountId: checking,
        amount: -25000,
        categoryId: groceries,
        date: DateTime.utc(2024, 1, 10),
      );
    });

    test('a negative balance is reset next month and charged to TBB', () async {
      expect(
        await t.budgeting.calculateCategoryAvailable(groceries, jan),
        -5000,
      );
      expect(await t.budgeting.calculateTBB(jan), 80000);
      // February: the category starts at zero, TBB pays the 50.
      expect(await t.budgeting.calculateCategoryAvailable(groceries, feb), 0);
      expect(await t.budgeting.calculateTBB(feb), 75000);
      expect(await t.budgeting.calculateTBB(mar), 75000);
      final batch = await t.budgeting.calculateBatchCategoryPerformance(feb);
      expect(batch[groceries], {'activity': 0, 'available': 0});
      await expectInvariant(jan);
      await expectInvariant(feb);
      await expectInvariant(mar);
    });

    test(
      'covering the overspending in the same month costs nothing extra',
      () async {
        await t.budgeting.setCategoryBudgetedAmount(groceries, 25000, jan);
        expect(await t.budgeting.calculateCategoryAvailable(groceries, jan), 0);
        expect(await t.budgeting.calculateTBB(feb), 75000);
        await expectInvariant(feb);
      },
    );

    test(
      'positive balances still roll over; overspending is charged once',
      () async {
        await t.budgeting.setCategoryBudgetedAmount(dining, 10000, jan);
        await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, feb);
        await t.addTransaction(
          accountId: checking,
          amount: -40000,
          categoryId: groceries,
          date: DateTime.utc(2024, 2, 10),
        );
        // Dining: 100 in January rolls into February and March.
        expect(
          await t.budgeting.calculateCategoryAvailable(dining, mar),
          10000,
        );
        // Groceries: -50 in January (charged in February), -100 in February
        // (charged in March), 0 in March.
        expect(
          await t.budgeting.calculateCategoryAvailable(groceries, feb),
          -10000,
        );
        expect(await t.budgeting.calculateCategoryAvailable(groceries, mar), 0);
        // TBB: 1000 - 200 - 100 (Jan) - 300 (Feb) = 400 in Jan;
        // minus 50 overspent in Jan = 350 in Feb; minus 100 = 250 in Mar.
        expect(await t.budgeting.calculateTBB(jan), 40000);
        expect(await t.budgeting.calculateTBB(feb), 35000);
        expect(await t.budgeting.calculateTBB(mar), 25000);
        expect(await t.budgeting.calculateTBB(DateTime.utc(2024, 4)), 25000);
        await expectInvariant(jan);
        await expectInvariant(feb);
        await expectInvariant(mar);
      },
    );
  });

  group('off-budget accounts', () {
    late String checking;
    late String savings;
    late String groceries;

    setUp(() async {
      groceries = await t.categoryId('Groceries');
      checking = (await t.addAccount(
        name: 'Checking',
        startingBalance: 10000,
      )).id;
      savings = (await t.addAccount(
        name: 'Savings',
        type: AccountType.savings,
        startingBalance: 500000,
        onBudget: false,
      )).id;
      // Salary into checking, interest into savings.
      await t.addTransaction(accountId: checking, amount: 300000, date: jan);
      await t.addTransaction(accountId: savings, amount: 1200, date: jan);
    });

    test('their balance and transactions stay out of the budget', () async {
      // A categorised row in a tracking account is not category activity.
      await t.addTransaction(
        accountId: savings,
        amount: -3000,
        date: jan,
        categoryId: groceries,
      );
      expect(await t.budgeting.calculateTBB(jan), 310000);
      expect(await t.budgeting.calculateCategoryActivity(groceries, jan), 0);
      expect(await t.budgeting.calculateTotalIncomeForMonth(jan), 300000);
      expect(await t.budgeting.calculateTotalSpendingForMonth(jan), 0);
      // Net worth still counts the tracking account.
      expect(await t.accounts.getAccountBalance(savings), 498200);
      await expectInvariant(jan);
    });

    test('a transfer to a tracking account leaves the budget', () async {
      await service.save(
        TransactionInput(
          accountId: checking,
          date: jan,
          amount: -50000,
          transferAccountId: savings,
        ),
      );
      expect(await t.budgeting.calculateTBB(jan), 260000);
      // Moving money is neither income nor spending.
      expect(await t.budgeting.calculateTotalIncomeForMonth(jan), 300000);
      expect(await t.budgeting.calculateTotalSpendingForMonth(jan), 0);
      await expectInvariant(jan);
    });

    test('a transfer from a tracking account enters the budget', () async {
      await service.save(
        TransactionInput(
          accountId: savings,
          date: feb,
          amount: -20000,
          transferAccountId: checking,
        ),
      );
      expect(await t.budgeting.calculateTBB(jan), 310000);
      expect(await t.budgeting.calculateTBB(feb), 330000);
      expect(await t.budgeting.calculateTotalIncomeForMonth(feb), 0);
      await expectInvariant(jan);
      await expectInvariant(feb);
    });

    test('a categorised transfer to a tracking account spends the category, '
        'not TBB', () async {
      final stocks = await t.categoryId('Stocks & ETFs');
      await t.budgeting.setCategoryBudgetedAmount(stocks, 50000, jan);
      final id = (await service.save(
        TransactionInput(
          accountId: checking,
          date: jan,
          amount: -50000,
          transferAccountId: savings,
          categoryId: stocks,
        ),
      )).id;
      // The category sits on the on-budget leg only.
      final out = (await t.transactions.getTransactionById(id))!;
      expect(out.categoryId, stocks);
      final inflow = (await t.transactions.getTransactionById(
        out.transferTransactionId!,
      ))!;
      expect(inflow.categoryId, isNull);
      expect(await t.budgeting.calculateTBB(jan), 310000 - 50000);
      expect(await t.budgeting.calculateCategoryAvailable(stocks, jan), 0);
      await expectInvariant(jan);
    });

    test('a categorised transfer from a tracking account funds the category '
        '(the category goes on the inflow leg)', () async {
      final vacation = await t.categoryId('Vacation');
      await service.save(
        TransactionInput(
          accountId: savings,
          date: jan,
          amount: -20000,
          transferAccountId: checking,
          categoryId: vacation,
        ),
      );
      expect(await t.budgeting.calculateTBB(jan), 310000);
      expect(
        await t.budgeting.calculateCategoryAvailable(vacation, jan),
        20000,
      );
      await expectInvariant(jan);
    });

    test('a transfer inside the budget never keeps a category', () async {
      final wallet = (await t.addAccount(name: 'Wallet')).id;
      final id = (await service.save(
        TransactionInput(
          accountId: checking,
          date: jan,
          amount: -5000,
          transferAccountId: wallet,
          categoryId: groceries,
        ),
      )).id;
      expect((await t.transactions.getTransactionById(id))!.categoryId, isNull);
      expect(await t.budgeting.calculateTBB(jan), 310000);
      await expectInvariant(jan);
    });

    test('putting the tracking account back on budget neutralises a '
        'categorised transfer', () async {
      final stocks = await t.categoryId('Stocks & ETFs');
      await service.save(
        TransactionInput(
          accountId: checking,
          date: jan,
          amount: -50000,
          transferAccountId: savings,
          categoryId: stocks,
        ),
      );
      final account = (await t.accounts.getAccountById(savings))!;
      await t.accounts.updateAccount(account.copyWith(onBudget: true));
      expect(await t.budgeting.calculateCategoryActivity(stocks, jan), 0);
      await expectInvariant(jan);
    });

    test(
      'a reserve budgeted once in a savings category stays out of TBB',
      () async {
        final reserve = await t.categoryId('Savings');
        await t.budgeting.setCategoryBudgetedAmount(reserve, 500000 ~/ 2, jan);
        expect(await t.budgeting.calculateTBB(feb), 310000 - 250000);
        expect(
          await t.budgeting.calculateCategoryAvailable(reserve, feb),
          250000,
        );
        await expectInvariant(feb);
      },
    );

    test('switching an account off budget recalculates TBB', () async {
      final wallet = await t.addAccount(name: 'Wallet', startingBalance: 7000);
      // The wallet has history in January, so its balance counts there.
      await t.addTransaction(accountId: wallet.id, amount: 500, date: jan);
      expect(await t.budgeting.calculateTBB(jan), 317500);
      await t.accounts.updateAccount(wallet.copyWith(onBudget: false));
      expect(await t.budgeting.calculateTBB(jan), 310000);
      await expectInvariant(jan);
    });
  });

  group('split parents (finding 2)', () {
    late String checking;
    late String fun;

    setUp(() async {
      checking = (await t.addAccount(name: 'Checking')).id;
      fun = await t.categoryId('Fun Money');
      // Income split of 1000: 600 to be budgeted, 400 into a category.
      await service.save(
        TransactionInput(
          accountId: checking,
          date: DateTime.utc(2024, 1, 15),
          amount: 100000,
          newPayeeName: 'Employer',
          splits: [
            const SplitLineInput(amount: 60000),
            SplitLineInput(amount: 40000, categoryId: fun),
          ],
        ),
      );
    });

    test('never counts towards TBB or income', () async {
      expect(await t.budgeting.calculateTBB(jan), 60000);
      expect(await t.budgeting.calculateTotalIncomeForMonth(jan), 60000);
      expect(await t.budgeting.calculateCategoryActivity(fun, jan), 40000);
      expect(await t.accounts.getAccountBalance(checking), 100000);
      await expectInvariant(jan);
    });
  });

  test('reports do not double count split parents and children', () async {
    final checking = (await t.addAccount(name: 'Checking')).id;
    final fun = await t.categoryId('Fun Money');
    final groceries = await t.categoryId('Groceries');
    await t.addTransaction(
      accountId: checking,
      amount: 200000,
      date: DateTime.utc(2024, 1, 2),
    );
    await service.save(
      TransactionInput(
        accountId: checking,
        date: DateTime.utc(2024, 1, 20),
        amount: -10000,
        newPayeeName: 'Shop',
        splits: [
          SplitLineInput(amount: -6000, categoryId: fun),
          SplitLineInput(amount: -4000, categoryId: groceries),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        englishL10nOverride,
        transactionRepositoryProvider.overrideWithValue(t.transactions),
        payeeRepositoryProvider.overrideWithValue(t.payees),
        categoryRepositoryProvider.overrideWithValue(t.categories),
        accountRepositoryProvider.overrideWithValue(t.accounts),
        budgetRepositoryProvider.overrideWithValue(t.budgets),
      ],
    );
    addTearDown(container.dispose);
    container.read(reportDateRangeProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2024, 1, 1),
      end: DateTime.utc(2024, 1, 31),
    );

    final history = await container.read(incomeVsExpenseHistoryProvider.future);
    final income = history.firstWhere((s) => s.name == 'Income');
    final expenses = history.firstWhere((s) => s.name == 'Expenses');
    expect(income.points.single.value, 200000);
    expect(expenses.points.single.value, 10000);

    final trends = await container.read(spendingTrendsProvider.future);
    expect(trends.values.single, 10000);

    final payees = await container.read(topPayeesProvider.future);
    expect(Map.fromEntries(payees)['Shop'], 10000);

    // Rows of a tracking account are not income or spending.
    final brokerage = (await t.addAccount(
      name: 'Brokerage',
      onBudget: false,
    )).id;
    await t.addTransaction(
      accountId: brokerage,
      amount: 50000,
      date: DateTime.utc(2024, 1, 3),
    );
    await t.addTransaction(
      accountId: brokerage,
      amount: -8000,
      date: DateTime.utc(2024, 1, 4),
      payeeId: (await t.payees.getAllPayees()).first.id,
    );
    container.invalidate(incomeVsExpenseHistoryProvider);
    container.invalidate(spendingTrendsProvider);
    container.invalidate(topPayeesProvider);
    final after = await container.read(incomeVsExpenseHistoryProvider.future);
    expect(
      after.firstWhere((s) => s.name == 'Income').points.single.value,
      200000,
    );
    expect(
      after.firstWhere((s) => s.name == 'Expenses').points.single.value,
      10000,
    );
    expect(
      (await container.read(spendingTrendsProvider.future)).values.single,
      10000,
    );
    expect(
      Map.fromEntries(await container.read(topPayeesProvider.future))['Shop'],
      10000,
    );
  });
}
