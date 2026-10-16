import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/widgets/budget_vs_actual_chart.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';
import 'package:ledger_zero/presentation/widgets/charts/balance_trend_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';
import 'package:ledger_zero/presentation/widgets/charts/multi_line_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/pie_chart.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';
import 'package:ledger_zero/presentation/widgets/common/app_button.dart';

final _usd = AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.');

/// [child] in a localised app with the en/USD formatter.
Widget _app(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [appFormatterProvider.overrideWithValue(_usd), ...overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('Accessibility Semantics Tests', () {
    testWidgets('SimpleBarChart has semantics', (WidgetTester tester) async {
      final data = {'Food': 10000, 'Rent': 50000};

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appFormatterProvider.overrideWithValue(
              AppFormatter(
                locale: 'en',
                currency: 'USD',
                decimalSeparator: '.',
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SimpleBarChart(
                data: data,
                barColor: Colors.blue,
                labelColor: Colors.black,
              ),
            ),
          ),
        ),
      );

      // Verify Semantics
      final handle = tester.ensureSemantics();
      // Find the semantics node that contains the label
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(RegExp(r'Bar Chart showing.*')),
        ),
        matchesSemantics(
          label: r'Bar Chart showing: Rent: $500.00, Food: $100.00',
        ),
      );
      handle.dispose();
    });

    testWidgets('PieChart exposes a summary of its slices', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const PieChart(
            data: {'Food': 4500, 'Rent': 3000, 'Fun': 2500},
            labelColor: Colors.black,
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Pie chart: Food 45.0%, Rent 30.0%, Fun 25.0%'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('MultiLineChart summarises range, min, max and latest', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          MultiLineChart(
            seriesList: [
              ChartSeries(
                name: 'Net Worth',
                kind: ChartSeriesKind.netWorth,
                points: [
                  TimeSeriesPoint(DateTime.utc(2024, 1, 1), 10000),
                  TimeSeriesPoint(DateTime.utc(2024, 2, 1), 5000),
                  TimeSeriesPoint(DateTime.utc(2024, 3, 1), 20000),
                  TimeSeriesPoint(DateTime.utc(2024, 4, 1), 15000),
                ],
              ),
            ],
            gridColor: Colors.grey,
            labelColor: Colors.black,
          ),
        ),
      );

      final start = _usd.formatDate(DateTime.utc(2024, 1, 1));
      final end = _usd.formatDate(DateTime.utc(2024, 4, 1));
      expect(
        find.bySemanticsLabel(
          'Line chart. Net Worth from $start to $end: lowest \$50.00, '
          'highest \$200.00, latest \$150.00',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('BalanceTrendChart exposes a summary label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          BalanceTrendChart(
            startingBalance: 10000,
            transactions: [
              Transaction(
                id: 't1',
                accountId: 'a',
                date: DateTime.utc(2024, 1, 10),
                amount: -2500,
              ),
              Transaction(
                id: 't2',
                accountId: 'a',
                date: DateTime.utc(2024, 1, 20),
                amount: 1000,
              ),
            ],
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Line chart\. Balance Trend from .* lowest \$75\.00, '
            r'highest \$100\.00, latest \$85\.00$',
          ),
        ),
        findsOneWidget,
      );
      // Painted in its own layer, like the other charts.
      expect(
        find.descendant(
          of: find.byType(BalanceTrendChart),
          matching: find.byWidgetPredicate(
            (w) => w is RepaintBoundary && w.child is CustomPaint,
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('BudgetVsActualChart exposes a summary label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const BudgetVsActualChart(),
          overrides: [
            budgetVsActualProvider.overrideWith(
              (ref) async => [
                BudgetVsActualItem(
                  categoryName: 'Food',
                  budgeted: 30000,
                  actual: 25000,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          r'Budget vs actual: Food: $300.00 budgeted, $250.00 spent',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('TransactionListItem clear-status button is at least 48x48', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      TransactionClearStatus? changed;
      await tester.pumpWidget(
        _app(
          TransactionListItem(
            transaction: Transaction(
              id: 't1',
              accountId: 'a',
              date: DateTime.utc(2024, 1, 10),
              amount: -2500,
            ),
            payeeName: 'Shop',
            onClearStatusChanged: (status) => changed = status,
          ),
        ),
      );

      final button = find.byType(IconButton);
      expect(button, findsOneWidget);
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      // The icon keeps its visual size.
      expect(tester.getSize(find.byIcon(Icons.check_circle_outline)).width, 20);

      await tester.tap(button);
      expect(changed, TransactionClearStatus.cleared);

      // The row is read as one item; the amount with its direction and
      // without the raw glyphs.
      expect(find.bySemanticsLabel(RegExp(r'Outflow \$25\.00')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp(r'-\$25\.00')), findsNothing);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('AppButton has button semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(label: 'Save', onPressed: () {}),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(AppButton)),
        matchesSemantics(
          label: 'Save',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('AppButton disabled semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Save',
              onPressed: null, // Disabled
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(AppButton)),
        matchesSemantics(
          label: 'Save',
          isButton: true,
          isEnabled: false,
          hasEnabledState: true,
        ),
      );
      handle.dispose();
    });
  });
}
