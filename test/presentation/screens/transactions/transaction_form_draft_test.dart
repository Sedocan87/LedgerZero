// The draft and unsaved-changes model of the transaction form (fourth
// audit: ledger F2, UI F4, F5 and F7).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

import 'form_test_harness.dart';

const _draftKey = 'draft_transaction_new';

void main() {
  final h = FormHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  Finder amountField() => find.widgetWithText(AppTextField, 'Amount');
  Finder banner() => find.byKey(const Key('transaction.draftRestored'));
  Finder prompt() => find.byKey(const Key('unsavedChanges.dialog'));

  /// Lets the autosave timer of the form fire.
  Future<void> autosave(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await h.settle(tester);
  }

  Future<void> storeDraft(Map<String, Object?> json) =>
      h.prefs.setString(_draftKey, jsonEncode(json));

  group('new transaction', () {
    dbTestWidgets('cancelling asks, and Discard leaves no draft behind', (
      tester,
    ) async {
      await h.pump(
        tester,
        const AddEditTransactionScreen(initialAccountId: 'checking'),
      );
      await tester.enterText(amountField(), '50');
      await autosave(tester);
      expect(h.prefs.getString(_draftKey), isNotNull);

      await tester.tap(find.byTooltip('Cancel'));
      await h.settle(tester);
      expect(prompt(), findsOneWidget);
      await tester.tap(find.byKey(const Key('unsavedChanges.discard')));
      await h.settle(tester);
      expect(find.byKey(const Key('list')), findsOneWidget);
      expect(h.prefs.getString(_draftKey), isNull);

      // The next form is empty: nothing comes back.
      await h.pump(
        tester,
        const AddEditTransactionScreen(initialAccountId: 'savings'),
      );
      expect(banner(), findsNothing);
      expect(h.fieldText(tester, 'Amount'), '');
      expect(h.fieldText(tester, 'Account'), 'Savings');
    });

    dbTestWidgets('an untouched form closes without asking and stores no '
        'draft, also with Settings defaults', (tester) async {
      await h.prefs.setString('settings_default_account', 'savings');
      await h.prefs.setString('settings_default_category', h.groceries);
      await h.pump(tester, const AddEditTransactionScreen());
      expect(h.fieldText(tester, 'Account'), 'Savings');
      await autosave(tester);
      expect(h.prefs.getString(_draftKey), isNull);

      await tester.binding.handlePopRoute();
      await h.settle(tester);
      expect(prompt(), findsNothing);
      expect(find.byKey(const Key('list')), findsOneWidget);
    });

    dbTestWidgets('deleting what was typed removes the stored draft', (
      tester,
    ) async {
      await h.pump(tester, const AddEditTransactionScreen());
      await tester.enterText(amountField(), '50');
      await autosave(tester);
      expect(h.prefs.getString(_draftKey), isNotNull);
      await tester.enterText(amountField(), '');
      await autosave(tester);
      expect(h.prefs.getString(_draftKey), isNull);
    });

    dbTestWidgets('an interrupted draft is restored with a notice; the date '
        'is today and the caller\'s account wins', (tester) async {
      await storeDraft({
        'amount': '50',
        'memo': 'left open',
        'date': '2024-01-05T00:00:00.000Z',
        'accountId': 'checking',
      });
      await h.pump(
        tester,
        const AddEditTransactionScreen(initialAccountId: 'savings'),
      );
      expect(banner(), findsOneWidget);
      expect(h.fieldText(tester, 'Amount'), '50');
      expect(h.fieldText(tester, 'Memo'), 'left open');
      expect(h.fieldText(tester, 'Account'), 'Savings');

      await h.save(tester);
      final saved = (await h.liveRows(tester)).single;
      expect(saved.accountId, 'savings');
      expect(saved.date, CalendarDate.today());
      expect(saved.amount, -5000);
      expect(h.prefs.getString(_draftKey), isNull);
    });

    dbTestWidgets('without an account from the caller the draft\'s account '
        'is used', (tester) async {
      await storeDraft({'amount': '50', 'accountId': 'checking'});
      await h.pump(tester, const AddEditTransactionScreen());
      expect(banner(), findsOneWidget);
      expect(h.fieldText(tester, 'Account'), 'Checking');
    });

    dbTestWidgets('Discard on the notice empties the form and removes the '
        'draft', (tester) async {
      await storeDraft({
        'amount': '50',
        'payeeName': 'Somebody',
        'accountId': 'checking',
        'formType': 1,
      });
      await h.pump(
        tester,
        const AddEditTransactionScreen(initialAccountId: 'savings'),
      );
      expect(h.fieldText(tester, 'Payee'), 'Somebody');

      await tester.tap(find.byKey(const Key('transaction.discardDraft')));
      await h.settle(tester);
      expect(banner(), findsNothing);
      expect(h.fieldText(tester, 'Amount'), '');
      expect(h.fieldText(tester, 'Payee'), '');
      expect(h.fieldText(tester, 'Account'), 'Savings');
      expect(h.prefs.getString(_draftKey), isNull);
      await autosave(tester);
      expect(h.prefs.getString(_draftKey), isNull);
    });

    dbTestWidgets('a draft with no amount, payee, memo or split is not '
        'restored', (tester) async {
      await storeDraft({
        'amount': '',
        'date': '2024-01-05T00:00:00.000Z',
        'accountId': 'checking',
        'categoryId': h.groceries,
      });
      await h.pump(tester, const AddEditTransactionScreen());
      expect(banner(), findsNothing);
      expect(h.fieldText(tester, 'Account'), '');
      expect(h.fieldText(tester, 'Category'), '');
    });
  });

  group('editing', () {
    Future<String> row(WidgetTester tester) async => (await tester.runAsync(
      () => h.service.save(
        TransactionInput(
          accountId: 'checking',
          date: DateTime.utc(2024, 3, 1),
          amount: -500,
          memo: 'before',
        ),
      ),
    ))!.id;

    dbTestWidgets('back with an unsaved edit asks; Cancel stays, Discard '
        'leaves the row as it was', (tester) async {
      final id = await row(tester);
      await h.pump(tester, AddEditTransactionScreen(transactionId: id));
      await tester.enterText(
        find.widgetWithText(AppTextField, 'Memo'),
        'after',
      );
      await h.settle(tester);

      await tester.binding.handlePopRoute();
      await h.settle(tester);
      expect(prompt(), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await h.settle(tester);
      expect(find.byType(AddEditTransactionScreen), findsOneWidget);
      expect(h.fieldText(tester, 'Memo'), 'after');

      await tester.tap(find.byTooltip('Cancel'));
      await h.settle(tester);
      await tester.tap(find.byKey(const Key('unsavedChanges.discard')));
      await h.settle(tester);
      expect(find.byKey(const Key('list')), findsOneWidget);
      expect((await h.liveRows(tester)).single.memo, 'before');
      // Editing never writes the new-transaction draft.
      expect(h.prefs.getString(_draftKey), isNull);
    });

    dbTestWidgets('back without a change leaves at once; so does a change '
        'that was taken back', (tester) async {
      final id = await row(tester);
      await h.pump(tester, AddEditTransactionScreen(transactionId: id));
      await tester.enterText(
        find.widgetWithText(AppTextField, 'Memo'),
        'after',
      );
      await tester.enterText(
        find.widgetWithText(AppTextField, 'Memo'),
        'before',
      );
      await h.settle(tester);
      await tester.binding.handlePopRoute();
      await h.settle(tester);
      expect(prompt(), findsNothing);
      expect(find.byKey(const Key('list')), findsOneWidget);
    });

    dbTestWidgets('saving an edit leaves without asking', (tester) async {
      final id = await row(tester);
      await h.pump(tester, AddEditTransactionScreen(transactionId: id));
      await tester.enterText(
        find.widgetWithText(AppTextField, 'Memo'),
        'after',
      );
      await h.save(tester);
      expect(prompt(), findsNothing);
      expect(find.byKey(const Key('list')), findsOneWidget);
      expect((await h.liveRows(tester)).single.memo, 'after');
    });

    dbTestWidgets('a row that no longer exists shows that, and nothing can '
        'be saved', (tester) async {
      await h.pump(
        tester,
        const AddEditTransactionScreen(transactionId: 'does-not-exist'),
      );
      expect(find.byKey(const Key('transaction.notFound')), findsOneWidget);
      expect(find.widgetWithText(AppTextField, 'Amount'), findsNothing);
      final save = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.check),
      );
      expect(save.onPressed, isNull);
      expect(await h.liveRows(tester), isEmpty);

      // Leaving needs no prompt.
      await tester.tap(find.byTooltip('Cancel'));
      await h.settle(tester);
      expect(find.byKey(const Key('list')), findsOneWidget);
    });
  });
}
