import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/salary_prompt.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
  });

  tearDown(() => t.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: SalaryPrompt()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addSalary({DateTime? nextDate}) =>
      t.scheduledTransactions.createScheduledTransaction(
        ScheduledTransaction(
          id: 'salary',
          accountId: 'a',
          amount: 300000,
          frequency: RecurrenceFrequency.monthly,
          nextDate: nextDate,
        ),
      );

  final card = find.byKey(const Key('budget.salaryPrompt'));

  dbTestWidgets('hidden until an account exists', (tester) async {
    await pump(tester);
    expect(card, findsNothing);

    await tester.runAsync(() => t.addAccount(id: 'a'));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    expect(find.text('Add your salary?'), findsOneWidget);
  });

  dbTestWidgets('disappears once a salary is set up', (tester) async {
    await t.addAccount(id: 'a');
    await pump(tester);
    expect(card, findsOneWidget);

    await tester.runAsync(() => addSalary(nextDate: DateTime.utc(2099, 1, 1)));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
  });

  dbTestWidgets('a finished salary does not count', (tester) async {
    await t.addAccount(id: 'a');
    await addSalary();
    await pump(tester);
    expect(card, findsOneWidget);
  });

  dbTestWidgets('"Not now" hides it for good', (tester) async {
    await t.addAccount(id: 'a');
    await pump(tester);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(prefs.getBool(SalaryPrompt.handledKey), isTrue);
  });

  dbTestWidgets('"Add salary" opens the income form', (tester) async {
    await t.addAccount(id: 'a');
    await pump(tester);

    await tester.tap(find.text('Add salary'));
    await tester.pumpAndSettle();
    expect(find.text('Add Salary / Income'), findsOneWidget);
  });
}
