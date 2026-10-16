import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/error_tracker.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  AppConfig(
    environment: AppEnvironment.development,
    appTitle: 'LedgerZero Dev',
    enableLogging: true,
  );

  // Crash reports are opt-in (Settings > Security > Privacy).
  LocalErrorReportingService.crashReportsEnabled =
      sharedPreferences.getBool(kCrashReportsEnabledKey) ?? false;
  ErrorTracker.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}
