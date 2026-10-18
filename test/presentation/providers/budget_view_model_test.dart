import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';

import '../../helpers/test_database.dart';

/// Hidden categories stay off the budget screen, except those that still
/// have money: they form a last, collapsed "Hidden categories" section.
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
    await t.addAccount(id: 'a', startingBalance: 100000);
  });

  tearDown(() async {
    container.dispose();
    await t.close();
  });

  Future<void> hide(String name) async {
    final c = (await t.categories.getCategoryById(await t.categoryId(name)))!;
    await t.categories.updateCategory(c.copyWith(isHidden: true));
  }

  Future<List<BudgetGroupViewModel>> viewModel() {
    final sub = container.listen(budgetViewModelProvider, (_, _) {});
    addTearDown(sub.close);
    return container.read(budgetViewModelProvider.future);
  }

  List<String> namesIn(List<BudgetGroupViewModel> groups, bool hidden) => [
    for (final g in groups)
      if (g.isHiddenGroup == hidden)
        for (final c in g.categories) c.category.name,
  ];

  test('hidden categories without money are left out', () async {
    await hide('Water');
    final groups = await viewModel();
    expect(namesIn(groups, false), isNot(contains('Water')));
    expect(groups.any((g) => g.isHiddenGroup), isFalse);
  });

  test(
    'hidden categories with money form the collapsed last section',
    () async {
      final electric = await t.categoryId('Electric');
      await t.budgeting.setCategoryBudgetedAmount(electric, 5000, month);
      await hide('Electric');
      await hide('Water');
      final groups = await viewModel();
      expect(namesIn(groups, false), isNot(contains('Electric')));
      expect(groups.last.isHiddenGroup, isTrue);
      expect(groups.last.group.id, hiddenBudgetGroupId);
      expect(namesIn(groups, true), ['Electric']);
      expect(groups.last.categories.single.budgeted, 5000);
      expect(groups.last.categories.single.available, 5000);
    },
  );

  test('the search filter applies to the hidden section too', () async {
    final electric = await t.categoryId('Electric');
    await t.budgeting.setCategoryBudgetedAmount(electric, 5000, month);
    await hide('Electric');
    container.read(budgetSearchQueryProvider.notifier).state = 'groc';
    final groups = await viewModel();
    expect(groups.any((g) => g.isHiddenGroup), isFalse);
    expect(namesIn(groups, false), ['Groceries']);
  });
}
