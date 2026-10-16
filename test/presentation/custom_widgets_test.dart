import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';

void main() {
  final formatter = AppFormatter(
    locale: 'en',
    currency: 'USD',
    decimalSeparator: '.',
  );

  Widget wrap(Widget child) => ProviderScope(
    overrides: [appFormatterProvider.overrideWithValue(formatter)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  group('SimpleBarChart', () {
    testWidgets('Renders empty state when data is empty', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SimpleBarChart(
            data: {},
            barColor: Colors.blue,
            labelColor: Colors.black,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions'), findsOneWidget);
    });

    testWidgets('Renders bars and labels when data is provided', (
      tester,
    ) async {
      final data = {'Food': 50000, 'Rent': 120000};

      await tester.pumpWidget(
        wrap(
          SimpleBarChart(
            data: data,
            barColor: Colors.blue,
            labelColor: Colors.black,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify semantics exist using finder. If found, the label matches the regex.
      final semanticsFinder = find.bySemanticsLabel(
        RegExp(r'Bar Chart showing:.*Rent: \$1,200\.00.*'),
      );
      expect(semanticsFinder, findsOneWidget);

      final semanticsFinder2 = find.bySemanticsLabel(
        RegExp(r'Bar Chart showing:.*Food: \$500\.00.*'),
      );
      expect(semanticsFinder2, findsOneWidget);
    });

    testWidgets('Should repaint returns false for identical data', (
      tester,
    ) async {
      // Unit test for Painter
      final painter = BarChartPainter(
        data: const [MapEntry('A', 1000)],
        barColor: Colors.blue,
        labelColor: Colors.black,
        formatter: formatter,
      );

      final otherPainter = BarChartPainter(
        data: const [MapEntry('A', 1000)],
        barColor: Colors.blue,
        labelColor: Colors.black,
        formatter: formatter,
      );

      expect(painter.shouldRepaint(otherPainter), isFalse);
    });

    test('Should repaint returns true for a different formatter', () {
      final painter = BarChartPainter(
        data: const [MapEntry('A', 1000)],
        barColor: Colors.blue,
        labelColor: Colors.black,
        formatter: formatter,
      );
      final otherPainter = BarChartPainter(
        data: const [MapEntry('A', 1000)],
        barColor: Colors.blue,
        labelColor: Colors.black,
        formatter: AppFormatter(
          locale: 'de',
          currency: 'EUR',
          decimalSeparator: ',',
        ),
      );

      expect(painter.shouldRepaint(otherPainter), isTrue);
    });

    testWidgets('Should repaint returns true for different data', (
      tester,
    ) async {
      final painter = BarChartPainter(
        data: const [MapEntry('A', 1000)],
        barColor: Colors.blue,
        labelColor: Colors.black,
        formatter: formatter,
      );

      final otherPainter = BarChartPainter(
        data: const [MapEntry('A', 2000)],
        barColor: Colors.blue,
        labelColor: Colors.black,
        formatter: formatter,
      );

      expect(painter.shouldRepaint(otherPainter), isTrue);
    });
  });
}
