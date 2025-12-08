import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

void main() {
  testWidgets('E2E Sync Workflow (Mock UI interaction)', (tester) async {
    // 1. Setup App & Onboarding
    await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // 2. Navigate to Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // 3. Navigate to Sync Settings
    await tester.tap(find.text('Synchronization'));
    await tester.pumpAndSettle();

    // 4. Verify Options
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('iCloud Drive'), findsOneWidget);

    // 5. Simulate Connect (Mocking the auth flow is complex in E2E without mocks injected)
    // In a real E2E with mocked services (which we set up in test_utils via overrides if we had them),
    // we would tap "Connect" and verify the state changes.

    // Since we didn't inject a MockSyncService in setupIntegrationTest (only DB and Prefs),
    // this test will verify the UI presence and basic interactions, but not the actual cloud logic.
    // This serves as a placeholder for when service injection is fully wired for tests.

    // Tap Connect (expecting it might fail or show a dialog/spinner)
    // await tester.tap(find.text('Connect').first);
    // await tester.pump();

    // Verify "Sync Now" button exists (manual trigger)
    // Usually only appears if connected.

    // Go back
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  });
}
