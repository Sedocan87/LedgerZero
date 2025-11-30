import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class ErrorTracker {
  static void init() {
    // Catch Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      Logger.error(details.exceptionAsString(), details.exception, details.stack);
      _writeErrorToFile(details.exceptionAsString(), details.stack);
    };

    // Catch async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      Logger.error('Async error', error, stack);
      _writeErrorToFile(error.toString(), stack);
      return true;
    };
  }

  static void track(Object error, [StackTrace? stack]) {
    Logger.error(error.toString(), error, stack);
    _writeErrorToFile(error.toString(), stack);
  }

  static Future<void> _writeErrorToFile(String error, StackTrace? stack) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/error_logs.txt');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString(
        '[$timestamp] $error\n$stack\n\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // Avoid infinite loop if logger fails or if path_provider fails (e.g. in tests)
      if (kDebugMode) {
        print('Failed to write error to file: $e');
      }
    }
  }
}
