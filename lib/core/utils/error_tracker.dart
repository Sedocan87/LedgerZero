import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

class ErrorTracker {
  static void init() {
    // Catch Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      Logger.error(details.exceptionAsString(), details.exception, details.stack);
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

  static void _reportCrash(Object error, StackTrace? stack) {
    // We might want to filter what counts as a "Crash" vs just an error log.
    // For now, let's treat uncaught exceptions as crashes.
    LocalErrorReportingService().generateCrashReport(error, stack);
  }
}
