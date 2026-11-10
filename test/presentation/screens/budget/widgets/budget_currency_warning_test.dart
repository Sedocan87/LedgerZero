// Accounts in the budget that disagree on the currency: the budget screen
// warns, names the currencies and offers to relabel the odd accounts or
// take them out of the budget.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_currency_warning.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'settings_currency': 'EUR'});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
  });

  tearDown(() => t.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: BudgetCurrencyWarning()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> mixedBudget(WidgetTester tester) => tester.runAsync(() async {
    await t.addAccount(id: 'giro', name: 'Giro', currency: 'EUR');
    await t.addAccount(
      id: 'travel',
      name: 'Travel card',
      currency: 'USD',
      startingBalance: 5000,
    );
    await t.addAccount(id: 'brokerage', currency: 'GBP', onBudget: false);
  });

  Finder warning() => find.byKey(const Key('budget.currencyWarning'));

  testWidgets('not shown while the budget has one currency', (tester) async {
    await tester.runAsync(() async {
      await t.addAccount(currency: 'EUR');
      await t.addAccount(currency: 'USD', onBudget: false);
    });
    await pump(tester);
    expect(warning(), findsNothing);
    await unmount(tester);
  });

  testWidgets('names the currencies and relabels the odd accounts after '
      'the confirmation', (tester) async {
    await mixedBudget(tester);
    await pump(tester);

    expect(warning(), findsOneWidget);
    expect(find.textContaining('different currencies (EUR, USD)'), findsOne);
    expect(find.textContaining('Travel card (USD)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('budget.currencyWarning.relabel')));
    await tester.pumpAndSettle();
    expect(find.text('Change the budget currency to EUR?'), findsOneWidget);
    expect(
      find.textContaining('Amounts are NOT converted: 100 USD becomes 100 EUR'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('budgetCurrency.confirm.change')));
    await tester.pumpAndSettle();

    final accounts = (await tester.runAsync(t.accounts.getAllAccounts))!;
    expect(
      {for (final a in accounts) a.id: a.currency},
      {'giro': 'EUR', 'travel': 'EUR', 'brokerage': 'GBP'},
    );
    expect(accounts.singleWhere((a) => a.id == 'travel').startingBalance, 5000);
    expect(warning(), findsNothing);
    await unmount(tester);
  });

  testWidgets('takes an odd account out of the budget through the '
      'leave-budget dialog', (tester) async {
    await mixedBudget(tester);
    await pump(tester);

    await tester.tap(find.byKey(const Key('budget.currencyWarning.leave')));
    await tester.pumpAndSettle();
    expect(find.text('Change what you budget?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final travel = (await tester.runAsync(
      () => t.accounts.getAccountById('travel'),
    ))!;
    expect(travel.onBudget, isFalse);
    expect(travel.currency, 'USD');
    expect(warning(), findsNothing);
    await unmount(tester);
  });
}
