// The Budget app bar: the month is the title (chevrons, tap for the month
// picker), and one menu holds the view mode, the categories and the month
// operations next to Search and Settings.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:ledger_zero/presentation/screens/budget/providers/budget_ui_state_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/month_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'tutorial_completed_budget_screen_intro': true,
    });
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    await t.addAccount(id: 'a', startingBalance: 100000);
  });

  tearDown(() => t.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 1600);
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
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: BudgetScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('the month is the title; the chevrons step a month', (
    tester,
  ) async {
    await pump(tester);
    final appBar = find.byType(AppBar);
    expect(
      find.descendant(of: appBar, matching: find.byType(MonthSelector)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: appBar, matching: find.text('May 2024')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('June 2024'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('April 2024'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tapping the month opens the month picker', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('month.pick')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    // Opens on the year list.
    expect(find.byType(YearPicker), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('May 2024'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('three actions: Search, the menu and Settings; the view mode '
      'and Manage Categories are in the menu', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('View Mode'), findsNothing);
    expect(find.byTooltip('Manage Categories'), findsNothing);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byKey(const Key('budget.menu')));
    await tester.pumpAndSettle();
    expect(find.text('Manage Categories'), findsOneWidget);
    expect(find.text('Copy from Previous Month'), findsOneWidget);
    await tester.tap(find.text('Show progress bars'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BudgetScreen)),
    );
    expect(container.read(budgetViewModeProvider), BudgetViewMode.comparison);
    await unmount(tester);
  });
}
