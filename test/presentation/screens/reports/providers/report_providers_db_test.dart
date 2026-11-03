import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/l10n_override.dart';

void main() {
  late TestDatabase t;
  late ProviderContainer container;

  setUp(() async {
    t = TestDatabase();
    container = ProviderContainer(
      overrides: [
        englishL10nOverride,
        databaseProvider.overrideWithValue(t.db),
        reportCurrencyProvider.overrideWithValue('USD'),
      ],
    );
    container.read(reportDateRangeProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2024, 1, 1),
      end: DateTime.utc(2024, 3, 31),
    );
  });

  tearDown(() async {
    container.dispose();
    await t.close();
  });

  /// Sets the creation time of account [id] (`null`: unknown).
  Future<void> setCreatedAt(String id, DateTime? createdAt) =>
      t.db.customUpdate(
        'UPDATE accounts SET created_at = ? WHERE id = ?',
        variables: [
          createdAt == null
              ? const Variable<DateTime>(null)
              : Variable.withDateTime(createdAt),
          Variable.withString(id),
        ],
      );

  /// Makes [id] the partner's personal account with [sharedBalance], as it
  /// arrives from the partner's phone.
  Future<void> makePartners(String id, int sharedBalance) =>
      t.db.customStatement(
        'UPDATE accounts SET owner_id = ?, on_budget = 0, shared_balance = ? '
        'WHERE id = ?',
        ['partner-member', sharedBalance, id],
      );

  Future<List<(DateTime, int)>> netWorthPoints() async {
    final sub = container.listen(netWorthHistoryProvider, (_, _) {});
    final points = (await container.read(
      netWorthHistoryProvider.future,
    )).single.points;
    sub.close();
    return [for (final x in points) (x.date, x.value)];
  }

  test('net worth: one point per month from grouped SQL, split children '
      'and deleted rows excluded', () async {
    await t.addAccount(id: 'a1', startingBalance: 10010);
    await t.addAccount(id: 'a2', startingBalance: 5000);
    await setCreatedAt('a1', DateTime.utc(2023, 6, 1));
    await setCreatedAt('a2', DateTime.utc(2023, 6, 1));
    await t.addTransaction(
      accountId: 'a1',
      amount: 20,
      date: DateTime.utc(2023, 12, 31),
    );
    await t.addTransaction(
      id: 'p',
      accountId: 'a1',
      amount: -3000,
      date: DateTime.utc(2024, 1, 10),
    );
    for (final (id, amount) in [('c1', -1000), ('c2', -2000)]) {
      await t.addTransaction(
        id: id,
        accountId: 'a1',
        amount: amount,
        date: DateTime.utc(2024, 1, 10),
        parentTransactionId: 'p',
      );
    }
    await t.addTransaction(
      accountId: 'a2',
      amount: 999,
      date: DateTime.utc(2024, 3, 2),
    );
    await t.addTransaction(
      accountId: 'a2',
      amount: -50000,
      date: DateTime.utc(2024, 2, 2),
      isDeleted: true,
    );
    await t.addTransaction(
      accountId: 'a1',
      amount: -999999,
      date: DateTime.utc(2024, 4, 1),
    );

    final sub = container.listen(netWorthHistoryProvider, (_, _) {});
    final points = (await container.read(
      netWorthHistoryProvider.future,
    )).single.points;
    sub.close();

    List<(DateTime, int)> asPairs(List<TimeSeriesPoint> p) => [
      for (final x in p) (x.date, x.value),
    ];
    expect(asPairs(points), [
      (DateTime.utc(2024, 1, 1), 15030),
      (DateTime.utc(2024, 1, 31), 12030),
      (DateTime.utc(2024, 2, 29), 12030),
      (DateTime.utc(2024, 3, 31), 13029),
    ]);
  });

  test(
    'reports refresh after a new transaction (no manual invalidation)',
    () async {
      await t.addAccount(id: 'a1');
      final groceries = await t.categoryId('Groceries');
      await t.addTransaction(
        accountId: 'a1',
        amount: -1000,
        categoryId: groceries,
        date: DateTime.utc(2024, 2, 1),
      );

      final spending = <Map<String, int>>[];
      final net = <int>[];
      container.listen(spendingByCategoryProvider, (_, next) {
        if (next.hasValue && !next.isLoading) {
          spending.add(next.value!);
        }
      }, fireImmediately: true);
      container.listen(netWorthHistoryProvider, (_, next) {
        if (next.hasValue && !next.isLoading) {
          net.add(next.value!.single.points.last.value);
        }
      }, fireImmediately: true);
      await container.read(spendingByCategoryProvider.future);
      await container.read(netWorthHistoryProvider.future);
      expect(spending.last, {'Groceries': 1000});
      expect(net.last, -1000);

      await t.addTransaction(
        accountId: 'a1',
        amount: -500,
        categoryId: groceries,
        date: DateTime.utc(2024, 2, 3),
      );
      // Let the table-update signal fire and the providers recompute.
      for (var i = 0; i < 20 && spending.last['Groceries'] != 1500; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(spending.last, {'Groceries': 1500});
      expect(net.last, -1500);
    },
  );

  test('a net refund is not spending: spending by category and budget vs '
      'actual show the net outflow or nothing', () async {
    await t.addAccount(id: 'a1');
    final groceries = await t.categoryId('Groceries');
    final dining = await t.categoryId('Dining Out');
    // Groceries: refund 80 against 30 spent -> net +50, nothing spent.
    await t.addTransaction(
      accountId: 'a1',
      amount: 8000,
      categoryId: groceries,
      date: DateTime.utc(2024, 2, 1),
    );
    await t.addTransaction(
      accountId: 'a1',
      amount: -3000,
      categoryId: groceries,
      date: DateTime.utc(2024, 2, 2),
    );
    // Dining: 30 spent, 10 refunded -> 20 spent.
    await t.addTransaction(
      accountId: 'a1',
      amount: -3000,
      categoryId: dining,
      date: DateTime.utc(2024, 2, 3),
    );
    await t.addTransaction(
      accountId: 'a1',
      amount: 1000,
      categoryId: dining,
      date: DateTime.utc(2024, 2, 4),
    );
    await t.budgeting.setCategoryBudgetedAmount(
      groceries,
      10000,
      DateTime.utc(2024, 2, 1),
    );

    final spending = await container.read(spendingByCategoryProvider.future);
    expect(spending, {'Dining Out': 2000});

    final items = await container.read(budgetVsActualProvider.future);
    final byName = {for (final i in items) i.categoryName: i};
    expect(byName['Groceries']!.actual, 0);
    expect(byName['Groceries']!.budgeted, 10000);
    expect(byName['Dining Out']!.actual, 2000);
  });
  test('net worth: a starting balance counts from the day the account '
      'exists (creation or first transaction, whichever is earlier)', () async {
    // Created mid-February, no transactions.
    await t.addAccount(id: 'new', startingBalance: 5000);
    await setCreatedAt('new', DateTime.utc(2024, 2, 15, 10));
    // Created later, but with history from January 20.
    await t.addAccount(id: 'imported', startingBalance: 700);
    await setCreatedAt('imported', DateTime.utc(2026, 1, 1));
    await t.addTransaction(
      accountId: 'imported',
      amount: 300,
      date: DateTime.utc(2024, 1, 20),
    );
    // No creation time: always counts.
    await t.addAccount(id: 'old', startingBalance: 40);
    await setCreatedAt('old', null);

    expect(await netWorthPoints(), [
      (DateTime.utc(2024, 1, 1), 40),
      (DateTime.utc(2024, 1, 31), 40 + 700 + 300),
      (DateTime.utc(2024, 2, 29), 40 + 1000 + 5000),
      (DateTime.utc(2024, 3, 31), 40 + 1000 + 5000),
    ]);
  });

  test("net worth: a transfer between a shared account and the partner's "
      'personal account does not move household net worth', () async {
    await t.addAccount(id: 'shared', startingBalance: 100000);
    await setCreatedAt('shared', DateTime.utc(2023, 1, 1));
    await t.addAccount(id: 'theirs', onBudget: false);
    await setCreatedAt('theirs', DateTime.utc(2023, 1, 1));
    // The partner moved 100 into their account in February and 50 back
    // in March; only the shared legs reach this phone. Their phone shares
    // a balance of 250, so before the transfers it held 200.
    await makePartners('theirs', 25000);
    await t.addTransaction(
      accountId: 'shared',
      amount: -10000,
      date: DateTime.utc(2024, 2, 10),
      transferAccountId: 'theirs',
      transferTransactionId: 'not-on-this-phone-1',
    );
    await t.addTransaction(
      accountId: 'shared',
      amount: 5000,
      date: DateTime.utc(2024, 3, 5),
      transferAccountId: 'theirs',
      transferTransactionId: 'not-on-this-phone-2',
    );
    // Real spending still moves it.
    await t.addTransaction(
      accountId: 'shared',
      amount: -1000,
      date: DateTime.utc(2024, 3, 20),
    );

    expect(await netWorthPoints(), [
      (DateTime.utc(2024, 1, 1), 120000),
      (DateTime.utc(2024, 1, 31), 120000),
      (DateTime.utc(2024, 2, 29), 120000),
      (DateTime.utc(2024, 3, 31), 119000),
    ]);
    // The last point is today's household net worth.
    final accounts = await t.accounts.getAllAccounts();
    expect(accounts.fold<int>(0, (sum, a) => sum + a.balance), 119000);
  });

  test('net worth counts the budget currency only and names the currencies '
      'it left out', () async {
    await t.addAccount(id: 'usd', startingBalance: 1000);
    await setCreatedAt('usd', DateTime.utc(2023, 1, 1));
    await t.addAccount(
      id: 'eur',
      currency: 'EUR',
      startingBalance: 900000,
      onBudget: false,
    );
    await setCreatedAt('eur', DateTime.utc(2023, 1, 1));
    await t.addTransaction(
      accountId: 'eur',
      amount: 5000,
      date: DateTime.utc(2024, 2, 1),
    );
    await t.addAccount(
      id: 'chf',
      currency: 'CHF',
      startingBalance: 1,
      onBudget: false,
    );

    final points = await netWorthPoints();
    expect(points.map((p) => p.$2).toSet(), {1000});
    expect(await container.read(netWorthOtherCurrenciesProvider.future), [
      'CHF',
      'EUR',
    ]);
  });

  test('one definition of spent: dashboard, spending by category, trends, '
      'income vs expense and top payees agree for a month with refunds, a '
      'split and transfers', () async {
    final feb = DateTime.utc(2024, 2, 1);
    container.read(reportDateRangeProvider.notifier).state = DateTimeRange(
      start: feb,
      end: DateTime.utc(2024, 2, 29),
    );
    await t.addAccount(id: 'chk', startingBalance: 500000);
    await t.addAccount(id: 'card', type: AccountType.credit);
    await t.addAccount(id: 'brk', onBudget: false);
    final groceries = await t.categoryId('Groceries');
    final dining = await t.categoryId('Dining Out');
    final fun = await t.categoryId('Fun Money');
    final stocks = await t.categoryId('Stocks & ETFs');
    for (final (id, name) in [
      ('market', 'Market'),
      ('pizza', 'Pizzeria'),
      ('kiosk', 'Kiosk'),
      ('store', 'Store'),
      ('shop', 'Shop'),
      ('job', 'Employer'),
    ]) {
      await t.payees.createPayee(Payee(id: id, name: name));
    }
    Future<void> add(
      int amount, {
      String account = 'chk',
      String? category,
      String? payee,
      String? id,
      String? parent,
      String? transferTo,
    }) async {
      await t.addTransaction(
        id: id,
        accountId: account,
        amount: amount,
        date: DateTime.utc(2024, 2, 10),
        categoryId: category,
        payeeId: payee,
        parentTransactionId: parent,
        transferAccountId: transferTo,
      );
    }

    await add(300000, payee: 'job'); // income
    await add(-5000, category: groceries, payee: 'market');
    await add(2000, category: groceries, payee: 'market'); // refund
    await add(-3000, account: 'card', category: dining, payee: 'pizza');
    // A refund with no spending in its category is no spending and does
    // not offset other categories.
    await add(4000, category: fun, payee: 'shop');
    await add(-1000, payee: 'kiosk'); // uncategorised outflow
    // Split: 15 groceries, 10 uncategorised.
    await add(-2500, id: 'split', payee: 'store');
    await add(-1500, parent: 'split', category: groceries, payee: 'store');
    await add(-1000, parent: 'split', payee: 'store');
    // Categorised transfer to an off-budget account: not spending.
    await add(-7000, category: stocks, transferTo: 'brk');
    await add(7000, account: 'brk', transferTo: 'chk');
    // Transfer between on-budget accounts (card payment): not spending.
    await add(-3000, transferTo: 'card');
    await add(3000, account: 'card', transferTo: 'chk');
    // Off-budget account rows are never spending.
    await add(-800, account: 'brk', category: fun, payee: 'shop');

    // Groceries 50 - 20 + 15 = 45, Dining 30, uncategorised 10 + 10.
    const spent = 4500 + 3000 + 2000;

    final dashboard = await container.read(monthlyStatsProvider(feb).future);
    expect(dashboard['spending'], -spent);
    expect(dashboard['income'], 300000);

    final byCategory = await container.read(spendingByCategoryProvider.future);
    expect(byCategory, {
      'Groceries': 4500,
      'Dining Out': 3000,
      'Uncategorized': 2000,
    });
    expect(byCategory.values.fold<int>(0, (a, b) => a + b), spent);

    expect(await container.read(spendingTrendsProvider.future), {feb: spent});

    final history = await container.read(incomeVsExpenseHistoryProvider.future);
    expect(
      history.firstWhere((s) => s.name == 'Expenses').points.single.value,
      spent,
    );
    expect(
      history.firstWhere((s) => s.name == 'Income').points.single.value,
      300000,
    );

    final payees = Map.fromEntries(
      await container.read(topPayeesProvider.future),
    );
    expect(payees, {
      'Market': 3000,
      'Pizzeria': 3000,
      'Store': 2500,
      'Kiosk': 1000,
    });
    expect(payees.values.fold<int>(0, (a, b) => a + b), spent);

    // Budget vs actual counts category activity: the categorised transfer
    // to the brokerage account uses up "Stocks & ETFs".
    final items = await container.read(budgetVsActualProvider.future);
    final actual = {for (final i in items) i.categoryName: i.actual};
    expect(actual, {
      'Groceries': 4500,
      'Dining Out': 3000,
      'Stocks & ETFs': 7000,
    });
  });

  test(
    'budget vs actual compares the same whole months on both sides',
    () async {
      // "Last 3 months"-style range: mid-January to March 10.
      container.read(reportDateRangeProvider.notifier).state = DateTimeRange(
        start: DateTime.utc(2024, 1, 15),
        end: DateTime.utc(2024, 3, 10),
      );
      expect(
        container.read(budgetVsActualMonthsProvider),
        DateTimeRange(
          start: DateTime.utc(2024, 1, 1),
          end: DateTime.utc(2024, 3, 31),
        ),
      );
      await t.addAccount(id: 'a1');
      final groceries = await t.categoryId('Groceries');
      for (final month in [
        DateTime.utc(2023, 12),
        DateTime.utc(2024, 1),
        DateTime.utc(2024, 2),
        DateTime.utc(2024, 3),
        DateTime.utc(2024, 4),
      ]) {
        await t.budgeting.setCategoryBudgetedAmount(groceries, 10000, month);
      }
      for (final (day, amount) in [
        (DateTime.utc(2023, 12, 31), -100000), // before the months
        (DateTime.utc(2024, 1, 2), -1000), // before the range, same month
        (DateTime.utc(2024, 2, 10), -2000),
        (DateTime.utc(2024, 3, 20), -4000), // after the range, same month
        (DateTime.utc(2024, 4, 1), -100000), // after the months
      ]) {
        await t.addTransaction(
          accountId: 'a1',
          amount: amount,
          categoryId: groceries,
          date: day,
        );
      }

      final item = (await container.read(budgetVsActualProvider.future)).single;
      expect(item.budgeted, 30000);
      expect(item.actual, 7000);
    },
  );
}
