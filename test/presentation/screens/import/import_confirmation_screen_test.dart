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
}
