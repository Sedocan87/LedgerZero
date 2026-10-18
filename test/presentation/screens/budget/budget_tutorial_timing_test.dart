import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

/// The budget tutorial starts once the category list has data, so its
/// "categories" step has something to point at.
void main() {
  testWidgets('the tutorial waits for the category list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    final gate = Completer<List<BudgetGroupViewModel>>();
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
          budgetViewModelProvider.overrideWith((ref) => gate.future),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: BudgetScreen(),
        ),
      ),
    );
    // Several frames while the list is still loading: no tutorial yet.
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TutorialOverlay), findsNothing);

    gate.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(TutorialOverlay), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
