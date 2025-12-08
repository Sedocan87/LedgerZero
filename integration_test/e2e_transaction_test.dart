import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

void main() {
  testWidgets('E2E Transaction Lifecycle: Create, Edit, Delete', (tester) async {
    // 1. Setup App & Onboarding (Creates a default 'Checking' account)
    await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // 2. Navigate to Transactions Screen (via bottom nav or FAB on Home)
    // Using FAB on Home for quick access
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Verify Add Transaction Screen
    expect(find.text('Add Transaction'), findsOneWidget);

    // 3. Create Transaction
    await tester.enterText(find.widgetWithText(TextFormField, '0.00'), '50.00'); // Amount

    // Payee
    final payeeField = find.widgetWithText(TextFormField, 'Payee');
    await tester.enterText(payeeField, 'Grocery Store');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Category (Assuming 'Groceries' exists from default seed)
    await tester.tap(find.text('Select Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // 4. Verify in Transaction List (Home Screen Recent Transactions or Transactions Tab)
    await tester.tap(find.text('Transactions')); // Go to full list
    await tester.pumpAndSettle();

    expect(find.text('Grocery Store'), findsOneWidget);
    expect(find.text('-\$50.00'), findsOneWidget); // Expense is negative usually

    // 5. Edit Transaction
    await tester.tap(find.text('Grocery Store')); // Tap to edit
    await tester.pumpAndSettle();

    expect(find.text('Edit Transaction'), findsOneWidget);

    // Change Amount
    await tester.enterText(find.widgetWithText(TextFormField, '50.00'), '60.00');

    // Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify Edit
    expect(find.text('-\$60.00'), findsOneWidget);

    // 6. Delete Transaction
    // Swipe to delete or open and delete.
    // Let's open and verify delete button if exists, or use swipe action.
    // Assuming swipe left for delete in list
    await tester.drag(find.text('Grocery Store'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Confirm Delete (if dialog)
    // Note: Implementation might be swipe-to-reveal delete button or immediate.
    // Assuming a delete icon appears or immediate dialog.
    // If swipe reveals action:
    if (find.byIcon(Icons.delete).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
    }

    // Check for confirmation dialog
    if (find.text('Delete Transaction').evaluate().isNotEmpty) {
       await tester.tap(find.text('Delete'));
       await tester.pumpAndSettle();
    }

    // Verify Gone
    expect(find.text('Grocery Store'), findsNothing);
  });
}
