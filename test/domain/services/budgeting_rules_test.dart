// Goal targets, auto-assign rules, templates and month bulk operations of
// BudgetingService on a real in-memory database.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';

import '../../helpers/test_database.dart';
import 'ledger_test_helpers.dart';

void main() {
  late TestDatabase t;
  late String groceries;
  late String dining;
  late String acc;
  final jan = DateTime.utc(2024, 1);
  final feb = DateTime.utc(2024, 2);
  final mar = DateTime.utc(2024, 3);
  final apr = DateTime.utc(2024, 4);

  setUp(() async {
    t = TestDatabase();
    groceries = await t.categoryId('Groceries');
    dining = await t.categoryId('Dining Out');
    acc = (await t.addAccount(startingBalance: 1000000)).id;
  });
  tearDown(() => t.close());

  Future<int> budgeted(String category, DateTime month) async =>
      (await t.budgets.getBudgetByCategoryAndMonth(
        category,
        '${month.year}-${month.month.toString().padLeft(2, '0')}',
      ))?.budgeted ??
      0;

  Future<void> goal(GoalType type, int target, {DateTime? date}) async {
    final c = (await t.categories.getCategoryById(groceries))!;
    await t.categories.updateCategory(
      c.copyWith(goalType: type, targetAmount: target, targetDate: date),
    );
  }

  Future<int> target(DateTime month) async => t.budgeting.calculateGoalTarget(
    (await t.categories.getCategoryById(groceries))!,
    month,
  );

  group('goal targets', () {
    test('no goal: nothing to fund', () async {
      expect(await target(feb), 0);
    });

    test('monthly funding asks for the target every month', () async {
      await goal(GoalType.monthlyFunding, 25000);
      expect(await target(feb), 25000);
    });

    test('target balance asks for what is missing', () async {
      await goal(GoalType.targetBalance, 50000);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, jan);
      expect(await target(feb), 20000);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 60000, jan);
      expect(await target(feb), 0);
    });

    test('target by date spreads the rest over the remaining months', () async {
      await goal(
        GoalType.targetBalanceByDate,
        100000,
        date: DateTime.utc(2024, 4, 30),
      );
      await t.budgeting.setCategoryBudgetedAmount(groceries, 10000, jan);
      // Feb, Mar, Apr remain: 900.00 / 3.
      expect(await target(feb), 30000);
      // A past date asks for everything now.
      expect(await target(DateTime.utc(2024, 6)), 90000);
    });
  });

  group('auto-assign', () {
    setUp(() async {
      for (final (month, amount) in [
        (jan, -3000),
        (feb, -6000),
        (mar, -9000),
      ]) {
        await t.addTransaction(
          accountId: acc,
          amount: amount,
          categoryId: groceries,
          date: month.add(const Duration(days: 9)),
        );
      }
      await t.budgeting.setCategoryBudgetedAmount(groceries, 7000, mar);
    });

    Future<int> assign(AutoAssignRule rule) async {
      await t.budgeting.autoAssign(groceries, apr, rule);
      return budgeted(groceries, apr);
    }

    test('underfunded uses the goal target', () async {
      await goal(GoalType.monthlyFunding, 12345);
      expect(await assign(AutoAssignRule.underfunded), 12345);
    });

    test('average spent of the last three months', () async {
      expect(await assign(AutoAssignRule.averageSpent), 6000);
    });

    test('last month spent and last month budgeted', () async {
      expect(await assign(AutoAssignRule.lastMonthSpent), 9000);
      expect(await assign(AutoAssignRule.lastMonthBudgeted), 7000);
      await expectLedgerInvariant(t, apr);
    });
  });

  test('templates, copy from last month and reset', () async {
    await t.budgeting.setCategoryBudgetedAmount(groceries, 40000, jan);
    await t.budgeting.setCategoryBudgetedAmount(dining, 15000, jan);
    await t.budgeting.saveBudgetTemplate('Usual', jan);
    final template = (await t.budgeting.getAllTemplates()).single;
    expect(template.data, {groceries: 40000, dining: 15000});

    await t.budgeting.applyBudgetTemplate(template.id, mar);
    expect(await budgeted(groceries, mar), 40000);
    expect(await budgeted(dining, mar), 15000);

    await t.budgeting.copyBudgetFromPreviousMonth(feb);
    expect(await budgeted(groceries, feb), 40000);

    await t.budgeting.resetBudget(mar);
    expect(await budgeted(groceries, mar), 0);
    expect(await budgeted(dining, mar), 0);
    await expectLedgerInvariant(t, mar);

    await t.budgeting.deleteTemplate(template.id);
    expect(await t.budgeting.getAllTemplates(), isEmpty);
  });

  test(
    'month operations skip hidden categories, like the new-month fill',
    () async {
      final hidden = await t.categoryId('Electric');
      final electric = (await t.categories.getCategoryById(hidden))!;
      await t.budgeting.setCategoryBudgetedAmount(groceries, 40000, jan);
      await t.budgeting.setCategoryBudgetedAmount(hidden, 5000, jan);
      await t.budgeting.setCategoryBudgetedAmount(hidden, 7000, feb);
      await t.categories.updateCategory(electric.copyWith(isHidden: true));

      // Save as template: only visible categories.
      await t.budgeting.saveBudgetTemplate('Usual', jan);
      final template = (await t.budgeting.getAllTemplates()).single;
      expect(template.data, {groceries: 40000});

      // Copy from the month before: the hidden category is not copied.
      final copied = await t.budgeting.copyBudgetFromPreviousMonth(feb);
      expect(copied.after, {groceries: 40000});
      expect(copied.before, {groceries: 0});
      expect(await budgeted(hidden, feb), 7000);

      // Apply a template whose entry is hidden (or gone): skipped, the rest
      // is written.
      await t.budgetTemplates.createTemplate(
        BudgetTemplate(
          id: 'tpl',
          name: 'Old',
          data: {groceries: 1000, hidden: 2000, 'deleted-category': 3000},
        ),
      );
      final applied = await t.budgeting.applyBudgetTemplate('tpl', mar);
      expect(applied.after, {groceries: 1000});
      expect(await budgeted(hidden, mar), 0);

      // Reset: the hidden category keeps its amount.
      final reset = await t.budgeting.resetBudget(feb);
      expect(reset.before, {groceries: 40000});
      expect(reset.after, {groceries: 0});
      expect(await budgeted(hidden, feb), 7000);
      await expectLedgerInvariant(t, feb);
    },
  );

  test('a month operation reports only what it changed', () async {
    await t.budgeting.setCategoryBudgetedAmount(groceries, 40000, jan);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 40000, feb);
    await t.budgeting.setCategoryBudgetedAmount(dining, 15000, jan);
    final copied = await t.budgeting.copyBudgetFromPreviousMonth(feb);
    expect(copied.before, {dining: 0});
    expect(copied.after, {dining: 15000});

    // Undo writes the old amounts back; a category that no longer exists
    // is skipped instead of failing the whole restore.
    final restored = await t.budgeting.setCategoryBudgetedAmounts({
      ...copied.before,
      'deleted-category': 1,
    }, feb);
    expect(restored.after, {dining: 0});
    expect(await budgeted(dining, feb), 0);
  });
}
