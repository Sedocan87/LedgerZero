import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
import 'test_utils.dart';

void main() {
  testWidgets('E2E Account Creation', (tester) async {
    // 1. Setup App
    await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // 2. Navigate to Accounts Screen
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    // Verify we are on Accounts screen
    expect(find.byType(AccountsScreen), findsOneWidget);

    // 3. Tap Add Account (FAB)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Verify Add Account Screen
    expect(find.text('Add Account'), findsOneWidget);

    // 4. Fill Form
    // Name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account Name'),
      'Savings Account',
    );

    // Type (Defaults to Checking, change to Savings)
    // Note: Dropdown finding might vary based on implementation.
    // Assuming standard DropdownButtonFormField or similar.
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Savings').last); // Select from menu
    await tester.pumpAndSettle();

    // Balance
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Starting Balance'),
      '5000.00',
    );

    // 5. Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // 6. Verify Account Created in List
    expect(find.text('Savings Account'), findsOneWidget);
    expect(find.text('\$5,000.00'), findsOneWidget); // Format depends on locale
  });
}
