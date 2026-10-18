import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/utils/log_level.dart';
import 'package:ledger_zero/data/models/log_entry.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

/// Application log.
///
/// Warnings and errors are always written to the local diagnostic log
/// ([LocalErrorReportingService]: scrubbed, on this device only, never
/// uploaded), so a release build can explain afterwards why something did
/// not happen. Debug and info lines are written only with
/// [AppConfig.enableLogging]. Nothing is persisted before [AppConfig] is
/// initialised (tests). The developer console (`dart:developer`) gets
/// everything in debug builds and only with logging enabled otherwise.
class Logger {
  static void log(
    String message, {
    String name = 'LedgerZero',
    Object? error,
    StackTrace? stackTrace,
    LogLevel level = LogLevel.info,
  }) {
    final enabled = _loggingEnabled;
    if (enabled == true || kDebugMode) {
      developer.log(message, name: name, error: error, stackTrace: stackTrace);
    }
    // Only a configured app (main.dart) persists: tests and early start-up
    // have no place to write to.
    if (enabled == true ||
        (enabled == false &&
            (level == LogLevel.warning || level == LogLevel.error))) {
      try {
        LocalErrorReportingService().log(
          LogEntry(
            timestamp: DateTime.now(),
            level: level,
            message: '[$name] $message',
            error: error?.toString(),
            stackTrace: stackTrace?.toString(),
          ),
        );
      } catch (_) {
        // Logging must never break the caller.
      }
    }
  }

  /// `null` while [AppConfig] is not initialised (tests, early start-up).
  static bool? get _loggingEnabled {
    try {
      return AppConfig.instance.enableLogging;
    } catch (_) {
      return null;
    }
  }

  static void debug(String message) {
    log(message, name: 'DEBUG', level: LogLevel.debug);
  }

  static void info(String message) {
    log(message, name: 'INFO', level: LogLevel.info);
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    log(
      message,
      name: 'WARNING',
      error: error,
      stackTrace: stackTrace,
      level: LogLevel.warning,
    );
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    log(
      message,
      name: 'ERROR',
      error: error,
      stackTrace: stackTrace,
      level: LogLevel.error,
    );
  }
}
