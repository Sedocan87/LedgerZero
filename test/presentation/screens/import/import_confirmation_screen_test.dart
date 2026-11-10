import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/import/import_confirmation_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

void main() {
  testWidgets('selection is local state: the route objects are not mutated', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    final rows = [
      ImportTransaction(
        date: DateTime.utc(2024, 1, 2),
        amount: -1234,
        payeeName: 'Bakery',
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ImportConfirmationScreen(transactions: rows),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 transaction'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('0 transactions'), findsOneWidget);
    expect(rows.single.isSelected, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('duplicates follow the chosen account; unmatched file '
      'categories are flagged', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    final checking = await t.addAccount(id: 'a-checking', name: 'Checking');
    await t.addAccount(id: 'a-savings', name: 'Savings');
    await t.payees.createPayee(const Payee(id: 'p-bakery', name: 'Bakery'));
    await t.addTransaction(
      accountId: 'a-savings',
      amount: -1234,
      date: DateTime.utc(2024, 1, 2),
      payeeId: 'p-bakery',
    );
    final rows = [
      ImportTransaction(
        date: DateTime.utc(2024, 1, 2),
        amount: -1234,
        payeeName: 'Bakery',
        categoryName: 'Pastries',
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ImportConfirmationScreen(transactions: rows),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(checking.name), findsOneWidget);
    expect(
      find.text('Category “Pastries” not found – unassigned'),
      findsOneWidget,
    );
    expect(find.textContaining('might be a duplicate'), findsNothing);

    await tester.tap(find.byKey(const Key('import_account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Savings').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('might be a duplicate'), findsOneWidget);
    expect(find.text('0 transactions'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import_account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('might be a duplicate'), findsNothing);
    expect(find.text('1 transaction'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  Future<TestDatabase> pumpReview(
    WidgetTester tester,
    List<ImportTransaction> rows, {
    required Future<void> Function(TestDatabase t) seed,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    await seed(t);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ImportConfirmationScreen(transactions: rows),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return t;
  }

  ImportTransaction fileRow(String? account, int amount, String payee) =>
      ImportTransaction(
        date: DateTime.utc(2024, 1, 2),
        amount: amount,
        payeeName: payee,
        accountName: account,
      );

  FilledButton importButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Import'));

  testWidgets('a file naming an unknown account is never put into the first '
      'account: a banner blocks until the user chooses, and "account from '
      'file" imports the matching rows only (F8)', (tester) async {
    final rows = [
      fileRow('Checking', -1000, 'Bakery'),
      fileRow('Old Card', -2000, 'Cinema'),
      fileRow('Checking', -3000, 'Market'),
    ];
    final t = await pumpReview(
      tester,
      rows,
      seed: (t) async {
        // "Alpha" is the first account; the file never names it.
        await t.addAccount(id: 'a-alpha', name: 'Alpha');
        await t.addAccount(id: 'a-checking', name: 'Checking');
      },
    );

    final banner = find.byKey(const Key('import_unknown_accounts'));
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.textContaining('Old Card')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining('leaves out 1 row'),
      ),
      findsOneWidget,
    );
    expect(find.text('Please select an account'), findsOneWidget);
    expect(importButton(tester).onPressed, isNull, reason: 'no account yet');

    await tester.tap(find.byKey(const Key('import_account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account from file (Checking)').last);
    await tester.pumpAndSettle();

    expect(find.text('2 transactions'), findsOneWidget);
    expect(
      find.text('Account “Old Card” not found – not imported'),
      findsOneWidget,
    );
    expect(importButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
    final stored = await t.transactions.getAllTransactions();
    expect(stored.map((s) => s.accountId).toSet(), {'a-checking'});
    expect(stored.map((s) => s.amount).toList()..sort(), [-3000, -1000]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('no account name of the file matches: the user must pick the '
      'account, which then takes every row (F8)', (tester) async {
    final rows = [fileRow('Girokonto 123', -1000, 'Bakery')];
    await pumpReview(
      tester,
      rows,
      seed: (t) async {
        await t.addAccount(id: 'a-alpha', name: 'Alpha');
        await t.addAccount(id: 'a-beta', name: 'Beta');
      },
    );

    expect(find.textContaining('Girokonto 123'), findsOneWidget);
    expect(find.textContaining('Account from file'), findsNothing);
    expect(importButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('import_account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();
    expect(find.text('1 transaction'), findsOneWidget);
    expect(importButton(tester).onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('every account name matches: "account from file" is '
      'preselected and there is no banner', (tester) async {
    final rows = [
      fileRow('Checking', -1000, 'Bakery'),
      fileRow('savings ', 500, 'Interest'),
    ];
    await pumpReview(
      tester,
      rows,
      seed: (t) async {
        await t.addAccount(id: 'a-checking', name: 'Checking');
        await t.addAccount(id: 'a-savings', name: 'Savings');
      },
    );
    expect(find.byKey(const Key('import_unknown_accounts')), findsNothing);
    expect(find.textContaining('Account from file'), findsOneWidget);
    expect(find.text('2 transactions'), findsOneWidget);
    expect(importButton(tester).onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a possible duplicate names the transaction it matches (F2)', (
    tester,
  ) async {
    final rows = [
      ImportTransaction(
        date: DateTime.utc(2024, 1, 3),
        amount: -2345,
        payeeName: 'REWE SAGT DANKE 4711',
      ),
    ];
    await pumpReview(
      tester,
      rows,
      seed: (t) async {
        await t.addAccount(id: 'a-checking', name: 'Checking');
        await t.payees.createPayee(const Payee(id: 'p-rewe', name: 'Rewe'));
        await t.addTransaction(
          accountId: 'a-checking',
          amount: -2345,
          date: DateTime.utc(2024, 1, 2),
          payeeId: 'p-rewe',
        );
      },
    );
    expect(find.textContaining('Possible duplicate: Rewe on'), findsOneWidget);
    expect(find.textContaining('within 4 days'), findsOneWidget);
    expect(find.text('0 transactions'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('"Undo import" in the success dialog takes the import back '
      'and leaves the rows ready to import again (Improvement 6)', (
    tester,
  ) async {
    final rows = [
      ImportTransaction(
        date: DateTime.utc(2024, 1, 2),
        amount: -1234,
        payeeName: 'Bakery',
      ),
      ImportTransaction(
        date: DateTime.utc(2024, 1, 3),
        amount: 250000,
        payeeName: 'Employer',
      ),
    ];
    final t = await pumpReview(
      tester,
      rows,
      seed: (t) => t.addAccount(id: 'a-checking', name: 'Checking'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
    expect(await t.transactions.getAllTransactions(), hasLength(2));
    expect(find.text('Imported 2 transactions'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import_undo')));
    await tester.pumpAndSettle();
    expect(await t.transactions.getAllTransactions(), isEmpty);
    expect(find.text('Import undone: 2 transactions deleted'), findsOneWidget);
    // Still on the review, nothing flagged as a duplicate of itself.
    expect(find.text('2 transactions'), findsOneWidget);
    expect(importButton(tester).onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
