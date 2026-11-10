// Income and the category field of the transaction form (fourth audit, UI
// F1): only an inflow without a category reaches To Be Budgeted, so the
// form must not give an inflow a category by accident and must be able to
// take one away.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/pickers.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_form_controller.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

import 'form_test_harness.dart';

void main() {
  final h = FormHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  Future<int> toBeBudgeted(WidgetTester tester) async => (await tester.runAsync(
    () => h.t.budgeting.calculateTBB(CalendarDate.today()),
  ))!;

  Future<void> enterAmount(WidgetTester tester, String text) => tester
      .enterText(find.widgetWithText(AppTextField, 'Amount'), text);

  dbTestWidgets('income entered with a Settings default category reaches To '
      'Be Budgeted', (tester) async {
    await h.prefs.setString('settings_default_category', h.groceries);
    await h.pump(
      tester,
      const AddEditTransactionScreen(initialAccountId: 'checking'),
    );
    expect(h.fieldText(tester, 'Category'), 'Groceries');

    await tester.tap(find.text('Inflow'));
    await h.settle(tester);
    expect(h.fieldText(tester, 'Category'), 'To Be Budgeted');
    expect(
      find.byKey(const Key('transaction.inflowCategoryHint')),
      findsOneWidget,
    );

    await enterAmount(tester, '3000');
    await h.save(tester);
    final saved = (await h.liveRows(tester)).single;
    expect(saved.amount, 300000);
    expect(saved.categoryId, isNull);
    expect(await toBeBudgeted(tester), 300000);
  });

  dbTestWidgets('a payee\'s remembered category is not applied to an inflow', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final shop = (await h.t.payees.getPayeeById('shop'))!;
      await h.t.payees.updatePayee(shop.copyWith(autoCategoryId: h.groceries));
    });
    await h.pump(
      tester,
      const AddEditTransactionScreen(initialAccountId: 'checking'),
    );
    await tester.tap(find.text('Inflow'));
    await h.settle(tester);
    await tester.enterText(find.byKey(const Key('payee_field')), 'Corner');
    await h.settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Corner Shop'));
    await h.settle(tester);
    expect(h.fieldText(tester, 'Category'), 'To Be Budgeted');

    await enterAmount(tester, '20');
    await h.save(tester);
    expect((await h.liveRows(tester)).single.categoryId, isNull);
    expect(await toBeBudgeted(tester), 2000);
  });

  dbTestWidgets('a refund: a category picked for the inflow is kept', (
    tester,
  ) async {
    await h.pump(
      tester,
      const AddEditTransactionScreen(initialAccountId: 'checking'),
    );
    await tester.tap(find.text('Inflow'));
    await h.settle(tester);
    await tester.tap(find.byKey(const Key('transaction.category')));
    await h.settle(tester);
    // "To Be Budgeted" is the first entry of an inflow's picker.
    expect(find.byKey(pickerToBeBudgetedKey), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Groceries'));
    await h.settle(tester);
    expect(h.fieldText(tester, 'Category'), 'Groceries');

    await enterAmount(tester, '20');
    await h.save(tester);
    expect((await h.liveRows(tester)).single.categoryId, h.groceries);
    expect(await toBeBudgeted(tester), 0);
  });

  dbTestWidgets('an existing categorised inflow can be set back to To Be '
      'Budgeted', (tester) async {
    Future<String> categorisedInflow() async => (await tester.runAsync(
      () => h.service.save(
        TransactionInput(
          accountId: 'checking',
          date: CalendarDate.today(),
          amount: 300000,
          categoryId: h.groceries,
        ),
      ),
    ))!.id;

    // With the clear control.
    final first = await categorisedInflow();
    expect(await toBeBudgeted(tester), 0);
    await h.pump(tester, AddEditTransactionScreen(transactionId: first));
    expect(h.fieldText(tester, 'Category'), 'Groceries');
    await tester.tap(find.byTooltip('Clear'));
    await h.settle(tester);
    expect(h.fieldText(tester, 'Category'), 'To Be Budgeted');
    await h.save(tester);
    expect(await toBeBudgeted(tester), 300000);

    // With the picker's first entry.
    final second = await categorisedInflow();
    await h.pump(tester, AddEditTransactionScreen(transactionId: second));
    await tester.tap(find.byKey(const Key('transaction.category')));
    await h.settle(tester);
    await tester.tap(find.byKey(pickerToBeBudgetedKey));
    await h.settle(tester);
    expect(h.fieldText(tester, 'Category'), 'To Be Budgeted');
    await h.save(tester);
    expect(await toBeBudgeted(tester), 600000);
    expect(
      (await h.liveRows(tester)).map((r) => r.categoryId),
      everyElement(isNull),
    );
  });

  dbTestWidgets('the category of an outflow can be cleared', (tester) async {
    final id = (await tester.runAsync(
      () => h.service.save(
        TransactionInput(
          accountId: 'checking',
          date: CalendarDate.today(),
          amount: -500,
          categoryId: h.groceries,
        ),
      ),
    ))!.id;
    await h.pump(tester, AddEditTransactionScreen(transactionId: id));
    expect(h.fieldText(tester, 'Category'), 'Groceries');
    await tester.tap(find.byTooltip('Clear'));
    await h.settle(tester);
    expect(h.fieldText(tester, 'Category'), '');
    await h.save(tester);
    expect((await h.liveRows(tester)).single.categoryId, isNull);
  });

  dbTestWidgets('Inflow tapped by mistake: back on Outflow the category is '
      'there again', (tester) async {
    await h.prefs.setString('settings_default_category', h.groceries);
    await h.pump(
      tester,
      const AddEditTransactionScreen(initialAccountId: 'checking'),
    );
    await tester.tap(find.text('Inflow'));
    await h.settle(tester);
    await tester.tap(find.text('Outflow'));
    await h.settle(tester);
    expect(h.fieldText(tester, 'Category'), 'Groceries');
  });

  group('TransactionFormController.setFormType', () {
    test('becoming an inflow drops the category; leaving restores it', () {
      final c = TransactionFormController()..categoryId = 'cat';
      c.setFormType(TransactionFormType.income);
      expect(c.categoryId, isNull);
      c.setFormType(TransactionFormType.expense);
      expect(c.categoryId, 'cat');
      c.dispose();
    });

    test('a category picked for the inflow stays when leaving it', () {
      final c = TransactionFormController()..categoryId = 'cat';
      c.setFormType(TransactionFormType.income);
      c.categoryId = 'refund';
      c.setFormType(TransactionFormType.income);
      expect(c.categoryId, 'refund');
      c.setFormType(TransactionFormType.expense);
      expect(c.categoryId, 'refund');
      c.dispose();
    });
  });
}
