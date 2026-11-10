// The budget identity (decision D3, with credit cards) on a real database:
//
//   SUM over categories of available(M) (payment categories included)
//     + TBB(M) + held for later months(M) + credit overspending(M)
//     == cash(M) + card income(M)
//
// (see expectLedgerInvariant and docs/BUDGETING_RULES.md, "The budget
// identity"),
// plus targeted regression tests for the ledger-math findings.
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/services/account_service.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
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

  /// The budget identity (see [expectLedgerInvariant]).
  Future<void> expectInvariant(DateTime month) =>
      expectLedgerInvariant(t, month);

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
    // starting balances 1000 (the card's 300 of existing debt is not
    // budgeted money: its payment category shows it as missing);
    // ready-to-assign rows: income 2000 + uncategorised split line 700 =
    // 2700; budgeted 300 in January and 200 in February (assigned ahead, so
    // not available in January).
    expect(
      await t.budgeting.calculateTBB(jan),
      100000 + 270000 - 30000 - 20000,
    );
    // The 80 of dining on the card was funded (dining had 100 budgeted):
    // it moved to the card's payment category.
    final status = await t.budgeting.calculateCardPaymentStatus(card, jan);
    expect(status, const CardPaymentStatus(available: 8000, balance: -38000));
    expect(status!.missing, 30000);
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
      'starting balances are budgetable; existing card debt is not '
      'charged to TBB but shown as missing on the payment category',
      () async {
        await t.addAccount(name: 'Checking', startingBalance: 50000);
        final card = await t.addAccount(
          name: 'Card',
          type: AccountType.credit,
          startingBalance: -20000,
        );
        final thisMonth = CalendarDate.startOfMonthUtc(CalendarDate.today());
        expect(await t.budgeting.calculateTBB(thisMonth), 50000);
        final status = await t.budgeting.calculateCardPaymentStatus(
          card.id,
          thisMonth,
        );
        expect(status!.missing, 20000);
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

    test('income of the next month pays its budgets first; January gives '
        'only the rest', () async {
      final checking = (await t.accounts.getAllAccounts()).single.id;
      await t.addTransaction(accountId: checking, amount: 50000, date: feb);
      await t.budgeting.setCategoryBudgetedAmount(rent, 120000, feb);
      // February's 1,200: 500 from its own income, 700 from January.
      expect(await t.budgeting.calculateHeldForLaterMonths(jan), 70000);
      expect(await t.budgeting.calculateTBB(jan), 30000);
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
      expect(batch[groceries], {
        'activity': 0,
        'available': 0,
        'creditOverspent': 0,
      });
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

  group('credit cards (YNAB payment categories)', () {
    late String checking;
    late String card;
    late String payment;
    late String groceries;
    late String dining;
    final mar = DateTime.utc(2024, 3, 1);

    setUp(() async {
      groceries = await t.categoryId('Groceries');
      dining = await t.categoryId('Dining Out');
      checking = (await t.addAccount(name: 'Checking')).id;
      card = (await t.addAccount(name: 'Visa', type: AccountType.credit)).id;
      payment = CardPayments.categoryId(card);
      // 1,000 of income in January (both accounts exist from January).
      await t.addTransaction(accountId: checking, amount: 100000, date: jan);
      // A purchase and its return, so the card exists from January too.
      await t.addTransaction(
        accountId: card,
        amount: -1,
        categoryId: dining,
        date: jan,
      );
      await t.addTransaction(
        accountId: card,
        amount: 1,
        categoryId: dining,
        date: jan,
      );
    });

    Future<String> spend(
      String account,
      int amount, {
      String? category,
      DateTime? date,
      String? transferTo,
      List<SplitLineInput> splits = const [],
    }) async => (await service.save(
      TransactionInput(
        accountId: account,
        date: date ?? DateTime.utc(2024, 1, 10),
        amount: amount,
        categoryId: category,
        transferAccountId: transferTo,
        splits: splits,
      ),
    )).id;

    Future<int> available(String category, [DateTime? month]) =>
        t.budgeting.calculateCategoryAvailable(category, month ?? jan);

    Future<Map<String, int>> performance(
      String category, [
      DateTime? m,
    ]) async =>
        (await t.budgeting.calculateBatchCategoryPerformance(
          m ?? jan,
        ))[category] ??
        const {};

    Future<CardPaymentStatus> status([DateTime? month]) async =>
        (await t.budgeting.calculateCardPaymentStatus(card, month ?? jan))!;

    Future<void> expectAll(List<DateTime> months) async {
      for (final m in months) {
        await expectInvariant(m);
      }
    }

    // The table the owner agreed to (amounts in cents).
    test('table 1: 50 of groceries on the card, groceries had 200 -> '
        'groceries 150, Visa payment +50', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await spend(card, -5000, category: groceries);
      expect(await available(groceries), 15000);
      expect(await available(payment), 5000);
      expect(await performance(payment), {
        'activity': 5000,
        'available': 5000,
        'creditOverspent': 0,
      });
      expect((await status()).missing, 0);
      expect(await t.budgeting.calculateTBB(jan), 80000);
      await expectAll([jan, feb]);
    });

    test('table 2: paying the card 50 from checking -> Visa payment 0, TBB '
        'unchanged', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await spend(card, -5000, category: groceries);
      final before = await t.budgeting.calculateTBB(jan);
      await spend(
        checking,
        -5000,
        transferTo: card,
        date: DateTime.utc(2024, 1, 20),
      );
      expect(await available(payment), 0);
      expect((await performance(payment))['activity'], 0);
      expect(await t.budgeting.calculateTBB(jan), before);
      expect(await status(), const CardPaymentStatus(available: 0, balance: 0));
      // Payments are not spending.
      expect(await t.budgeting.calculateTotalSpendingForMonth(jan), -5000);
      await expectAll([jan, feb]);
    });

    test('table 3: 50 on the card, groceries had only 20 -> groceries -30 '
        '(credit overspending), Visa +20, the 30 is debt; next month TBB is '
        'not reduced', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 2000, jan);
      await spend(card, -5000, category: groceries);
      expect(await available(groceries), -3000);
      expect(await performance(groceries), {
        'activity': -5000,
        'available': -3000,
        'creditOverspent': 3000,
      });
      expect(await available(payment), 2000);
      final s = await status();
      expect(s.debt, 5000);
      expect(s.missing, 3000);
      expect(await t.budgeting.calculateCreditOverspending(jan), 3000);
      final tbbJan = await t.budgeting.calculateTBB(jan);
      expect(tbbJan, 98000);
      // February: groceries starts at 0, To Be Budgeted is not charged.
      expect(await available(groceries, feb), 0);
      expect(await t.budgeting.calculateTBB(feb), tbbJan);
      expect(await t.budgeting.calculateCreditOverspending(feb), 0);
      expect((await status(feb)).missing, 3000);
      await expectAll([jan, feb, mar]);
    });

    test('table 4: a refund on the card reverses the move', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await spend(card, -5000, category: groceries);
      await spend(
        card,
        5000,
        category: groceries,
        date: DateTime.utc(2024, 1, 12),
      );
      expect(await available(groceries), 20000);
      expect(await available(payment), 0);
      expect((await status()).missing, 0);
      await expectAll([jan, feb]);
    });

    test('table 5: a card added with 1,000 of existing debt -> TBB '
        'unchanged, the payment category shows 1,000 still to cover', () async {
      final thisMonth = CalendarDate.startOfMonthUtc(CalendarDate.today());
      final before = await t.budgeting.calculateTBB(thisMonth);
      final amex = await t.addAccount(
        name: 'Amex',
        type: AccountType.credit,
        startingBalance: -100000,
      );
      expect(await t.budgeting.calculateTBB(thisMonth), before);
      final s = (await t.budgeting.calculateCardPaymentStatus(
        amex.id,
        thisMonth,
      ))!;
      expect(s, const CardPaymentStatus(available: 0, balance: -100000));
      expect(s.missing, 100000);
      // Covering it: assign to the payment category, then pay.
      expect(await t.budgeting.coverCardBalance(amex.id, thisMonth), 100000);
      expect(await t.budgeting.calculateTBB(thisMonth), before - 100000);
      expect(
        (await t.budgeting.calculateCardPaymentStatus(
          amex.id,
          thisMonth,
        ))!.missing,
        0,
      );
      await expectInvariant(thisMonth);
    });

    test('a refund of unfunded spending cancels the debt, not the payment '
        'category', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 2000, jan);
      await spend(card, -5000, category: groceries);
      await spend(
        card,
        2000,
        category: groceries,
        date: DateTime.utc(2024, 1, 12),
      );
      // -30 + 20 = -10, all credit; the payment category keeps its 20.
      expect(await performance(groceries), {
        'activity': -3000,
        'available': -1000,
        'creditOverspent': 1000,
      });
      expect(await available(payment), 2000);
      expect((await status()).missing, 1000);
      await expectAll([jan, feb]);
    });

    test('a refund after the card was paid makes the payment category '
        'negative (YNAB): cash overspending, charged next month', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await spend(card, -5000, category: groceries);
      await spend(
        checking,
        -5000,
        transferTo: card,
        date: DateTime.utc(2024, 1, 11),
      );
      await spend(
        card,
        5000,
        category: groceries,
        date: DateTime.utc(2024, 1, 12),
      );
      expect(await available(groceries), 20000);
      expect(await available(payment), -5000);
      expect((await performance(payment))['creditOverspent'], 0);
      final tbbJan = await t.budgeting.calculateTBB(jan);
      expect(await t.budgeting.calculateTBB(feb), tbbJan - 5000);
      await expectAll([jan, feb]);
    });

    test('cash and credit overspending in one category: only the cash part '
        'is charged next month', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 2000, jan);
      await spend(
        checking,
        -3000,
        category: groceries,
        date: DateTime.utc(2024, 1, 5),
      );
      await spend(
        card,
        -4000,
        category: groceries,
        date: DateTime.utc(2024, 1, 6),
      );
      // 20 - 30 = -10 (cash), then 40 on the card with nothing left: -50,
      // of which 40 credit.
      expect(await performance(groceries), {
        'activity': -7000,
        'available': -5000,
        'creditOverspent': 4000,
      });
      expect(await available(payment), 0);
      final tbbJan = await t.budgeting.calculateTBB(jan);
      expect(await t.budgeting.calculateTBB(feb), tbbJan - 1000);
      expect((await status(feb)).missing, 4000);
      await expectAll([jan, feb, mar]);
    });

    test('money assigned later in the month covers credit overspending: '
        'it moves to the payment category', () async {
      await spend(card, -5000, category: groceries);
      expect(await available(payment), 0);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 5000, jan);
      expect(await available(groceries), 0);
      expect(await available(payment), 5000);
      await expectAll([jan]);
    });

    test('a cash refund into a credit-overspent category covers the card '
        'spending', () async {
      await spend(card, -5000, category: groceries);
      await spend(
        checking,
        3000,
        category: groceries,
        date: DateTime.utc(2024, 1, 12),
      );
      expect(await available(groceries), -2000);
      expect(await available(payment), 3000);
      expect((await performance(groceries))['creditOverspent'], 2000);
      await expectAll([jan, feb]);
    });

    test('card rows of one category are processed in date, created_at, id '
        'order', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 3000, jan);
      // Same day: the cash row was entered first, so it uses the money.
      await spend(
        checking,
        -3000,
        category: groceries,
        date: DateTime.utc(2024, 1, 7),
      );
      await spend(
        card,
        -3000,
        category: groceries,
        date: DateTime.utc(2024, 1, 7),
      );
      expect(await available(payment), 0);
      expect((await performance(groceries))['creditOverspent'], 3000);
      // A card row dated earlier is funded first.
      await spend(
        card,
        -1000,
        category: dining,
        date: DateTime.utc(2024, 1, 2),
      );
      await t.budgeting.setCategoryBudgetedAmount(dining, 1000, jan);
      await spend(
        checking,
        -1000,
        category: dining,
        date: DateTime.utc(2024, 1, 3),
      );
      expect(await available(payment), 1000);
      expect((await performance(dining))['creditOverspent'], 0);
      await expectAll([jan, feb]);
    });

    test('a split on the card with lines in several categories', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await t.budgeting.setCategoryBudgetedAmount(dining, 1000, jan);
      await spend(
        card,
        -8000,
        splits: [
          SplitLineInput(amount: -5000, categoryId: groceries),
          SplitLineInput(amount: -3000, categoryId: dining),
        ],
      );
      expect(await available(groceries), 15000);
      expect(await available(dining), -2000);
      expect((await performance(dining))['creditOverspent'], 2000);
      expect(await available(payment), 6000);
      expect((await status()).missing, 2000);
      await expectAll([jan, feb]);
    });

    test('uncategorised card spending is unfunded debt; an uncategorised card '
        'inflow is income', () async {
      final before = await t.budgeting.calculateTBB(jan);
      await spend(card, -4000);
      expect(await t.budgeting.calculateTBB(jan), before);
      expect((await status()).missing, 4000);
      // A reward credited to the card.
      await spend(card, 500, date: DateTime.utc(2024, 1, 15));
      expect(await t.budgeting.calculateTBB(jan), before + 500);
      expect(await t.budgeting.calculateTotalIncomeForMonth(jan), 100500);
      expect((await status()).missing, 3500);
      await expectAll([jan, feb]);
    });

    test('a cash advance puts the money into the payment category', () async {
      await spend(card, -10000, transferTo: checking);
      expect(await available(payment), 10000);
      expect((await status()).missing, 0);
      expect(await t.budgeting.calculateTBB(jan), 100000);
      await expectAll([jan, feb]);
    });

    test('a balance transfer between two cards moves the funding with the '
        'debt, at most what is there', () async {
      final amex = (await t.addAccount(
        name: 'Amex',
        type: AccountType.credit,
      )).id;
      final amexPayment = CardPayments.categoryId(amex);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 3000, jan);
      await spend(card, -5000, category: groceries);
      // Visa: debt 50, 30 funded. Amex pays off the whole Visa balance.
      await spend(
        amex,
        -5000,
        transferTo: card,
        date: DateTime.utc(2024, 1, 20),
      );
      expect(await available(payment), 0);
      expect(await available(amexPayment), 3000);
      expect(await t.budgeting.calculateTBB(jan), 97000);
      expect(
        (await t.budgeting.calculateCardPaymentStatus(amex, jan))!.missing,
        2000,
      );
      expect((await status()).missing, 0);
      await expectAll([jan, feb]);
    });

    test('transfers between a card and an off-budget account', () async {
      final savings = (await t.addAccount(
        name: 'Savings',
        type: AccountType.savings,
        onBudget: false,
        startingBalance: 500000,
      )).id;
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await spend(card, -5000, category: groceries);
      // Paying the card from savings without a category is money entering
      // the budget through the card: To Be Budgeted grows.
      final before = await t.budgeting.calculateTBB(jan);
      await spend(
        savings,
        -2000,
        transferTo: card,
        date: DateTime.utc(2024, 1, 12),
      );
      expect(await t.budgeting.calculateTBB(jan), before + 2000);
      expect(await available(payment), 5000);
      // With a category it is a refund-like inflow into that category.
      await spend(
        savings,
        -1000,
        transferTo: card,
        category: groceries,
        date: DateTime.utc(2024, 1, 13),
      );
      expect(await available(groceries), 16000);
      expect(await available(payment), 4000);
      // Moving money from the card to savings without a category is
      // unfunded card debt; with one it is card spending of the category.
      await spend(
        card,
        -700,
        transferTo: savings,
        date: DateTime.utc(2024, 1, 14),
      );
      expect(await t.budgeting.calculateTBB(jan), before + 2000);
      await expectAll([jan, feb]);
    });

    test('budgets of later months (Held) with card spending', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 5000, jan);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, feb);
      await t.budgeting.setCategoryBudgetedAmount(payment, 10000, mar);
      await spend(
        card,
        -8000,
        category: groceries,
        date: DateTime.utc(2024, 2, 5),
      );
      await spend(
        card,
        -6000,
        category: groceries,
        date: DateTime.utc(2024, 1, 5),
      );
      expect(await available(payment, feb), 5000 + 8000);
      expect(await t.budgeting.calculateHeldForLaterMonths(jan), 40000);
      await expectAll([jan, feb, mar, DateTime.utc(2024, 4)]);
    });

    test('assigning, moving money and filling work with the payment '
        'category', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await t.budgeting.moveMoney(groceries, payment, 5000, jan);
      expect(await available(payment), 5000);
      await t.budgeting.copyBudgetFromPreviousMonth(feb);
      expect(await t.budgeting.calculateCategoryAvailable(payment, feb), 10000);
      await expectAll([jan, feb]);
    });

    test('closing the card or taking it off budget releases its payment '
        'category to TBB', () async {
      final accountService = AccountService(
        accountRepository: t.accounts,
        maintenance: t.maintenance,
        ruleRepository: t.rules,
        unitOfWork: t.unitOfWork,
        budgeting: t.budgeting,
        categoryRepository: t.categories,
      );
      await t.budgeting.setCategoryBudgetedAmount(payment, 4000, jan);
      final before = await t.budgeting.calculateTBB(jan);
      expect(await accountService.setClosed(card, true, month: jan), 4000);
      expect(await t.budgeting.calculateTBB(jan), before + 4000);
      expect((await t.categories.getCategoryById(payment))!.isHidden, isTrue);
      await expectAll([jan]);
      await accountService.setClosed(card, false, month: jan);
      expect((await t.categories.getCategoryById(payment))!.isHidden, isFalse);

      // Off budget: the card's rows leave the budget, the payment category
      // holds only its budgets, which are released.
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await spend(card, -5000, category: groceries);
      await t.budgeting.setCategoryBudgetedAmount(payment, 3000, jan);
      final account = (await t.accounts.getAccountById(card))!;
      await t.accounts.updateAccount(account.copyWith(onBudget: false));
      expect(await available(payment), 3000);
      expect(await t.budgeting.releasePaymentCategory(card, jan), 3000);
      expect(await available(payment), 0);
      await expectAll([jan, feb]);
    });

    test('deleting the card deletes its payment category', () async {
      final accountService = AccountService(
        accountRepository: t.accounts,
        maintenance: t.maintenance,
        ruleRepository: t.rules,
        unitOfWork: t.unitOfWork,
        budgeting: t.budgeting,
        categoryRepository: t.categories,
      );
      await t.budgeting.setCategoryBudgetedAmount(payment, 4000, jan);
      await accountService.deleteAccount(card);
      expect(await t.categories.getCategoryById(payment), isNull);
      await expectAll([jan]);
    });

    test('payment-category activity and card payments are not spending in '
        'the reports', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, jan);
      await spend(card, -5000, category: groceries);
      await spend(
        checking,
        -5000,
        transferTo: card,
        date: DateTime.utc(2024, 1, 20),
      );
      expect(await t.budgeting.calculateTotalSpendingForMonth(jan), -5000);
      expect(await t.budgeting.calculateCategoryActivity(payment, jan), 0);
    });

    for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
      test(
        'randomised ledger with cards keeps the identity (seed $seed)',
        () async {
          final random = Random(seed);
          final amex = (await t.addAccount(
            name: 'Amex',
            type: AccountType.credit,
            startingBalance: -25000,
          )).id;
          final wallet = (await t.addAccount(name: 'Wallet')).id;
          final savings = (await t.addAccount(
            name: 'Savings',
            onBudget: false,
            startingBalance: 200000,
          )).id;
          await t.addTransaction(accountId: amex, amount: -100, date: jan);
          await t.addTransaction(accountId: wallet, amount: 3000, date: jan);
          final onBudget = [checking, wallet, card, amex];
          final cards = [card, amex];
          final cats = [
            groceries,
            dining,
            await t.categoryId('Fun Money'),
            await t.categoryId('Vacation'),
          ];
          final payments = [payment, CardPayments.categoryId(amex)];
          final months = [jan, feb, mar, DateTime.utc(2024, 4)];
          T pick<T>(List<T> list) => list[random.nextInt(list.length)];
          int amount() => (random.nextInt(200) + 1) * 100;

          for (var i = 0; i < 60; i++) {
            final month = pick(months.take(3).toList());
            final date = DateTime.utc(
              month.year,
              month.month,
              1 + random.nextInt(27),
            );
            switch (random.nextInt(11)) {
              case 0 || 1 || 2:
                await spend(
                  pick(onBudget),
                  -amount(),
                  category: pick(cats),
                  date: date,
                );
              case 3:
                await spend(
                  pick(onBudget),
                  amount(),
                  category: pick(cats),
                  date: date,
                );
              case 4:
                await spend(
                  pick(cards),
                  random.nextBool() ? -amount() : amount(),
                  date: date,
                );
              case 5:
                await spend(
                  pick([checking, wallet]),
                  -amount(),
                  transferTo: pick(cards),
                  date: date,
                );
              case 6:
                final from = pick(cards);
                await spend(
                  from,
                  -amount(),
                  transferTo: from == card ? amex : card,
                  date: date,
                );
              case 7:
                await spend(
                  pick(cards),
                  -amount(),
                  transferTo: checking,
                  date: date,
                );
              case 8:
                await spend(
                  savings,
                  -amount(),
                  transferTo: pick(cards),
                  category: random.nextBool() ? pick(cats) : null,
                  date: date,
                );
              case 9:
                final a = amount();
                final b = amount();
                await spend(
                  pick(cards),
                  -(a + b),
                  splits: [
                    SplitLineInput(amount: -a, categoryId: pick(cats)),
                    SplitLineInput(amount: -b, categoryId: pick(cats)),
                  ],
                  date: date,
                );
              default:
                await t.budgeting.addToCategoryBudget(
                  pick([...cats, ...payments]),
                  amount(),
                  pick(months),
                );
            }
          }
          if (random.nextBool()) {
            await t.budgeting.moveMoney(cats.first, payments.first, 1500, feb);
          }
          await expectAll(months);
          // Deterministic: the same numbers when computed again.
          final first = await t.budgeting.calculateBatchCategoryPerformance(
            feb,
          );
          expect(
            await t.budgeting.calculateBatchCategoryPerformance(feb),
            first,
          );
          // Per category and batch agree.
          for (final c in [...cats, ...payments]) {
            expect(
              await t.budgeting.calculateCategoryAvailable(c, feb),
              first[c]?['available'] ?? 0,
            );
          }
        },
      );
    }
  });
}
