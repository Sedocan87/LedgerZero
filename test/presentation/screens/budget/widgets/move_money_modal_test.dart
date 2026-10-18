import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/move_money_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

void main() {
  testWidgets('moving money can be undone from the snack bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    final month = DateTime.utc(2024, 5);
    final groceries = await t.categoryId('Groceries');
    final dining = await t.categoryId('Dining Out');
    await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, month);

    Future<int> budgeted(String id) async =>
        (await t.budgets.getBudgetByCategoryAndMonth(
          id,
          CalendarDate.monthKey(month),
        ))?.budgeted ??
        0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          selectedBudgetMonthProvider.overrideWith((ref) => month),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => MoveMoneyModal(
                    initialFromCategoryId: groceries,
                    initialToCategoryId: dining,
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

    await tester.enterText(find.byType(TextFormField).last, '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => budgeted(groceries)), 20000);
    expect(await tester.runAsync(() => budgeted(dining)), 10000);
    expect(find.text('Money moved'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => budgeted(groceries)), 30000);
    expect(await tester.runAsync(() => budgeted(dining)), 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('hidden categories are not offered, except a preselected one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    final month = DateTime.utc(2024, 5);
    final groceries = await t.categoryId('Groceries');
    for (final name in ['Electric', 'Water']) {
      final c = (await t.categories.getCategoryById(await t.categoryId(name)))!;
      await t.categories.updateCategory(c.copyWith(isHidden: true));
    }
    final electric = await t.categoryId('Electric');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          selectedBudgetMonthProvider.overrideWith((ref) => month),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: MoveMoneyModal(
              initialFromCategoryId: electric,
              initialToCategoryId: groceries,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final items = tester
        .widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .expand((d) => d.items ?? const <DropdownMenuItem<String>>[])
        .map((i) => i.value)
        .toSet();
    expect(items, contains(groceries));
    expect(items, contains(electric));
    expect(items, isNot(contains(await t.categoryId('Water'))));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
