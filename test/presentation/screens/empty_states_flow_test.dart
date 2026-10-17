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
import 'package:ledger_zero/presentation/screens/budget/widgets/salary_prompt.dart';
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

  Future<void> createFirstAccount(WidgetTester tester) async {
    await pumpAt(tester, '/accounts/add?first=1');
    await tester.enterText(find.byType(TextFormField).at(0), 'Checking');
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    final save = find.widgetWithText(ElevatedButton, 'Create Account');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  final salaryQuestion = find.byKey(const Key('firstAccount.salaryQuestion'));

  testWidgets('First account: asks for the salary; skipping goes to the '
      'budget and retires the salary card', (tester) async {
    await createFirstAccount(tester);
    expect(salaryQuestion, findsOneWidget);
    expect(find.text('When do you get paid?'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(prefs.getBool(SalaryPrompt.handledKey), isTrue);
    expect(find.byKey(const Key('budget.salaryPrompt')), findsNothing);
    // Still reachable under To Be Budgeted.
    expect(
      find.text('Add your salary to budget it every month'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('First account: "Add salary" opens the income form, then the '
      'budget', (tester) async {
    await createFirstAccount(tester);
    await tester.tap(find.text('Add salary'));
    await tester.pumpAndSettle();
    expect(find.text('Add Salary / Income'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetScreen), findsOneWidget);
    // Not declined: the budget screen may still suggest it.
    expect(prefs.getBool(SalaryPrompt.handledKey), isNull);
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
