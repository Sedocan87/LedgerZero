import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/config/app_config.dart';

class Logger {
  static void log(String message, {String name = 'LedgerZero', Object? error, StackTrace? stackTrace}) {
    try {
      if (AppConfig.instance.enableLogging) {
        developer.log(
          message,
          name: name,
          error: error,
          stackTrace: stackTrace,
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
    log(message, name: 'DEBUG');
  }

  static void info(String message) {
    log(message, name: 'INFO');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    log(message, name: 'ERROR', error: error, stackTrace: stackTrace);
  }
}
