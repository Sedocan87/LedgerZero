import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/reports_screen.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';
import 'package:ledger_zero/presentation/widgets/charts/multi_line_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/pie_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

void main() {
  testWidgets('ReportsScreen renders charts', (WidgetTester tester) async {
    // Set a large surface size to ensure all items in ListView are built
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    // Override providers to return dummy data immediately
    final container = ProviderContainer(
      overrides: [
        appFormatterProvider.overrideWithValue(
          AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
        ),
        spendingByCategoryProvider.overrideWith(
          (ref) => Future.value({'Food': 10000}),
        ),
        spendingTrendsProvider.overrideWith(
          (ref) => Future.value({DateTime.utc(2025, 1, 1): 50000}),
        ),
        topPayeesProvider.overrideWith(
          (ref) => Future.value([const MapEntry('Mario', 5000)]),
        ),
        incomeVsExpenseHistoryProvider.overrideWith(
          (ref) => Future.value([
            ChartSeries(
              name: 'Income',
              kind: ChartSeriesKind.income,
              points: [TimeSeriesPoint(DateTime.utc(2025, 1, 1), 10000)],
            ),
          ]),
        ),
        netWorthHistoryProvider.overrideWith(
          (ref) => Future.value([
            ChartSeries(
              name: 'Net Worth',
              kind: ChartSeriesKind.netWorth,
              points: [TimeSeriesPoint(DateTime.utc(2025, 1, 1), 100000)],
            ),
          ]),
        ),
        // Override all data providers to prevent loading states during test
        budgetVsActualProvider.overrideWith((ref) => Future.value([])),
        reportNotesListProvider.overrideWith((ref) => Future.value([])),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReportsScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Wait for futures
    await tester.pump(const Duration(milliseconds: 100));
    // Pump again for animations
    await tester.pumpAndSettle();

    expect(find.byType(ReportsScreen), findsOneWidget);

    // Charts
    expect(
      find.byType(SimpleBarChart),
      findsNWidgets(2),
    ); // Trends + SpendingByCategory
    expect(find.byType(PieChart), findsOneWidget); // CategoryBreakdown
    expect(
      find.byType(MultiLineChart),
      findsNWidgets(2),
    ); // IncomeVsExpense + NetWorth

    // Titles
    expect(find.text('Spending Trends'), findsOneWidget);
    expect(find.text('Spending by Category'), findsOneWidget);
    expect(find.text('Category Breakdown'), findsOneWidget);
    expect(find.text('Income vs Expense'), findsOneWidget);
    expect(find.text('Net Worth'), findsNWidgets(2)); // Title + Legend
    expect(find.text('Top Payees'), findsOneWidget);

    // Data check
    expect(find.text('Mario'), findsOneWidget);
    expect(find.text(r'$50.00'), findsOneWidget);

    // Clean up
    addTearDown(tester.view.resetPhysicalSize);
  });
}
