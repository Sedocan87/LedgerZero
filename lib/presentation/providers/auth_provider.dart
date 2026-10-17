import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  final bool isOnboarded;

  /// The UI is unlocked: the app lock was passed, or it is off. The
  /// database session ([sessionProvider]) is independent of this.
  final bool isAuthenticated;

  const AuthState({this.isOnboarded = false, this.isAuthenticated = false});

  AuthState copyWith({bool? isOnboarded, bool? isAuthenticated}) {
    return AuthState(
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
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

  void setOnboarded(bool value) {
    _prefs.setBool(_onboardedKey, value);
    state = state.copyWith(isOnboarded: value);
  }

  void setAuthenticated(bool value) {
    state = state.copyWith(isAuthenticated: value);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(prefs);
});
