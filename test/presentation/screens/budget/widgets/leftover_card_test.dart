import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/leftover_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

/// Money the month before left unassigned: offered once at the start of
/// the month, to budget for savings or keep.
void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  late String groceries;
  final month = CalendarDate.startOfMonthUtc(CalendarDate.today());
  final previous = DateTime.utc(month.year, month.month - 1, 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    groceries = await t.categoryId('Groceries');
    await t.addAccount(id: 'a', startingBalance: 100000);
  });

  tearDown(() => t.close());

  group('leftoverProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(t.db)],
      );
    });

    tearDown(() => container.dispose());

    Future<int> leftover(DateTime m) async {
      final sub = container.listen(leftoverProvider(m), (_, _) {});
      addTearDown(sub.close);
      return container.read(leftoverProvider(m).future);
    }

    test('what the month before left unassigned', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, previous);
      expect(await leftover(month), 70000);
    });

    test('not for a new budget: its starting balance is no leftover', () async {
      expect(await leftover(month), 0);
    });

    test('only what is still unassigned now, and only this month', () async {
      await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, previous);
      await t.budgeting.setCategoryBudgetedAmount(groceries, 50000, month);
      expect(await leftover(month), 20000);
      expect(await leftover(DateTime.utc(month.year, month.month + 1, 1)), 0);
    });
  });

  group('card', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.runAsync(
        () => t.budgeting.setCategoryBudgetedAmount(groceries, 30000, previous),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(t.db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            appFormatterProvider.overrideWithValue(
              AppFormatter(
                locale: 'en',
                currency: 'USD',
                decimalSeparator: '.',
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(body: LeftoverCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }

    final card = find.byKey(const Key('budget.leftoverCard'));

    testWidgets('budgets the leftover in the picked savings category', (
      tester,
    ) async {
      await pump(tester);
      expect(card, findsOneWidget);
      expect(find.textContaining(r'$700.00 from '), findsOneWidget);

      await tester.tap(find.byKey(const Key('budget.leftoverAssign')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Savings'));
      await tester.pumpAndSettle();

      expect(find.text(r'$700.00 budgeted for Savings'), findsOneWidget);
      expect(card, findsNothing);
      final savings = (await tester.runAsync(() => t.categoryId('Savings')))!;
      final budget = await tester.runAsync(
        () => t.budgets.getBudgetByCategoryAndMonth(
          savings,
          CalendarDate.monthKey(month),
        ),
      );
      expect(budget!.budgeted, 70000);
      await unmount(tester);
    });

    testWidgets('"Keep" hides it for this month', (tester) async {
      await pump(tester);
      await tester.tap(find.textContaining('Keep for'));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(prefs.getStringList(LeftoverCard.dismissedKey), [
        CalendarDate.monthKey(month),
      ]);
      await unmount(tester);
    });
  });
}
