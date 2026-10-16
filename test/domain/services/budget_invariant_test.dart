// The budget identity (decision D3) on a real database:
//
//   SUM over categories of available(M) + TBB(M)
//     == SUM of account balances counting transactions up to end of M
//
// plus targeted regression tests for the ledger-math findings.
import 'package:drift/drift.dart' show Variable;
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

  /// SUM of account balances counting rows dated before the next month.
  Future<int> sumBalancesAt(DateTime month) async {
    final row = await t.db
        .customSelect(
          'SELECT COALESCE((SELECT SUM(starting_balance) FROM accounts), 0) + '
          'COALESCE((SELECT SUM(amount) FROM transactions WHERE is_deleted = 0 '
          'AND parent_transaction_id IS NULL AND date < ?), 0) AS total',
          variables: [Variable.withDateTime(CalendarDate.endOfMonthUtc(month))],
        )
        .getSingle();
    return row.read<int>('total');
  }

  Future<void> expectInvariant(DateTime month) async {
    final available = await sumAvailable(month);
    final tbb = await t.budgeting.calculateTBB(month);
    expect(
      available + tbb,
      await sumBalancesAt(month),
      reason:
          'invariant at ${CalendarDate.monthKey(month)} '
          '(available $available, TBB $tbb)',
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
    // 2000 + uncategorised split line 700 = 2700; budgeted 300.
    expect(await t.budgeting.calculateTBB(jan), 70000 + 270000 - 30000);
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
        expect(await t.budgeting.calculateTBB(jan), 30000);
        await expectInvariant(jan);
      },
    );

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
  });
}
