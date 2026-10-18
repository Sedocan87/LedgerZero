import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Key for SharedPreferences
const String kAutoLockDurationKey = 'auto_lock_duration_minutes';

/// Shows the app lock again when the app has been in the background for
/// the configured time. Only the UI is locked ([AuthState.isAuthenticated]);
/// the database stays open, so sync and card capture keep working. Does
/// nothing while the app lock is off or onboarding is not finished.
///
/// * `0` (immediate): locks as soon as the app is `hidden` or `paused` (it
///   left the screen). `inactive` alone does not lock: it also means the
///   notification shade, a system dialog or the app switcher is over the
///   app, which FLAG_SECURE and the privacy shield already cover.
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
  Timer? _graceTimer;

  /// How long to wait for `resumed` after an OS screen closed. A full-screen
  /// OS activity (the device PIN screen of the app lock) reports its result
  /// before the app is resumed; without the grace period the app would lock
  /// again right after a successful unlock. Three seconds: a slow PIN
  /// screen on a busy phone can take more than one to hand back.
  static const Duration resumeGrace = Duration(seconds: 3);
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
      if (state == null || state == AppLifecycleState.resumed) {
        return;
      }
      _graceTimer?.cancel();
      _graceTimer = _timerFactory(resumeGrace, () {
        _graceTimer = null;
        final now = _lastState;
        if (now != null &&
            now != AppLifecycleState.resumed &&
            !ExternalUiGuard.isActive) {
          didChangeAppLifecycleState(now);
        }
      });
    });
  }

  int get _duration => _ref.read(autoLockDurationProvider);

  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        _graceTimer?.cancel();
        _graceTimer = null;
        _onForeground();
      case AppLifecycleState.inactive:
        break;
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
    final auth = _ref.read(authProvider);
    if (!_ref.read(appLockEnabledProvider) ||
        !auth.isOnboarded ||
        !auth.isAuthenticated) {
      return;
    }
    _ref.read(authProvider.notifier).setAuthenticated(false);
  }

  void dispose() {
    _timer?.cancel();
    _graceTimer?.cancel();
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
    : super(_prefs.getInt(kAutoLockDurationKey) ?? defaultMinutes);

  /// Until the user picks one: a quick look at another app does not lock.
  static const int defaultMinutes = 1;

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
