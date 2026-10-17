import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  final bool isOnboarded;

  /// The UI is unlocked: the app lock was passed, or it is off. The
  /// database session ([sessionProvider]) is independent of this.
  final bool isAuthenticated;

  /// The UI was unlocked at least once since start-up (or since onboarding
  /// started again). From then on the app lock covers the app instead of
  /// replacing it, so the user returns to where they were.
  final bool hasUnlocked;

  const AuthState({
    this.isOnboarded = false,
    this.isAuthenticated = false,
    this.hasUnlocked = false,
  });

  /// The app lock is showing over the unlocked app (see [hasUnlocked]).
  bool get isRelocked => isOnboarded && hasUnlocked && !isAuthenticated;

  AuthState copyWith({
    bool? isOnboarded,
    bool? isAuthenticated,
    bool? hasUnlocked,
  }) {
    return AuthState(
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasUnlocked: hasUnlocked ?? this.hasUnlocked,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SharedPreferences _prefs;
  static const _onboardedKey = 'user_onboarded';

  AuthNotifier(this._prefs)
    : super(
        AuthState(
          isOnboarded: _prefs.getBool(_onboardedKey) ?? false,
          isAuthenticated: false,
        ),
      );

  /// Onboarding again (factory reset) starts a new UI session.
  void setOnboarded(bool value) {
    _prefs.setBool(_onboardedKey, value);
    state = state.copyWith(
      isOnboarded: value,
      hasUnlocked: value ? null : false,
    );
  }

  void setAuthenticated(bool value) {
    state = state.copyWith(
      isAuthenticated: value,
      hasUnlocked: value ? true : null,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(prefs);
});
