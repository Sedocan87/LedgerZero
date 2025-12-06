import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/main_development.dart' as app;
import 'package:ledger_zero/presentation/widgets/tutorial/tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Onboarding and Tutorial Flow Test', (tester) async {
    // Clear SharedPreferences to simulate fresh install
    SharedPreferences.setMockInitialValues({});

    app.main();
    await tester.pumpAndSettle();

    // 1. Verify Onboarding Screen
    expect(find.text('Welcome to LedgerZero'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // 2. Security Setup
    expect(find.text('Secure Your Data'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'password123');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    // 3. Account Setup
    expect(find.text('Add First Account'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Test Checking');
    await tester.enterText(find.byType(TextField).last, '1000');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    // 4. Budget Setup
    expect(find.text('Set Initial Budget'), findsOneWidget);
    await tester.tap(find.text('Finish Setup'));
    await tester.pumpAndSettle();

    // 5. Completion
    expect(find.text('All Set!'), findsOneWidget);
    await tester.tap(find.text('Go to Dashboard'));
    await tester.pumpAndSettle();

    // 6. Verify Dashboard/Budget Screen Tutorial
    // Note: Depends on which screen loads first. Usually Home.
    // If Budget screen is navigated to, tutorial should show.

    // Navigate to Budget
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    // Check for Tutorial Overlay
    expect(find.byType(TutorialOverlay), findsOneWidget);
    expect(find.text('Welcome to your Budget'), findsOneWidget);

    // Tap Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Select Month'), findsOneWidget);

    // Skip Tutorial
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialOverlay), findsNothing);

    // 7. Verify Transaction Tutorial
    // Navigate to Add Transaction (FAB)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Check for Tutorial Overlay
    expect(find.byType(TutorialOverlay), findsOneWidget);
    expect(find.text('Enter Amount'), findsOneWidget);

    // Skip
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialOverlay), findsNothing);
  });
}
