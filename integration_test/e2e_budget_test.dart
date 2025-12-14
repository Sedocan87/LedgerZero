import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

void main() {
  testWidgets('E2E Budget Allocation Flow', (tester) async {
    // 1. Setup App & Onboarding
    await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // 2. Navigate to Budget Screen
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    // Verify "To Be Budgeted" is visible (should have some amount from initial account)
    // Checking was 1000.
    expect(find.text('To Be Budgeted'), findsOneWidget);
    // Exact text format might vary, e.g., "$1,000.00"

    // 3. Find a Category (e.g., 'Groceries') and Budget Money
    // Note: Categories are usually in a list.
    // We need to find the budgeted amount field for 'Groceries'.
    // Assuming the row has the category name and a text field or tappable area for budget.

    // Tap on Groceries row/budget cell
    // Finding the widget might be tricky without keys.
    // Assuming tapping the row opens a detail/edit sheet or inline edit.
    // Let's assume inline edit or "Budget" button.

    // Attempt: Find category name, tap it.
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    // Verify Edit Budget Sheet/Dialog
    // Assuming a numeric keypad or input field appears.
    // "Enter Amount"

    // If it's the "Move Money" or "Budget Amount" dialog
    // Enter 200
    // We might need to find the text field.
    // If inline, finding the TextField inside the row.

    // Simplification: Assume tapping opens a modal with a text field.
    final inputFinder = find.byType(TextField).first; // Or specific key
    if (inputFinder.evaluate().isNotEmpty) {
      await tester.enterText(inputFinder, '200');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    } else {
      // Maybe calculator widget?
      // Fallback: Check implementation details if tests fail.
      // For now, assuming standard text input flow.

      // If the implementation uses a custom calculator, we need to tap buttons.
      // Let's assume text input for simplicity of this E2E skeleton.
    }

    // Close dialog if needed (e.g. "Save", "OK")
    if (find.text('Save').evaluate().isNotEmpty) {
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    // 4. Verify Updates
    // Budgeted column for Groceries should be 200.
    // Available column for Groceries should be 200 (assuming 0 activity).
    // TBB should decrease by 200.

    // Finding specific text widgets in the tree is safer.
    expect(find.text('\$200.00'), findsAtLeastNWidgets(1));
    // One for Budgeted, one for Available likely.
  });
}
