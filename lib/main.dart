import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/performance/performance_monitor.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/error_tracker.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    final sharedPreferences = await SharedPreferences.getInstance();

    AppConfig(
      environment: AppEnvironment.production,
      appTitle: 'LedgerZero',
      enableLogging: false,
    );

    // Crash reports are opt-in (Settings > Security > Privacy).
    LocalErrorReportingService.crashReportsEnabled =
        sharedPreferences.getBool(kCrashReportsEnabledKey) ?? false;
    ErrorTracker.init();

    if (kDebugMode || kProfileMode) {
      PerformanceMonitor.instance.startMonitoring();
    }

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    // Logging may not be set up yet: debug builds report to the developer
    // log; release builds stay silent.
    if (kDebugMode) {
      developer.log(
        'App initialization failed',
        name: 'LedgerZero',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
