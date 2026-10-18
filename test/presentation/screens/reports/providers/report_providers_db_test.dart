import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';

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

  test('net worth: one point per month from grouped SQL, split children '
      'and deleted rows excluded', () async {
    await t.addAccount(id: 'a1', startingBalance: 10010);
    await t.addAccount(id: 'a2', startingBalance: 5000);
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
}
