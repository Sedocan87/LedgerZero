import 'dart:async';

/// Marks periods where the app deliberately hands the screen to the OS (file
/// picker, share sheet, biometric prompt, Google sign-in). The auto-lock
/// does not lock for the lifecycle changes those cause; once the last one
/// finishes it applies its policy to the state the app is then in.
class ExternalUiGuard {
  ExternalUiGuard._();

  static int _active = 0;
  static final StreamController<void> _ended = StreamController<void>.broadcast(
    sync: true,
  );

  static bool get isActive => _active > 0;

  /// Fires whenever the last active guard ends.
  static Stream<void> get onEnded => _ended.stream;

  static Future<T> run<T>(Future<T> Function() action) async {
    _active++;
    try {
      return await action();
    } finally {
      _active--;
      if (_active == 0) {
        _ended.add(null);
      }
    }
  }
}
