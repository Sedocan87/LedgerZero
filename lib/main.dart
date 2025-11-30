import 'package:flutter/material.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/utils/error_tracker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig(
    environment: AppEnvironment.production,
    appTitle: 'LedgerZero',
    enableLogging: false,
  );

  ErrorTracker.init();

  runApp(const MyApp());
}
