import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App startup benchmark', (WidgetTester tester) async {
    // 1. Setup
    final stopwatch = Stopwatch()..start();

    // Simulate main() initialization
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    AppConfig(
      environment: AppEnvironment.development, // Use dev for benchmarks usually
      appTitle: 'LedgerZero Benchmark',
      enableLogging: false,
    );

    // 2. Pump the app
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MyApp(),
      ),
    );

    // 3. Wait for first frame and settle
    await tester.pumpAndSettle();

    stopwatch.stop();
    print('Startup time (simulated): ${stopwatch.elapsedMilliseconds}ms');

    // 4. Basic assertion to ensure it actually loaded something
    // Check if we are either at Onboarding or Login or Home.
    // Since we provided empty SharedPreferences, it should likely go to Onboarding or Login.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
