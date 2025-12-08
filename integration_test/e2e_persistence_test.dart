import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

void main() {
  testWidgets('E2E Data Persistence Simulation', (tester) async {
    // 1. Setup App & Onboarding
    // Note: To test persistence, we would ideally use a real file database path.
    // However, setupIntegrationTest uses in-memory.
    // We can simulate persistence by creating a DB, adding data, closing it,
    // and reopening it with the same in-memory reference/executor if Drift supports it,
    // OR just verify that data written is queryable immediately (which is basic correctness).

    // Ideally, for "App Restart", we rely on the `database_test.dart` (unit/integration level)
    // that uses a temp file.

    // Here we verify that navigating away and back preserves state in memory (app lifecycle simulation).

    await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // 2. Add an Account
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Account Name'), 'Persistent Account');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Starting Balance'), '100.00');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Persistent Account'), findsOneWidget);

    // 3. Navigate Away (to Budget)
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    // 4. Navigate Back
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    // 5. Verify Account Still Exists
    expect(find.text('Persistent Account'), findsOneWidget);
  });
}
