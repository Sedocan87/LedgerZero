import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/app/startup_error_app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/performance/performance_monitor.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/error_tracker.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/demo/demo_data.dart';
import 'package:ledger_zero/demo/demo_mode.dart';
import 'package:ledger_zero/services/backup/transferred_install.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The start-up shared by every entry point (`main.dart` and the
/// `main_<flavor>.dart` files): on failure it shows [StartupErrorApp],
/// whose Retry runs it again (every step is safe to repeat).
///
/// [loadPreferences], [noBackupDirectory] and [run] are seams for tests.
Future<void> bootstrap(
  AppEnvironment environment, {
  @visibleForTesting
  Future<SharedPreferences> Function() loadPreferences =
      SharedPreferences.getInstance,
  @visibleForTesting
  Future<Directory?> Function() noBackupDirectory =
      TransferredInstall.platformNoBackupDirectory,
  @visibleForTesting void Function(Widget app) run = runApp,
}) async {
  Future<void> retry() => bootstrap(
    environment,
    loadPreferences: loadPreferences,
    noBackupDirectory: noBackupDirectory,
    run: run,
  );
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Store screenshots: fresh sample data, nothing of the user's
    // (lib/demo/demo_mode.dart; inert unless built with LEDGERZERO_DEMO).
    if (kDemoMode) {
      await ensureDemoInstall();
    }
    final sharedPreferences = kDemoMode
        ? await prepareDemoPreferences()
        : await loadPreferences();

    AppConfig(
      environment: environment,
      appTitle: switch (environment) {
        AppEnvironment.development => 'LedgerZero Dev',
        AppEnvironment.staging => 'LedgerZero Staging',
        AppEnvironment.production => 'LedgerZero',
      },
      enableLogging: environment != AppEnvironment.production,
    );

    // Crash reports are opt-in (Settings > Security > Privacy).
    LocalErrorReportingService.crashReportsEnabled =
        sharedPreferences.getBool(kCrashReportsEnabledKey) ?? false;
    ErrorTracker.init();

    if (kDebugMode || kProfileMode) {
      PerformanceMonitor.instance.startMonitoring();
    }

    if (kDemoMode) {
      final container = ProviderContainer(
        overrides: demoOverrides(sharedPreferences, demoDatabase()),
      );
      await seedDemoData(container);
      run(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      return;
    }

    // Before anything reads the sync device id: an install that Android
    // moved here from another phone becomes a device of its own.
    await TransferredInstall.checkAtStartup(
      sharedPreferences,
      noBackupDirectory: noBackupDirectory,
      databaseFile: databaseFile,
    );

    run(
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
    // Not a black screen: say what happened and offer to try again.
    run(StartupErrorApp(onRetry: () => retry()));
  }
}
