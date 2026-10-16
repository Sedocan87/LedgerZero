import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';

import '../../helpers/test_database.dart';

/// TBB and the budget rows follow the database: no screen invalidates them.
void main() {
  late TestDatabase t;
  late ProviderContainer container;
  final month = CalendarDate.startOfMonthUtc(CalendarDate.today());

  setUp(() async {
    t = TestDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(t.db)],
    );
    container.read(selectedBudgetMonthProvider.notifier).state = month;
    await t.addAccount(id: 'a', startingBalance: 10000);
  });

  tearDown(() async {
    container.dispose();
    await t.close();
  });

  Future<void> settle(bool Function() done) async {
    for (var i = 0; i < 50 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('TBB and category available update after a budget change', () async {
    int? tbb;
    int? available;
    final groceries = await t.categoryId('Groceries');
    container.listen(tbbProvider(month), (_, next) {
      if (!next.isLoading && next.hasValue) {
        tbb = next.value;
      }
    }, fireImmediately: true);
    container.listen(budgetViewModelProvider, (_, next) {
      if (!next.isLoading && next.hasValue) {
        available = next.value!
            .expand((g) => g.categories)
            .firstWhere((c) => c.category.id == groceries)
            .available;
      }
    }, fireImmediately: true);
    await settle(() => tbb != null && available != null);
    expect(tbb, 10000);
    expect(available, 0);

    await t.budgeting.setCategoryBudgetedAmount(groceries, 2500, month);
    await settle(() => tbb == 7500 && available == 2500);
    expect(tbb, 7500);
    expect(available, 2500);

    await t.addTransaction(
      accountId: 'a',
      amount: -1000,
      categoryId: groceries,
      date: month,
    );
    await settle(() => available == 1500);
    expect(available, 1500);
    expect(tbb, 7500);
  });
}
