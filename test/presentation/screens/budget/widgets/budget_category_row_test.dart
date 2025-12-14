import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';

void main() {
  const category = Category(id: '1', name: 'Test Category');

  testWidgets('BudgetCategoryRow displays positive available amount in green', (
    tester,
  ) async {
    const viewModel = BudgetCategoryViewModel(
      category: category,
      budgeted: 100.0,
      activity: -50.0,
      available: 50.0,
      goalTarget: 0.0,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: BudgetCategoryRow(viewModel: viewModel)),
        ),
      ),
    );

    final containerFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final decoration = widget.decoration as BoxDecoration;
        return decoration.color == Colors.green.shade100;
      }
      return false;
    });

    expect(containerFinder, findsOneWidget);

    final availableTextFinder = find.descendant(
      of: containerFinder,
      matching: find.text('\$50.00'),
    );

    expect(availableTextFinder, findsOneWidget);

    final text = tester.widget<Text>(availableTextFinder);
    expect(text.style?.color, Colors.green.shade800);
  });

  testWidgets('BudgetCategoryRow displays negative available amount in red', (
    tester,
  ) async {
    const viewModel = BudgetCategoryViewModel(
      category: category,
      budgeted: 0.0,
      activity: -50.0,
      available: -50.0,
      goalTarget: 0.0,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: BudgetCategoryRow(viewModel: viewModel)),
        ),
      ),
    );

    final containerFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final decoration = widget.decoration as BoxDecoration;
        return decoration.color == Colors.red.shade100;
      }
      return false;
    });

    expect(containerFinder, findsOneWidget);

    final availableTextFinder = find.descendant(
      of: containerFinder,
      matching: find.text('-\$50.00'),
    );
    expect(availableTextFinder, findsOneWidget);

    final text = tester.widget<Text>(availableTextFinder);
    expect(text.style?.color, Colors.red.shade800);
  });

  testWidgets('BudgetCategoryRow displays zero available amount in grey', (
    tester,
  ) async {
    const viewModel = BudgetCategoryViewModel(
      category: category,
      budgeted: 100.0,
      activity: -100.0,
      available: 0.0,
      goalTarget: 0.0,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: BudgetCategoryRow(viewModel: viewModel)),
        ),
      ),
    );

    final containerFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final decoration = widget.decoration as BoxDecoration;
        return decoration.color == Colors.grey.withValues(alpha: 0.1);
      }
      return false;
    });

    expect(containerFinder, findsOneWidget);

    final availableTextFinder = find.descendant(
      of: containerFinder,
      matching: find.text('\$0.00'),
    );
    expect(availableTextFinder, findsOneWidget);
  });
}
