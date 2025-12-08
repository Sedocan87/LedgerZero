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

// Helper to initialize the app for integration tests
// Uses in-memory database and mock shared preferences
Future<void> setupIntegrationTest(WidgetTester tester) async {
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
}

// Basic smoke test to verify setup
void main() {
  testWidgets('App starts up and shows onboarding', (tester) async {
    await setupIntegrationTest(tester);

    expect(find.text('Welcome to LedgerZero'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
