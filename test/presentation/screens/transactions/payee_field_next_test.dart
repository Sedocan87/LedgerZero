// The keyboard's "Next" in the payee field (fourth audit, ledger F4): it
// keeps the typed name unless that is an existing payee's name.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';

import 'form_test_harness.dart';

void main() {
  final h = FormHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  Finder payeeField() => find.byKey(const Key('payee_field'));

  Future<void> typeAndNext(WidgetTester tester, String text) async {
    await tester.showKeyboard(payeeField());
    await tester.enterText(payeeField(), text);
    await h.settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await h.settle(tester);
  }

  Future<void> giveShopACategory(WidgetTester tester) =>
      tester.runAsync(() async {
        final shop = (await h.t.payees.getPayeeById('shop'))!;
        await h.t.payees.updatePayee(
          shop.copyWith(autoCategoryId: h.groceries),
        );
      });

  dbTestWidgets('a new name that is part of an existing one is kept', (
    tester,
  ) async {
    await giveShopACategory(tester);
    await h.pump(
      tester,
      const AddEditTransactionScreen(initialAccountId: 'checking'),
    );
    await typeAndNext(tester, 'Corner');
    expect(h.fieldText(tester, 'Payee'), 'Corner');
    expect(h.fieldText(tester, 'Category'), '');

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5');
    await h.save(tester);
    final saved = (await h.liveRows(tester)).single;
    final payee = await tester.runAsync(
      () => h.t.payees.getPayeeById(saved.payeeId!),
    );
    expect(payee!.name, 'Corner');
    expect(saved.categoryId, isNull);
  });

  dbTestWidgets('an existing name, in any case, selects that payee', (
    tester,
  ) async {
    await giveShopACategory(tester);
    await h.pump(
      tester,
      const AddEditTransactionScreen(initialAccountId: 'checking'),
    );
    await typeAndNext(tester, 'corner shop');
    expect(h.fieldText(tester, 'Payee'), 'Corner Shop');
    expect(h.fieldText(tester, 'Category'), 'Groceries');
  });
}
