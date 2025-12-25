import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Key for SharedPreferences
const String kAutoLockDurationKey = 'auto_lock_duration_minutes';

class AutoLockService {
  final Ref _ref;
  DateTime? _pausedTime;

  /// Set this to true before opening file picker or similar operations
  /// that temporarily background the app but shouldn't trigger re-lock.
  bool bypassNextPause = false;

  AutoLockService(this._ref);

  void onAppPaused() {
    // If bypass is set, skip this pause cycle
    if (bypassNextPause) {
      bypassNextPause = false;
      return;
    }

    _pausedTime = DateTime.now();

    // If immediate lock (duration == 0), lock now.
    final duration = _ref.read(autoLockDurationProvider);
    if (duration == 0) {
      _lockApp();
    }
  }

  void onAppResumed() {
    if (_pausedTime == null) {
      return;
    }

    final duration = _ref.read(autoLockDurationProvider);

    // If "Never" (-1), don't lock.
    if (duration == -1) {
      _pausedTime = null;
      return;
    }

    // If "Immediate" (0), we already locked on pause.
    if (duration == 0) {
      _pausedTime = null;
      return;
    }

    // Check elapsed time since pause
    final now = DateTime.now();
    final elapsed = now.difference(_pausedTime!);

    if (elapsed.inMinutes >= duration) {
      _lockApp();
    }

    _pausedTime = null;
  }

  void _lockApp() {
    // Lock database
    SecurityManager.setSessionKey(null);
    // Update auth state
    if (_ref.read(authProvider).isAuthenticated) {
      ref.read(authProvider.notifier).setAuthenticated(false);
    }
  }

  // Getter for the Ref to use inside _lockApp (since it's an instance method)
  Ref get ref => _ref;
}

final autoLockServiceProvider = Provider<AutoLockService>((ref) {
  return AutoLockService(ref);
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
