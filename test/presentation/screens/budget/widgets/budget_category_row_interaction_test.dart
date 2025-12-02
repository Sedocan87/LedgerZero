import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/providers/budget_ui_state_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_input_field.dart';

void main() {
  const category1 = Category(id: '1', name: 'Cat 1');
  const category2 = Category(id: '2', name: 'Cat 2');

  const viewModel1 = BudgetCategoryViewModel(
    category: category1,
    budgeted: 100.0,
    activity: 0.0,
    available: 100.0,
  );

  const viewModel2 = BudgetCategoryViewModel(
    category: category2,
    budgeted: 200.0,
    activity: 0.0,
    available: 200.0,
  );

  // Mock ordered categories
  final orderedCategoriesOverride = budgetOrderedCategoriesProvider.overrideWith(
      (ref) => Future.value(['1', '2']));

  testWidgets('Tap on amount enables editing', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: BudgetCategoryRow(viewModel: viewModel1),
        ),
      ),
    ));

    // Initially not editing (Text widget)
    expect(find.byType(BudgetInputField), findsNothing);
    // There are 3 texts: name, budgeted, activity, available.
    // budgeted is formatted.
    expect(find.text('\$100.00'), findsAny);

    // Tap on budgeted amount (which is the container with gesture detector)
    // We can find by text.
    await tester.tap(find.text('\$100.00').first);
    await tester.pump();

    // Now editing (BudgetInputField)
    expect(find.byType(BudgetInputField), findsOneWidget);
  });

  testWidgets('Keyboard navigation (Down Arrow) switches to next category', (tester) async {
    // We need a stateful container for the provider overrides to persist?
    // ProviderScope manages it.

    await tester.pumpWidget(ProviderScope(
      overrides: [
         orderedCategoriesOverride,
         // We can't override StateProvider with a specific initial state easily in overrides list
         // without creating a custom provider, but here we can just set it?
         // Actually we can override with a notifier that has initial state?
         // Or simpler: just let the test tap to start editing.
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
               BudgetCategoryRow(viewModel: viewModel1),
               BudgetCategoryRow(viewModel: viewModel2),
            ],
          ),
        ),
      ),
    ));

    // Wait for future provider
    await tester.pumpAndSettle();

    // Start editing first row
    await tester.tap(find.text('Cat 1')); // Wait, text is "Cat 1".
    await tester.tap(find.text('\$100.00').first);
    await tester.pump();

    expect(find.descendant(of: find.byType(BudgetCategoryRow).first, matching: find.byType(BudgetInputField)), findsOneWidget);
    expect(find.descendant(of: find.byType(BudgetCategoryRow).last, matching: find.byType(BudgetInputField)), findsNothing);

    // Press Down Arrow
    // We need to focus? AppTextField requests focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Verify cat 2 is editing
    expect(find.descendant(of: find.byType(BudgetCategoryRow).first, matching: find.byType(BudgetInputField)), findsNothing);
    expect(find.descendant(of: find.byType(BudgetCategoryRow).last, matching: find.byType(BudgetInputField)), findsOneWidget);
  });
}
