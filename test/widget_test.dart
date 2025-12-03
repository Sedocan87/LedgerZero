// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App starts with Onboarding Screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    // Initialize AppConfig
    try {
      AppConfig(
        environment: AppEnvironment.development,
        appTitle: 'LedgerZero Test',
      );
    } catch (_) {
      // Already initialized
    }

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MyApp(),
      ),
    );

    // Wait for animations and navigation
    await tester.pumpAndSettle();

    // Verify that we are on the Onboarding Screen
    expect(find.text('Welcome to LedgerZero'), findsOneWidget);
  });
}
