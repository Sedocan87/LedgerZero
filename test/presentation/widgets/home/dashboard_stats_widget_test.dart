// Home's month row and Income / Spending tiles: the month without a frame
// (no going past the current month), tonal tiles, income in the success
// colour and spending in the text colour.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/month_selector.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';

import '../../../widget_test_helpers.dart';

void main() {
  final current = DateTime.utc(2026, 11);

  Future<void> pump(WidgetTester tester) => pumpTestWidget(
    tester,
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: DashboardStatsWidget(),
    ),
    overrides: [
      appFormatterProvider.overrideWithValue(
        AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
      ),
      currentMonthProvider.overrideWithValue(current),
      selectedHomeMonthProvider.overrideWith((ref) => current),
      monthlyStatsProvider.overrideWith(
        (ref, month) => Future.value({'income': 200000, 'spending': 4250}),
      ),
    ],
  );

  testWidgets('income is green, spending is in the text colour', (
    tester,
  ) async {
    await pump(tester);
    final context = tester.element(find.byType(DashboardStatsWidget));
    expect(
      tester.widget<Text>(find.text('\$2,000.00')).style?.color,
      AppSemanticColors.of(context).income,
    );
    expect(
      tester.widget<Text>(find.text('\$42.50')).style?.color,
      Theme.of(context).colorScheme.onSurface,
    );
    // Tabular figures, so the two amounts line up.
    expect(
      tester.widget<Text>(find.text('\$42.50')).style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('the month row has no frame and stops at the current month', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(MonthSwitcher), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNotNull,
    );
  });
}
