import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/reports_screen.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
import 'package:ledger_zero/presentation/widgets/charts/multi_line_chart.dart';
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
        spendingByCategoryProvider.overrideWith((ref) => Future.value({'Food': 100.0})),
        incomeVsExpenseHistoryProvider.overrideWith((ref) => Future.value([
          ChartSeries(name: 'Income', color: Colors.green, points: [TimeSeriesPoint(DateTime.now(), 100)]),
        ])),
        netWorthHistoryProvider.overrideWith((ref) => Future.value([
           ChartSeries(name: 'Net Worth', color: Colors.blue, points: [TimeSeriesPoint(DateTime.now(), 1000)]),
        ])),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReportsScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Wait for futures
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ReportsScreen), findsOneWidget);
    expect(find.byType(SimpleBarChart), findsOneWidget);
    expect(find.byType(MultiLineChart), findsNWidgets(2)); // IncomeVsExpense and NetWorth
    expect(find.text('Spending by Category'), findsOneWidget);
    expect(find.text('Income vs Expense'), findsOneWidget);
    // Net Worth appears as title and in the chart legend
    expect(find.text('Net Worth'), findsNWidgets(2));

    // Clean up
    addTearDown(tester.view.resetPhysicalSize);
  });
}
