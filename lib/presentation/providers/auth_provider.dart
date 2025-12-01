import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isOnboarded;
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
  // Default to false to verify guards.
  AuthNotifier() : super(const AuthState(isOnboarded: false, isAuthenticated: false));

  void setOnboarded(bool value) {
    state = state.copyWith(isOnboarded: value);
  }

  void setAuthenticated(bool value) {
    state = state.copyWith(isAuthenticated: value);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
