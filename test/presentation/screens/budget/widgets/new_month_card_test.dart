import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/new_month_fill_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/new_month_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

/// testWidgets that disposes the widget tree (and with it the drift stream
/// subscriptions) before the end.
void dbTestWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  late String groceries;
  // Future months: the card is offered for the current and later months.
  final february = DateTime.utc(2099, 2, 1);
  final march = DateTime.utc(2099, 3, 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    groceries = await t.categoryId('Groceries');
    await t.addAccount(id: 'a', startingBalance: 100000);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, february);
    await t.budgeting.setCategoryBudgetedAmount(
      await t.categoryId('Rent/Mortgage'),
      10000,
      february,
    );
  });

  tearDown(() => t.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          selectedBudgetMonthProvider.overrideWith((ref) => march),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: Column(children: [AutoFillNoteCard(), NewMonthCard()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final card = find.byKey(const Key('budget.newMonthCard'));

  dbTestWidgets('offers the month before with the effect on To Be Budgeted; '
      'filling hides it, Undo brings it back', (tester) async {
    await pump(tester);
    expect(find.text('Start March like February?'), findsOneWidget);
    // $1,000 balance - $400 in February - $400 in March.
    expect(
      find.text(
        '\$400.00 in the same categories. To Be Budgeted after: \$200.00.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Fill like February'));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(find.text('2 categories filled'), findsOneWidget);
    expect(await t.budgeting.isMonthEmpty(march), isFalse);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await t.budgeting.isMonthEmpty(march), isTrue);
    expect(card, findsOneWidget);
  });

  dbTestWidgets('"Not now" hides it for this month', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(prefs.getStringList(NewMonthCard.dismissedKey), ['2099-03']);
  });

  dbTestWidgets('a template can be used instead', (tester) async {
    await t.budgeting.saveBudgetTemplate('Lean', february);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 99900, february);
    await pump(tester);

    await tester.tap(find.text('Use a template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lean'));
    await tester.pumpAndSettle();

    final row = await t.budgets.getBudgetByCategoryAndMonth(
      groceries,
      CalendarDate.monthKey(march),
    );
    expect(row?.budgeted, 30000);
  });

  dbTestWidgets('the automatic fill setting can be chosen from the card', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Fill new months automatically'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Same as the month before'));
    await tester.pumpAndSettle();
    expect(
      prefs.getString(NewMonthFillController.sourceKey),
      AutoFillSource.previousMonth.name,
    );
  });

  dbTestWidgets('after an automatic fill: a note with Undo', (tester) async {
    final filled = await t.budgeting.fillEmptyCategories(march, {
      groceries: 30000,
    });
    await prefs.setString(
      NewMonthFillController.noteKey,
      jsonEncode(AutoFillNote(month: march, filled: filled).toJson()),
    );
    await pump(tester);
    expect(find.text('March was filled automatically'), findsOneWidget);
    expect(
      find.text('\$300.00 from February. Change any amount as usual.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('budget.autoFillNote')), findsNothing);
    expect(await t.budgeting.isMonthEmpty(march), isTrue);
  });

  dbTestWidgets('while the automatic fill waits for income, the card says '
      'what is missing and offers Fill anyway', (tester) async {
    // $1,000 - $400 (February) - $700 rent = -$100: $500 short of $400.
    final rent = await t.categoryId('Rent/Mortgage');
    await t.addTransaction(accountId: 'a', amount: -70000, categoryId: rent);
    await pump(tester);
    final container = ProviderScope.containerOf(tester.element(card));
    final controller = container.read(newMonthFillProvider.notifier);
    // The controller works on the current month in real time; the card
    // is pinned to March 2099, so the wait is set up like runIfDue does.
    await controller.setSource(AutoFillSource.previousMonth);
    controller.state = controller.state.copyWith(
      waiting: AutoFillWaiting(
        month: DateTime.utc(2099, 3, 1),
        total: 40000,
        missing: 50000,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('budget.autoFillWaiting')), findsOneWidget);
    expect(find.text('Waiting for income to fill March'), findsOneWidget);
    expect(
      find.textContaining(
        '\$400.00 is ready to be filled in; To Be Budgeted is \$500.00 short.',
      ),
      findsOneWidget,
    );
    expect(find.text('Fill anyway'), findsOneWidget);
    expect(await t.budgeting.isMonthEmpty(march), isTrue);
  });
}
