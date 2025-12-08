import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

void main() {
  testWidgets('E2E CSV Import Workflow', (tester) async {
    // 1. Setup App & Onboarding
    await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // 2. Navigate to Settings -> Import
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import Data'));
    await tester.pumpAndSettle();

    // 3. Select CSV Import
    await tester.tap(find.text('Import CSV'));
    await tester.pumpAndSettle();

    // Verify Import Screen
    expect(find.text('Select CSV File'), findsOneWidget);

    // 4. Simulate File Picking
    // This requires mocking the FilePicker result.
    // Without mocking, we can't proceed past this point in a real automated test easily.
    // We verify the UI is reachable.

    // If we could mock:
    // mockFilePicker.pickFiles(returns: 'test_statement.csv');
    // await tester.tap(find.text('Pick File'));
    // await tester.pumpAndSettle();

    // Verify Mapping Screen
    // expect(find.text('Map Columns'), findsOneWidget);

    // Go back
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  });
}
