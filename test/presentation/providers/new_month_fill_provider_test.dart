import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/presentation/providers/new_month_fill_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

/// "Fill new months automatically": once per month and phone, only empty
/// months, starting with the month after it was turned on.
void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  late DateTime now;
  late String groceries;
  late String rent;

  final october = DateTime.utc(2099, 10, 1);
  final november = DateTime.utc(2099, 11, 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    now = DateTime(2099, 10, 15);
    groceries = await t.categoryId('Groceries');
    rent = await t.categoryId('Rent/Mortgage');
    // Enough money for October's 1,300 and the same again in November.
    await t.addAccount(id: 'a', startingBalance: 300000);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, october);
    await t.budgeting.setCategoryBudgetedAmount(rent, 100000, october);
  });

  tearDown(() => t.close());

  NewMonthFillController controller() =>
      NewMonthFillController(prefs, () => t.budgeting, clock: () => now);

  Future<int> budgeted(String categoryId, DateTime month) async =>
      (await t.budgets.getBudgetByCategoryAndMonth(
        categoryId,
        CalendarDate.monthKey(month),
      ))?.budgeted ??
      0;

  test('off: nothing is filled', () async {
    now = DateTime(2099, 11, 2);
    await controller().runIfDue();
    expect(await t.budgeting.isMonthEmpty(november), isTrue);
  });

  test('starts with the next month, fills it once and leaves a note', () async {
    final c = controller();
    await c.setSource(AutoFillSource.previousMonth);
    // October is the current month: offered by the card, not filled.
    await c.runIfDue();
    expect(c.state.note, isNull);

    now = DateTime(2099, 11, 2);
    await c.runIfDue();
    expect(await budgeted(groceries, november), 30000);
    expect(await budgeted(rent, november), 100000);
    final row = await t.budgets.getBudgetByCategoryAndMonth(
      groceries,
      CalendarDate.monthKey(november),
    );
    expect(row!.updatedAt, BudgetingService.automaticFillStamp(november));
    expect(c.state.note?.month, november);
    expect(c.state.note?.total, 130000);

    // Once per month: emptied by hand, it stays empty.
    await t.budgeting.resetBudget(november);
    await c.runIfDue();
    expect(await t.budgeting.isMonthEmpty(november), isTrue);

    // The note survives a restart.
    expect(controller().state.note?.total, 130000);
  });

  test('a month that already has budgets is left as it is', () async {
    final c = controller();
    await c.setSource(AutoFillSource.previousMonth);
    await t.budgeting.setCategoryBudgetedAmount(rent, 90000, november);

    now = DateTime(2099, 11, 2);
    await c.runIfDue();
    expect(await budgeted(rent, november), 90000);
    expect(await budgeted(groceries, november), 0);
    expect(c.state.note, isNull);
  });

  test('a template is used; once deleted, the month before', () async {
    await t.budgeting.saveBudgetTemplate('Lean', october);
    final template = (await t.budgeting.getAllTemplates()).single;
    await t.budgeting.setCategoryBudgetedAmount(rent, 120000, october);

    final c = controller();
    await c.setSource(AutoFillSource.template, templateId: template.id);
    now = DateTime(2099, 11, 2);
    await c.runIfDue();
    // The template still has the old rent.
    expect(await budgeted(rent, november), 100000);
    expect(c.state.note?.templateName, 'Lean');

    await t.budgeting.deleteTemplate(template.id);
    final december = DateTime.utc(2099, 12, 1);
    // November's salary, so December is covered.
    await t.addTransaction(accountId: 'a', amount: 300000);
    now = DateTime(2099, 12, 1);
    await c.dismissNote();
    await c.runIfDue();
    // Filled from November instead, and the setting says so from now on.
    expect(await budgeted(rent, december), 100000);
    expect(c.state.note?.templateName, isNull);
    expect(c.state.source, AutoFillSource.previousMonth);
  });

  test('undo takes the fill back and removes the note', () async {
    final c = controller();
    await c.setSource(AutoFillSource.previousMonth);
    now = DateTime(2099, 11, 2);
    await c.runIfDue();

    await c.undoNote();
    expect(await t.budgeting.isMonthEmpty(november), isTrue);
    expect(c.state.note, isNull);
    expect(controller().state.note, isNull);
  });

  test(
    'waits for the money: fills as soon as To Be Budgeted covers it',
    () async {
      // 3,000 - 1,300 (October) - 1,000 rent = 700 left: 600 short of 1,300.
      await t.addTransaction(accountId: 'a', amount: -100000, categoryId: rent);
      final c = controller();
      await c.setSource(AutoFillSource.previousMonth);
      now = DateTime(2099, 11, 2);

      await c.runIfDue();
      expect(await t.budgeting.isMonthEmpty(november), isTrue);
      expect(c.state.note, isNull);
      expect(c.state.waiting?.month, november);
      expect(c.state.waiting?.total, 130000);
      expect(c.state.waiting?.missing, 60000);
      // Not handled yet: tried again at the next run.
      expect(prefs.getString(NewMonthFillController.lastMonthKey), '2099-10');

      // Payday.
      await t.addTransaction(accountId: 'a', amount: 250000);
      await c.runIfDue();
      expect(await budgeted(groceries, november), 30000);
      expect(await budgeted(rent, november), 100000);
      expect(c.state.waiting, isNull);
      expect(c.state.note?.total, 130000);
      expect(prefs.getString(NewMonthFillController.lastMonthKey), '2099-11');
    },
  );

  test('"Fill anyway" fills the waiting month; "Not now" leaves it empty '
      'for the month', () async {
    await t.addTransaction(accountId: 'a', amount: -100000, categoryId: rent);
    final c = controller();
    await c.setSource(AutoFillSource.previousMonth);
    now = DateTime(2099, 11, 2);
    await c.runIfDue();
    expect(c.state.waiting, isNotNull);

    await c.fillAnyway();
    expect(await budgeted(groceries, november), 30000);
    expect(c.state.waiting, isNull);
    expect(c.state.note?.month, november);

    // December, short again: skipped by hand.
    final december = DateTime.utc(2099, 12, 1);
    now = DateTime(2099, 12, 1);
    await c.runIfDue();
    expect(c.state.waiting?.month, december);
    await c.skipMonth();
    expect(c.state.waiting, isNull);
    await t.addTransaction(accountId: 'a', amount: 500000);
    await c.runIfDue();
    expect(await t.budgeting.isMonthEmpty(december), isTrue);
  });

  test('a stale wait is dropped when the month changes', () async {
    await t.addTransaction(accountId: 'a', amount: -100000, categoryId: rent);
    final c = controller();
    await c.setSource(AutoFillSource.previousMonth);
    now = DateTime(2099, 11, 2);
    await c.runIfDue();
    expect(c.state.waiting?.month, november);

    now = DateTime(2099, 12, 1);
    await c.runIfDue();
    // November stays empty, so December has nothing to copy: no wait.
    expect(c.state.waiting, isNull);
  });
}
