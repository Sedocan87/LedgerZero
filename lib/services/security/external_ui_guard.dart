import 'dart:async';

import 'package:flutter/foundation.dart';

/// Marks periods where the app deliberately hands the screen to the OS (file
/// picker, share sheet, biometric prompt, Google sign-in). The auto-lock
/// does not lock for the lifecycle changes those cause; once the last one
/// finishes it applies its policy to the state the app is then in.
///
/// A guard ends when its action completes or after [timeout], whichever
/// comes first: a platform call that never answers must not switch the
/// auto-lock off for the rest of the process.
class ExternalUiGuard {
  ExternalUiGuard._();

  static int _active = 0;
  static final StreamController<void> _ended = StreamController<void>.broadcast(
    sync: true,
  );

  /// The longest an OS screen can keep the auto-lock waiting.
  static const Duration timeout = Duration(minutes: 2);

  /// Timer factory, replaceable in tests.
  @visibleForTesting
  static Timer Function(Duration, void Function()) timerFactory = Timer.new;

  static bool get isActive => _active > 0;

  /// Fires whenever the last active guard ends.
  static Stream<void> get onEnded => _ended.stream;

  static Future<T> run<T>(Future<T> Function() action) async {
    var ended = false;
    void end() {
      if (ended) {
        return;
      }
      ended = true;
      _active--;
      if (_active == 0) {
        _ended.add(null);
      }
    }

    _active++;
    final timer = timerFactory(timeout, end);
    try {
      return await action();
    } finally {
      timer.cancel();
      end();
    }
  }
}
