import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

void main() {
  testWidgets('E2E Multi-Screen Navigation', (tester) async {
    // 1. Setup App & Onboarding
    await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // 2. Default: Home
    expect(find.text('To Be Budgeted'), findsOneWidget); // Feature of Home

    // 3. Tab: Budget
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    expect(find.text('Budget'), findsAtLeastNWidgets(1));

    // 4. Tab: Accounts
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Accounts'), findsAtLeastNWidgets(1));

    // 5. Tab: Transactions (might be under a different tab or label)
    // Assuming 5 tabs: Home, Budget, Accounts, Transactions, Reports
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('Transactions'), findsAtLeastNWidgets(1));

    // 6. Tab: Reports
    await tester.tap(find.text('Reports')); // Or icon
    await tester.pumpAndSettle();
    expect(find.text('Reports'), findsAtLeastNWidgets(1));

    // 7. Verify back to Home
    await tester.tap(find.text('Home')); // Or icon
    await tester.pumpAndSettle();
    expect(find.text('To Be Budgeted'), findsOneWidget);
  });
}
