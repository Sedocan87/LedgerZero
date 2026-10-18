import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

/// The month menu: copy from the month before and apply a template ask
/// before overwriting a month that is not empty, and all three operations
/// (reset included) can be undone from the snack bar.
void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  late String groceries;
  late String dining;
  final month = DateTime.utc(2024, 5);
  final previous = DateTime.utc(2024, 4);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'tutorial_completed_budget_screen_intro': true,
    });
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    groceries = await t.categoryId('Groceries');
    dining = await t.categoryId('Dining Out');
    await t.addAccount(id: 'a', startingBalance: 500000);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, previous);
    await t.budgeting.setCategoryBudgetedAmount(dining, 10000, previous);
  });

  tearDown(() => t.close());

  Future<int> budgeted(String id, DateTime m) async =>
      (await t.budgets.getBudgetByCategoryAndMonth(
        id,
        CalendarDate.monthKey(m),
      ))?.budgeted ??
      0;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          selectedBudgetMonthProvider.overrideWith((ref) => month),
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

  Future<void> openMenuItem(WidgetTester tester, String label) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('copy from the month before: no question for an empty month, '
      'Undo takes it back', (tester) async {
    await pump(tester);
    await openMenuItem(tester, 'Copy from Previous Month');
    expect(find.text('Replace budgeted amounts?'), findsNothing);
    expect(find.text('Copied from April'), findsOneWidget);
    expect(await tester.runAsync(() => budgeted(groceries, month)), 30000);
    expect(await tester.runAsync(() => budgeted(dining, month)), 10000);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => budgeted(groceries, month)), 0);
    expect(await tester.runAsync(() => budgeted(dining, month)), 0);
    await unmount(tester);
  });

  testWidgets('copy onto a month with budgets asks first and keeps the '
      'other categories', (tester) async {
    final rent = await t.categoryId('Rent/Mortgage');
    await t.budgeting.setCategoryBudgetedAmount(rent, 90000, month);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 1000, month);
    await pump(tester);
    await openMenuItem(tester, 'Copy from Previous Month');

    expect(find.text('Replace budgeted amounts?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => budgeted(groceries, month)), 1000);

    await openMenuItem(tester, 'Copy from Previous Month');
    await tester.tap(find.byKey(const Key('budget.overwriteConfirm')));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => budgeted(groceries, month)), 30000);
    expect(await tester.runAsync(() => budgeted(rent, month)), 90000);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => budgeted(groceries, month)), 1000);
    expect(await tester.runAsync(() => budgeted(dining, month)), 0);
    expect(await tester.runAsync(() => budgeted(rent, month)), 90000);
    await unmount(tester);
  });

  testWidgets('apply template: says it is a merge, asks on a non-empty '
      'month, Undo', (tester) async {
    await t.budgeting.saveBudgetTemplate('Usual', previous);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 1000, month);
    await pump(tester);
    await openMenuItem(tester, 'Apply Template');
    expect(
      find.text(
        'Only the categories in the template change; all other categories '
        'keep their amounts.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Usual'));
    await tester.pumpAndSettle();
    expect(find.text('Replace budgeted amounts?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('budget.overwriteConfirm')));
    await tester.pumpAndSettle();
    expect(find.text('“Usual” applied'), findsOneWidget);
    expect(await tester.runAsync(() => budgeted(groceries, month)), 30000);
    expect(await tester.runAsync(() => budgeted(dining, month)), 10000);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => budgeted(groceries, month)), 1000);
    expect(await tester.runAsync(() => budgeted(dining, month)), 0);
    await unmount(tester);
  });

  testWidgets('reset can be undone', (tester) async {
    await t.budgeting.setCategoryBudgetedAmount(groceries, 1000, month);
    await pump(tester);
    await openMenuItem(tester, 'Reset Budget');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Budget reset'), findsOneWidget);
    expect(await tester.runAsync(() => budgeted(groceries, month)), 0);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => budgeted(groceries, month)), 1000);
    await unmount(tester);
  });
}
