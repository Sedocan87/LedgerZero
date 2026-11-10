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

  test('while LedgerZero Pro is locked the automatic fill waits; it runs '
      'once Pro is unlocked', () async {
    var pro = false;
    final c = NewMonthFillController(
      prefs,
      () => t.budgeting,
      clock: () => now,
      allowed: () => pro,
    );
    await c.setSource(AutoFillSource.previousMonth);
    now = DateTime(2099, 11, 2);
    await c.runIfDue();
    expect(await t.budgeting.isMonthEmpty(november), isTrue);
    expect(c.state.note, isNull);

    pro = true;
    await c.runIfDue();
    expect(await budgeted(groceries, november), 30000);
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

  group('the template was deleted and the month is short of money', () {
    late NewMonthFillController c;

    setUp(() async {
      await t.budgeting.saveBudgetTemplate('Lean', october);
      final template = (await t.budgeting.getAllTemplates()).single;
      // 3,000 - 1,300 (October) - 1,000 rent = 700 left: 600 short.
      await t.addTransaction(accountId: 'a', amount: -100000, categoryId: rent);
      c = controller();
      await c.setSource(AutoFillSource.template, templateId: template.id);
      // Deleted behind the setting's back (the paired phone, or a restore).
      await t.budgeting.deleteTemplate(template.id);
      now = DateTime(2099, 11, 2);
      await c.runIfDue();
    });

    test('the month waits, is not marked handled, and the setting falls '
        'back to the month before', () async {
      expect(c.state.source, AutoFillSource.previousMonth);
      expect(c.state.templateId, isNull);
      expect(c.state.waiting?.month, november);
      expect(c.state.waiting?.missing, 60000);
      expect(prefs.getString(NewMonthFillController.lastMonthKey), '2099-10');
      // The fallback is stored.
      expect(controller().state.source, AutoFillSource.previousMonth);
    });

    test('it is filled when the salary arrives', () async {
      await t.addTransaction(accountId: 'a', amount: 250000);
      await c.runIfDue();
      expect(await budgeted(groceries, november), 30000);
      expect(await budgeted(rent, november), 100000);
      expect(c.state.waiting, isNull);
      expect(prefs.getString(NewMonthFillController.lastMonthKey), '2099-11');
    });

    test('"Fill anyway" fills it', () async {
      await c.fillAnyway();
      expect(await budgeted(groceries, november), 30000);
      expect(c.state.waiting, isNull);
      expect(c.state.note?.month, november);
    });
  });

  group('deleting the template the automatic fill uses', () {
    test('switches to the month before without touching the month', () async {
      await t.budgeting.saveBudgetTemplate('Lean', october);
      final template = (await t.budgeting.getAllTemplates()).single;
      final c = controller();
      await c.setSource(AutoFillSource.template, templateId: template.id);
      expect(c.usesTemplate(template.id), isTrue);
      expect(c.usesTemplate('another'), isFalse);

      now = DateTime(2099, 11, 2);
      await t.budgeting.deleteTemplate(template.id);
      await c.templateDeleted(template.id);
      expect(c.state.source, AutoFillSource.previousMonth);
      expect(c.state.templateId, isNull);
      expect(prefs.getString(NewMonthFillController.templateKey), isNull);
      // November is still due.
      expect(prefs.getString(NewMonthFillController.lastMonthKey), '2099-10');
      await c.runIfDue();
      expect(await budgeted(groceries, november), 30000);
    });

    test('another template leaves the setting alone', () async {
      await t.budgeting.saveBudgetTemplate('Lean', october);
      final template = (await t.budgeting.getAllTemplates()).single;
      final c = controller();
      await c.setSource(AutoFillSource.template, templateId: template.id);
      await c.templateDeleted('another');
      expect(c.state.source, AutoFillSource.template);
      expect(c.state.templateId, template.id);
    });

    test('a wait computed from the template is recomputed', () async {
      await t.budgeting.saveBudgetTemplate('Lean', october);
      final template = (await t.budgeting.getAllTemplates()).single;
      await t.addTransaction(accountId: 'a', amount: -100000, categoryId: rent);
      // October is emptied: the month before has nothing to copy.
      await t.budgeting.resetBudget(october);
      final c = controller();
      await c.setSource(AutoFillSource.template, templateId: template.id);
      now = DateTime(2099, 11, 2);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 250000, october);
      await c.runIfDue();
      expect(c.state.waiting?.total, 130000);

      await t.budgeting.deleteTemplate(template.id);
      await c.templateDeleted(template.id);
      // Now waiting for October's 2,500 instead of the template's 1,300.
      expect(c.state.waiting?.total, 250000);
    });
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
