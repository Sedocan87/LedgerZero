import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

Future<AppDatabase> setupIntegrationTest(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Clear preferences
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();

  // Set config
  AppConfig(
    environment: AppEnvironment.development,
    appTitle: 'LedgerZero Test',
    enableLogging: true,
  );

  // Use in-memory database for testing
  final db = AppDatabase(NativeDatabase.memory());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        databaseProvider.overrideWithValue(db),
        ...overrides,
      ],
      child: const MyApp(),
    ),
  );

  await tester.pumpAndSettle();
  return db;
}

// Helper to complete onboarding
Future<void> completeOnboarding(WidgetTester tester) async {
    // 1. Welcome
    // Check if 'Get Started' is present, it might vary based on screen size/layout
    final getStartedFinder = find.text('Get Started');
    if (getStartedFinder.evaluate().isNotEmpty) {
      await tester.tap(getStartedFinder);
      await tester.pumpAndSettle();
    }

    // 2. Security (password123)
    // Check if we are on the security screen
    if (find.text('Create a Password').evaluate().isNotEmpty || find.byType(TextField).evaluate().isNotEmpty) {
       await tester.enterText(find.byType(TextField).first, 'password123');
       await tester.enterText(find.byType(TextField).last, 'password123');
       await tester.tap(find.byIcon(Icons.arrow_forward));
       await tester.pumpAndSettle();
    }

    // 3. Account
    if (find.text('Add First Account').evaluate().isNotEmpty || find.byType(TextField).evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, 'Checking');
      await tester.enterText(find.byType(TextField).last, '1000');
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
    }

    // 4. Finish
    final finishFinder = find.text('Finish Setup');
    if (finishFinder.evaluate().isNotEmpty) {
      await tester.tap(finishFinder);
      await tester.pumpAndSettle();
    }

    final dashboardFinder = find.text('Go to Dashboard');
    if (dashboardFinder.evaluate().isNotEmpty) {
      await tester.tap(dashboardFinder);
      await tester.pumpAndSettle();
    }

    // Skip tutorials if they appear
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
}
