import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class ErrorTracker {
  static void init() {
    // Catch Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      Logger.error(details.exceptionAsString(), details.exception, details.stack);
    };

    // Catch async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      Logger.error('Async error', error, stack);
      return true;
    };
  }

  static void track(Object error, [StackTrace? stack]) {
    Logger.error(error.toString(), error, stack);
  }
}
