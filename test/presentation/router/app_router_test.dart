import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/config/app_config.dart';

void main() {
  setUpAll(() {
    // Initialize AppConfig for the test suite
    try {
      AppConfig(environment: AppEnvironment.development, appTitle: 'Test App');
    } catch (_) {
      // Already initialized
    }
  });

  testWidgets('Initial route is Home when onboarded and authenticated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
             sharedPreferencesProvider.overrideWithValue(sharedPreferences),
             authProvider.overrideWith((ref) => AuthNotifier(sharedPreferences)..setOnboarded(true)..setAuthenticated(true)),
             databaseProvider.overrideWithValue(db),
        ],
        child: const MyApp(),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('Redirects to Onboarding when not onboarded', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
             sharedPreferencesProvider.overrideWithValue(sharedPreferences),
             authProvider.overrideWith((ref) => AuthNotifier(sharedPreferences)..setOnboarded(false)),
             databaseProvider.overrideWithValue(db),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Onboarding Screen'), findsOneWidget);
  });

  testWidgets('Redirects to Login when onboarded but not authenticated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
         overrides: [
             sharedPreferencesProvider.overrideWithValue(sharedPreferences),
             authProvider.overrideWith((ref) => AuthNotifier(sharedPreferences)..setOnboarded(true)..setAuthenticated(false)),
             databaseProvider.overrideWithValue(db),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Login Screen'), findsOneWidget);
  });

  testWidgets('Can navigate between tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
             sharedPreferencesProvider.overrideWithValue(sharedPreferences),
             authProvider.overrideWith((ref) => AuthNotifier(sharedPreferences)..setOnboarded(true)..setAuthenticated(true)),
             databaseProvider.overrideWithValue(db),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Home
    expect(find.text('Home'), findsWidgets);

    // Tap Budget tab
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    expect(find.text('Budget'), findsWidgets);

    // Tap Accounts tab
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsWidgets);

    // Tap Transactions tab
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsWidgets);

    // Tap Reports tab
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsWidgets);
  });
}
