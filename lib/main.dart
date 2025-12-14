import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/performance/performance_monitor.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/error_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize SQLCipher on Android
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
      open.overrideFor(OperatingSystem.android, _openOnAndroid);
    }

    final sharedPreferences = await SharedPreferences.getInstance();

    AppConfig(
      environment: AppEnvironment.production,
      appTitle: 'LedgerZero',
      enableLogging: false,
    );

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
    // If initialization fails, print to console/log.
    // We can't use ErrorTracker fully if it failed to init, but we can try.
    if (kDebugMode) {
      print('CRITICAL: App initialization failed: $e');
      print(stack);
    }
    // Attempt to log using standard print or a fallback since native logging might be broken
    // if dependencies failed.
  }
}

DynamicLibrary _openOnAndroid() {
  try {
    return DynamicLibrary.open('libsqlcipher.so');
  } catch (e) {
    if (kDebugMode) {
      print('Failed to open libsqlcipher.so: $e');
    }
    rethrow;
  }
}
