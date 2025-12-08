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

Future<AppDatabase> setupIntegrationTest(WidgetTester tester) async {
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
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // 2. Security (password123)
    await tester.enterText(find.byType(TextField).first, 'password123');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    // 3. Account
    await tester.enterText(find.byType(TextField).first, 'Checking');
    await tester.enterText(find.byType(TextField).last, '1000');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    // 4. Finish
    await tester.tap(find.text('Finish Setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Dashboard'));
    await tester.pumpAndSettle();

    // Skip tutorials if they appear
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
}
