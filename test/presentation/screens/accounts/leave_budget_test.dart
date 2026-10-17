import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

/// Taking a savings account out of the budget offers to release the money
/// budgeted for it, so To Be Budgeted does not go negative.
void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  final month = CalendarDate.startOfMonthUtc(CalendarDate.today());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
  });

  tearDown(() => t.close());

  Future<void> pump(WidgetTester tester, String accountId) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddEditAccountScreen(accountId: accountId),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> leaveBudget(WidgetTester tester) async {
    final toggle = find.byKey(const Key('account.onBudget'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(ElevatedButton, 'Save Changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('offers the savings categories holding the money, then '
      'releases it', (tester) async {
    final account = await tester.runAsync(
      () => t.addAccount(
        name: 'Savings account',
        type: AccountType.savings,
        startingBalance: 1000000,
      ),
    );
    final savings = (await tester.runAsync(() => t.categoryId('Savings')))!;
    await tester.runAsync(
      () => t.budgeting.setCategoryBudgetedAmount(savings, 1000000, month),
    );
    await pump(tester, account!.id);

    await leaveBudget(tester);
    expect(find.text('Change what you budget?'), findsOneWidget);
    expect(
      find.textContaining(r'$10,000.00 in this account leaves your budget'),
      findsOneWidget,
    );
    expect(find.text(r'Release $10,000.00'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text(r'$10,000.00 returned to To Be Budgeted'), findsOneWidget);

    final stored = await tester.runAsync(
      () => t.accounts.getAccountById(account.id),
    );
    expect(stored!.onBudget, isFalse);
    expect(await tester.runAsync(() => t.budgeting.calculateTBB(month)), 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('unticking a category leaves its money budgeted', (tester) async {
    final account = await tester.runAsync(
      () => t.addAccount(
        name: 'Savings account',
        type: AccountType.savings,
        startingBalance: 1000000,
      ),
    );
    final savings = (await tester.runAsync(() => t.categoryId('Savings')))!;
    await tester.runAsync(
      () => t.budgeting.setCategoryBudgetedAmount(savings, 1000000, month),
    );
    await pump(tester, account!.id);

    await leaveBudget(tester);
    await tester.tap(find.byKey(Key('release.$savings')));
    await tester.pumpAndSettle();
    expect(find.text(r'Release $0.00'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final budget = await tester.runAsync(
      () => t.budgets.getBudgetByCategoryAndMonth(
        savings,
        CalendarDate.monthKey(month),
      ),
    );
    expect(budget!.budgeted, 1000000);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
