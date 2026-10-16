import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

class ErrorTracker {
  static void init() {
    // Catch Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      Logger.error(
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      _reportCrash(details.exception, details.stack);
    };

    // Catch async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      Logger.error('Async error', error, stack);
      _reportCrash(error, stack);
      return true;
    };
  }

  static void track(Object error, [StackTrace? stack]) {
    Logger.error(error.toString(), error, stack);
  }

  /// Uncaught errors become local crash reports only when the user turned
  /// crash reports on (Settings > Security > Privacy); the service checks
  /// [LocalErrorReportingService.crashReportsEnabled] and scrubs the text.
  static void _reportCrash(Object error, StackTrace? stack) {
    LocalErrorReportingService().generateCrashReport(error, stack);
  }
}
