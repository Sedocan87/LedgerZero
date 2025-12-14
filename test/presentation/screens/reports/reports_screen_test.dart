import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/reports_screen.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
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
        spendingByCategoryProvider.overrideWith(
          (ref) => Future.value({'Food': 100.0}),
        ),
        spendingTrendsProvider.overrideWith(
          (ref) => Future.value({DateTime(2025, 1, 1): 500.0}),
        ),
        topPayeesProvider.overrideWith(
          (ref) => Future.value([const MapEntry('Mario', 50.0)]),
        ),
        incomeVsExpenseHistoryProvider.overrideWith(
          (ref) => Future.value([
            ChartSeries(
              name: 'Income',
              color: Colors.green,
              points: [TimeSeriesPoint(DateTime.now(), 100)],
            ),
          ]),
        ),
        netWorthHistoryProvider.overrideWith(
          (ref) => Future.value([
            ChartSeries(
              name: 'Net Worth',
              color: Colors.blue,
              points: [TimeSeriesPoint(DateTime.now(), 1000)],
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

    // Clean up
    addTearDown(tester.view.resetPhysicalSize);
  });
}
