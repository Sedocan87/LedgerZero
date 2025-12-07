import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';
import 'package:ledger_zero/presentation/widgets/common/buttons.dart';

void main() {
  group('Accessibility Semantics Tests', () {
    testWidgets('SimpleBarChart has semantics', (WidgetTester tester) async {
      final data = {'Food': 100.0, 'Rent': 500.0};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleBarChart(
              data: data,
              barColor: Colors.blue,
              labelColor: Colors.black,
            ),
          ),
        ),
      );

      // Verify Semantics
      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.byType(SimpleBarChart)), matchesSemantics(
        label: 'Bar Chart showing: Rent: 500.00, Food: 100.00',
      ));
      handle.dispose();
    });

    testWidgets('AppButton has button semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Save',
              onPressed: () {},
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.byType(AppButton)), matchesSemantics(
        label: 'Save',
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ));
      handle.dispose();
    });

    testWidgets('AppButton disabled semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Save',
              onPressed: null, // Disabled
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.byType(AppButton)), matchesSemantics(
        label: 'Save',
        isButton: true,
        isEnabled: false,
      ));
      handle.dispose();
    });
  });
}
