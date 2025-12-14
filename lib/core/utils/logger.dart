import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/utils/log_level.dart';
import 'package:ledger_zero/data/models/log_entry.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

class Logger {
  static void log(
    String message, {
    String name = 'LedgerZero',
    Object? error,
    StackTrace? stackTrace,
    LogLevel level = LogLevel.info,
  }) {
    try {
      if (AppConfig.instance.enableLogging) {
        developer.log(
          message,
          name: name,
          error: error,
          stackTrace: stackTrace,
        );

        LocalErrorReportingService().log(
          LogEntry(
            timestamp: DateTime.now(),
            level: level,
            message: '[$name] $message',
            error: error?.toString(),
            stackTrace: stackTrace?.toString(),
          ),
        );
      }
    } catch (_) {
      // Fallback if AppConfig is not initialized or other error
      if (kDebugMode) {
        print('[$name] $message');
        if (error != null) {
          print(error);
        }
      }
    }
  }

  static void debug(String message) {
    log(message, name: 'DEBUG', level: LogLevel.debug);
  }

  static void info(String message) {
    log(message, name: 'INFO', level: LogLevel.info);
  }

  static void warning(String message) {
    log(message, name: 'WARNING', level: LogLevel.warning);
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
