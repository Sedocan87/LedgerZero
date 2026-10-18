import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outcome of [AppLockAuthenticator.authenticate].
enum AppLockResult {
  success,

  /// The user dismissed the prompt.
  cancelled,

  /// The device has no screen lock any more (the native side checks
  /// `KeyguardManager.isDeviceSecure`); the app lock cannot work.
  unavailable,

  /// Too many attempts, a sensor that is not available right now, or
  /// another error ([AppLockAuthenticator.lastFailure]); the app stays
  /// locked and the user can try again.
  failed,
}

/// The system prompt for a fingerprint/face or the device PIN, pattern or
/// password (Android `BiometricPrompt`, native code in
/// android/app/src/main/kotlin/com/ledgerzero/app/AppLockChannel.kt).
///
/// The app lock gates the UI; it is not tied to the database key.
abstract class AppLockAuthenticator {
  /// Whether the device can show the prompt (it has a screen lock).
  Future<bool> canAuthenticate();

  Future<AppLockResult> authenticate({required String title, String? subtitle});

  /// The system's reason for the last [AppLockResult.failed], if any.
  String? get lastFailure;
}

class PlatformAppLockAuthenticator implements AppLockAuthenticator {
  PlatformAppLockAuthenticator({bool? isAndroid})
    : _isAndroid = isAndroid ?? Platform.isAndroid;

  static const _channel = MethodChannel('com.ledgerzero.app/app_lock');

  final bool _isAndroid;

  @override
  String? lastFailure;

  @override
  Future<bool> canAuthenticate() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('canAuthenticate') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<AppLockResult> authenticate({
    required String title,
    String? subtitle,
  }) async {
    if (!_isAndroid) {
      return AppLockResult.unavailable;
    }
    try {
      await _channel.invokeMethod<bool>('authenticate', {
        'title': title,
        'subtitle': subtitle,
      });
      lastFailure = null;
      return AppLockResult.success;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'cancelled':
          return AppLockResult.cancelled;
        case 'unavailable':
          // Only reported without a screen lock (AppLockChannel.kt).
          return AppLockResult.unavailable;
        default:
          lastFailure = e.message ?? e.code;
          return AppLockResult.failed;
      }
    } on MissingPluginException {
      // A build without the native channel must not unlock without asking.
      lastFailure = 'app lock channel missing';
      return AppLockResult.failed;
    }
  }
}

final appLockAuthenticatorProvider = Provider<AppLockAuthenticator>(
  (ref) => PlatformAppLockAuthenticator(),
);

/// SharedPreferences flag: the app lock is on.
const String kAppLockEnabledKey = 'app_lock_enabled';

/// Whether the app asks for the fingerprint/face or device PIN when it
/// starts and after the auto-lock time. Off until the user turns it on
/// (onboarding offers it).
class AppLockEnabledNotifier extends StateNotifier<bool> {
  AppLockEnabledNotifier(this._prefs)
    : super(_prefs.getBool(kAppLockEnabledKey) ?? false);

  final SharedPreferences _prefs;

  Future<void> set(bool enabled) async {
    await _prefs.setBool(kAppLockEnabledKey, enabled);
    state = enabled;
  }
}

final appLockEnabledProvider =
    StateNotifierProvider<AppLockEnabledNotifier, bool>(
      (ref) => AppLockEnabledNotifier(ref.watch(sharedPreferencesProvider)),
    );
