import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';

void main() {
  const noIncome = MonthIncome(
    received: 0,
    expected: 0,
    nextExpectedDate: null,
    hasRecurringIncome: false,
  );

  Widget buildBanner(int tbb, {MonthIncome income = noIncome}) {
    return ProviderScope(
      overrides: [
        tbbProvider.overrideWith((ref, month) => Future.value(tbb)),
        monthIncomeProvider.overrideWith((ref, month) => Future.value(income)),
        appFormatterProvider.overrideWithValue(
          AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ToBeBudgetedBanner()),
      ),
    );
  }

  testWidgets('ToBeBudgetedBanner displays positive amount in green', (
    tester,
  ) async {
    await tester.pumpWidget(buildBanner(10000));

    // Wait for the FutureProvider to resolve
    await tester.pumpAndSettle();

    final tbbTextFinder = find.text('\$100.00');
    expect(tbbTextFinder, findsOneWidget);

    final text = tester.widget<Text>(tbbTextFinder);
    expect(text.style?.color, Colors.green.shade700);
  });

  testWidgets(
    'ToBeBudgetedBanner displays negative amount in error color (red)',
    (tester) async {
      await tester.pumpWidget(buildBanner(-5000));

      await tester.pumpAndSettle();

      final tbbTextFinder = find.text('-\$50.00');
      expect(tbbTextFinder, findsOneWidget);

      final text = tester.widget<Text>(tbbTextFinder);

      final context = tester.element(find.byType(ToBeBudgetedBanner));
      final expectedColor = Theme.of(context).colorScheme.error;

      expect(text.style?.color, expectedColor);
    },
  );

  testWidgets('ToBeBudgetedBanner shows an exact zero without a sign', (
    tester,
  ) async {
    await tester.pumpWidget(buildBanner(0));
    await tester.pumpAndSettle();

    expect(find.text('\$0.00'), findsOneWidget);
    expect(find.text('-\$0.00'), findsNothing);
  });
  group('income line', () {
    testWidgets('invites to add the salary while none is set up', (
      tester,
    ) async {
      await tester.pumpWidget(buildBanner(0));
      await tester.pumpAndSettle();

      expect(
        find.text('Add your salary to budget it every month'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('keeps the invitation next to income received without a '
        'schedule', (tester) async {
      await tester.pumpWidget(
        buildBanner(
          0,
          income: const MonthIncome(
            received: 250000,
            expected: 0,
            nextExpectedDate: null,
            hasRecurringIncome: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Income: \$2,500.00 received'), findsOneWidget);
      expect(
        find.text('Add your salary to budget it every month'),
        findsOneWidget,
      );
    });

    testWidgets('shows received and expected income with a salary', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildBanner(
          0,
          income: MonthIncome(
            received: 250000,
            expected: 300000,
            nextExpectedDate: DateTime.utc(2026, 10, 25),
            hasRecurringIncome: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Income: \$2,500.00 received · \$3,000.00 expected, next Oct 25',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Add your salary to budget it every month'),
        findsNothing,
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('says so when a month with a salary has no income', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildBanner(
          0,
          income: const MonthIncome(
            received: 0,
            expected: 0,
            nextExpectedDate: null,
            hasRecurringIncome: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Income: none this month'), findsOneWidget);
    });
  });
}
