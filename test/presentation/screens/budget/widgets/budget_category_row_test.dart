import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';

void main() {
  const category = Category(id: '1', name: 'Test Category');

  Future<void> pumpRow(
    WidgetTester tester,
    BudgetCategoryViewModel viewModel, {
    AppFormatter? formatter,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFormatterProvider.overrideWithValue(
            formatter ??
                AppFormatter(
                  locale: 'en',
                  currency: 'USD',
                  decimalSeparator: '.',
                ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: BudgetCategoryRow(viewModel: viewModel)),
        ),
      ),
    );
  }

  Finder bubbleWithColor(Color color) {
    return find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final decoration = widget.decoration as BoxDecoration;
        return decoration.color == color;
      }
      return false;
    });
  }

  testWidgets('BudgetCategoryRow displays positive available amount in green', (
    tester,
  ) async {
    const viewModel = BudgetCategoryViewModel(
      category: category,
      budgeted: 10000,
      activity: -5000,
      available: 5000,
      goalTarget: 0,
    );

    await pumpRow(tester, viewModel);

    final containerFinder = bubbleWithColor(
      AppColors.success.withValues(alpha: 0.1),
    );
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
      budgeted: 0,
      activity: -5000,
      available: -5000,
      goalTarget: 0,
    );

    await pumpRow(tester, viewModel);

    final containerFinder = bubbleWithColor(
      AppColors.expense.withValues(alpha: 0.1),
    );
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
    // Budgeted and spent cancel out exactly; with minor units this is a
    // true zero and must not render as a red "-$0.00".
    const viewModel = BudgetCategoryViewModel(
      category: category,
      budgeted: 1010,
      activity: -1010,
      available: 0,
      goalTarget: 0,
    );

    await pumpRow(tester, viewModel);

    final context = tester.element(find.byType(BudgetCategoryRow));
    final scheme = Theme.of(context).colorScheme;
    final containerFinder = bubbleWithColor(
      scheme.surfaceContainerHighest.withValues(alpha: 0.5),
    );
    expect(containerFinder, findsOneWidget);

    final availableTextFinder = find.descendant(
      of: containerFinder,
      matching: find.text('\$0.00'),
    );
    expect(availableTextFinder, findsOneWidget);
    expect(find.text('-\$0.00'), findsNothing);

    final text = tester.widget<Text>(availableTextFinder);
    expect(text.style?.color, scheme.onSurfaceVariant);
  });

  testWidgets('BudgetCategoryRow formats amounts with the user settings', (
    tester,
  ) async {
    const viewModel = BudgetCategoryViewModel(
      category: category,
      budgeted: 123456,
      activity: -2050,
      available: 121406,
      goalTarget: 0,
    );
    final formatter = AppFormatter(
      locale: 'de',
      currency: 'EUR',
      decimalSeparator: ',',
    );

    await pumpRow(tester, viewModel, formatter: formatter);

    expect(find.text(formatter.formatMoney(123456)), findsOneWidget);
    expect(find.text(formatter.formatMoney(-2050)), findsOneWidget);
    expect(find.text(formatter.formatMoney(121406)), findsOneWidget);
    expect(formatter.formatMoney(123456), contains('1.234,56'));
  });
}
