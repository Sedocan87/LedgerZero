import 'package:flutter/scheduler.dart';
import 'package:ledger_zero/core/utils/logger.dart';

/// Monitoring service that logs frame build times exceeding 16ms (60fps threshold).
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  static PerformanceMonitor get instance => _instance;

  bool _isMonitoring = false;

  PerformanceMonitor._internal();

  void startMonitoring() {
    if (_isMonitoring) {
      return;
    }

    Logger.debug('Starting performance monitor');
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _isMonitoring = true;
  }

  void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _isMonitoring = false;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final duration = timing.totalSpan.inMilliseconds;
      if (duration > 16) {
        // Log dropped frame (or slow frame)
        // We use a simplified log format to avoid spamming
        Logger.warning('Slow frame detected: ${duration}ms');
      }
    }
  }
}
