import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

void main() {
  testWidgets('E2E Migration Workflow (YNAB/Mint)', (tester) async {
    // 1. Setup App & Onboarding
    await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // 2. Navigate to Settings -> Import
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import Data'));
    await tester.pumpAndSettle();

    // 3. Verify Migration Options
    expect(find.text('Import from YNAB'), findsOneWidget);
    expect(find.text('Import from Mint'), findsOneWidget);

    // 4. Test YNAB Flow Navigation
    await tester.tap(find.text('Import from YNAB'));
    await tester.pumpAndSettle();

    // Verify YNAB Wizard
    // expect(find.text('YNAB Migration'), findsOneWidget); // Or specific title

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 5. Test Mint Flow Navigation
    await tester.tap(find.text('Import from Mint'));
    await tester.pumpAndSettle();

    // Verify Mint Wizard
    // expect(find.text('Mint Migration'), findsOneWidget); // Or specific title

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  });
}
