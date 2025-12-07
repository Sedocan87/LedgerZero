import 'dart:math';
import 'package:flutter/foundation.dart';

class RetryUtils {
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffFactor = 2.0,
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts || (shouldRetry != null && !shouldRetry(e))) {
          rethrow;
        }

        final delaySeconds = initialDelay.inSeconds * pow(backoffFactor, attempt - 1);
        final delay = Duration(seconds: delaySeconds.toInt());

        if (kDebugMode) {
          print('Retry attempt $attempt failed. Retrying in ${delay.inSeconds} seconds...');
        }

        await Future.delayed(delay);
      }
    }
  }
}
