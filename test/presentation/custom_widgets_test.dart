import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';

void main() {
  group('SimpleBarChart', () {
    testWidgets('Renders empty state when data is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SimpleBarChart(
              data: {},
              barColor: Colors.blue,
              labelColor: Colors.black,
            ),
          ),
        ),
      );

      expect(
        find.text('No transactions found'),
        findsOneWidget,
      ); // Assuming default localizations or fallback
    });

    testWidgets('Renders bars and labels when data is provided', (
      tester,
    ) async {
      final data = {'Food': 500.0, 'Rent': 1200.0};

      await tester.pumpWidget(
        MaterialApp(
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
      );

      // Verify semantics exist using finder. If found, the label matches the regex.
      final semanticsFinder = find.bySemanticsLabel(
        RegExp(r'Bar Chart showing:.*Rent: 1200.00.*'),
      );
      expect(semanticsFinder, findsOneWidget);

      final semanticsFinder2 = find.bySemanticsLabel(
        RegExp(r'Bar Chart showing:.*Food: 500.00.*'),
      );
      expect(semanticsFinder2, findsOneWidget);
    });

    testWidgets('Should repaint returns false for identical data', (
      tester,
    ) async {
      // Unit test for Painter
      final painter = BarChartPainter(
        data: const [MapEntry('A', 10.0)],
        barColor: Colors.blue,
        labelColor: Colors.black,
      );

      final otherPainter = BarChartPainter(
        data: const [MapEntry('A', 10.0)],
        barColor: Colors.blue,
        labelColor: Colors.black,
      );

      expect(painter.shouldRepaint(otherPainter), isFalse);
    });

    testWidgets('Should repaint returns true for different data', (
      tester,
    ) async {
      final painter = BarChartPainter(
        data: const [MapEntry('A', 10.0)],
        barColor: Colors.blue,
        labelColor: Colors.black,
      );

      final otherPainter = BarChartPainter(
        data: const [MapEntry('A', 20.0)],
        barColor: Colors.blue,
        labelColor: Colors.black,
      );

      expect(painter.shouldRepaint(otherPainter), isTrue);
    });
  });
}
