import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/transactions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

/// Empty, first-run states: each screen offers the next step instead of a
/// bare message.
void main() {
  late TestDatabase t;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      // Skip the first-run tutorials.
      'tutorial_completed_budget_screen_intro': true,
    });
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
  });

  tearDown(() => t.close());

  Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => AddEditAccountScreen(
                firstAccount: state.uri.queryParameters['first'] == '1',
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/budget',
          builder: (context, state) => const BudgetScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsScreen(),
        ),
        GoRoute(
          path: '/add-transaction',
          builder: (context, state) => const Text('add-transaction-screen'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Accounts: empty list offers creating the first account', (
    tester,
  ) async {
    await pumpAt(tester, '/accounts');
    expect(find.text('No accounts yet'), findsOneWidget);
    await tester.tap(find.text('Create Account').last);
    await tester.pumpAndSettle();
    // The first-account form explains why an account comes first.
    expect(find.byKey(const Key('firstAccount.explanation')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Budget: without accounts it points to creating one', (
    tester,
  ) async {
    await pumpAt(tester, '/budget');
    expect(find.byKey(const Key('budget.noAccounts')), findsOneWidget);

    await tester.runAsync(() => t.addAccount(id: 'a', startingBalance: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('budget.noAccounts')), findsNothing);
    await unmount(tester);
  });

  testWidgets('Transactions: empty list offers adding one; an empty search '
      'offers clearing it', (tester) async {
    await t.addAccount(id: 'a');
    await pumpAt(tester, '/transactions');
    expect(find.text('No transactions'), findsOneWidget);
    expect(find.text('Add Transaction'), findsWidgets);

    await t.addTransaction(accountId: 'a', amount: -100);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz-nothing');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No matching transactions'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('No matching transactions'), findsNothing);
    await unmount(tester);
  });
}
