import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Key for SharedPreferences
const String kAutoLockDurationKey = 'auto_lock_duration_minutes';

/// Locks the session (closes the database, zeroes the key) when the app has
/// been in the background for the configured time.
///
/// * `0` (immediate): locks as soon as the app becomes `inactive`, `hidden`
///   or `paused`, so the app switcher never shows an unlocked app.
/// * `n > 0` minutes: a timer locks after `n` minutes in the background
///   (while the process runs); on resume the elapsed time is checked again.
///   The elapsed time is the larger of a monotonic [Stopwatch] and the wall
///   clock: moving the clock back cannot extend the session, and device
///   sleep (which some monotonic clocks skip) is still counted.
/// * `-1` (never): no automatic lock.
///
/// OS screens opened by the app itself ([ExternalUiGuard]) do not lock.
class AutoLockService {
  final Ref _ref;
  final DateTime Function() _now;
  final Stopwatch _stopwatch;
  final Timer Function(Duration, void Function()) _timerFactory;

  bool _inBackground = false;
  DateTime? _backgroundedAt;
  Timer? _timer;
  StreamSubscription<void>? _guardSubscription;
  AppLifecycleState? _lastState;

  AutoLockService(
    this._ref, {
    DateTime Function()? now,
    Stopwatch? stopwatch,
    Timer Function(Duration, void Function())? timerFactory,
  }) : _now = now ?? DateTime.now,
       _stopwatch = stopwatch ?? Stopwatch(),
       _timerFactory = timerFactory ?? Timer.new {
    _guardSubscription = ExternalUiGuard.onEnded.listen((_) {
      final state = _lastState;
      if (state != null && state != AppLifecycleState.resumed) {
        didChangeAppLifecycleState(state);
      }
    });
  }

  int get _duration => _ref.read(autoLockDurationProvider);

  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        _onForeground();
      case AppLifecycleState.inactive:
        if (_duration == 0) {
          _onBackground();
        }
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _onBackground();
      case AppLifecycleState.detached:
        unawaited(lock());
    }
  }

  void _onBackground() {
    if (ExternalUiGuard.isActive) {
      return;
    }
    if (!_inBackground) {
      _inBackground = true;
      _backgroundedAt = _now();
      _stopwatch
        ..reset()
        ..start();
    }
    final duration = _duration;
    if (duration < 0) {
      return;
    }
    if (duration == 0) {
      unawaited(lock());
      return;
    }
    _timer ??= _timerFactory(
      Duration(minutes: duration),
      () => unawaited(lock()),
    );
  }

  void _onForeground() {
    _timer?.cancel();
    _timer = null;
    if (!_inBackground) {
      return;
    }
    _inBackground = false;
    _stopwatch.stop();
    final duration = _duration;
    if (duration > 0 && elapsedInBackground >= Duration(minutes: duration)) {
      unawaited(lock());
    }
  }

  /// Time since the app went to the background (see class doc).
  @visibleForTesting
  Duration get elapsedInBackground {
    final monotonic = _stopwatch.elapsed;
    final since = _backgroundedAt;
    if (since == null) {
      return monotonic;
    }
    final wall = _now().difference(since);
    return wall > monotonic ? wall : monotonic;
  }

  Future<void> lock() async {
    _timer?.cancel();
    _timer = null;
    if (_ref.read(sessionProvider).isUnlocked) {
      await _ref.read(sessionProvider.notifier).lock();
    }
  }

  void dispose() {
    _timer?.cancel();
    _guardSubscription?.cancel();
  }
}

final autoLockServiceProvider = Provider<AutoLockService>((ref) {
  final service = AutoLockService(ref);
  ref.onDispose(service.dispose);
  return service;
});

// Provider for the duration setting
class AutoLockDurationNotifier extends StateNotifier<int> {
  final SharedPreferences _prefs;

  AutoLockDurationNotifier(this._prefs)
    : super(
        _prefs.getInt(kAutoLockDurationKey) ?? 0,
      ); // Default to Immediate (0)

  Future<void> setDuration(int minutes) async {
    await _prefs.setInt(kAutoLockDurationKey, minutes);
    state = minutes;
  }
}

final autoLockDurationProvider =
    StateNotifierProvider<AutoLockDurationNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return AutoLockDurationNotifier(prefs);
    });
