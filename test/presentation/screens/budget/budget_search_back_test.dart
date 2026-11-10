// Back in search mode leaves the search (and clears the filter) instead of
// leaving the Budget tab.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

void main() {
  testWidgets('back closes the search first; the next back leaves the '
      'screen', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tutorial_completed_budget_screen_intro': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    await t.addAccount(id: 'a', startingBalance: 100000);
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          selectedBudgetMonthProvider.overrideWith(
            (ref) => DateTime.utc(2024, 5),
          ),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BudgetScreen()),
                ),
                child: const Text('open budget'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open budget'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rent');
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Rent/Mortgage'), findsOneWidget);

    // System back: the search closes and the filter is gone.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);

    // Back again leaves the screen.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BudgetScreen), findsNothing);
    expect(find.text('open budget'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
