import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';

class ThemeState {
  final ThemeMode mode;
  final bool isHighContrast;
  final bool reducedMotion;

  const ThemeState({
    required this.mode,
    required this.isHighContrast,
    required this.reducedMotion,
  });

  ThemeState copyWith({
    ThemeMode? mode,
    bool? isHighContrast,
    bool? reducedMotion,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      isHighContrast: isHighContrast ?? this.isHighContrast,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _themeKey = 'theme_mode';
  static const String _highContrastKey = 'high_contrast_mode';
  static const String _reducedMotionKey = 'reduced_motion_mode';

  @override
  ThemeState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_themeKey);
    final isHighContrast = prefs.getBool(_highContrastKey) ?? false;
    final reducedMotion = prefs.getBool(_reducedMotionKey) ?? false;

    return ThemeState(
      mode: _getThemeModeFromString(savedTheme),
      isHighContrast: isHighContrast,
      reducedMotion: reducedMotion,
    );
  }

  void setTheme(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_themeKey, mode.toString());
  }

  void toggleHighContrast(bool value) {
    state = state.copyWith(isHighContrast: value);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_highContrastKey, value);
  }

  void toggleReducedMotion(bool value) {
    state = state.copyWith(reducedMotion: value);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_reducedMotionKey, value);
  }

  static bool shouldAnimate(BuildContext context, WidgetRef ref) {
    final reducedMotion = ref.read(themeProvider).reducedMotion;
    final systemReducedMotion = MediaQuery.of(context).disableAnimations;
    return !reducedMotion && !systemReducedMotion;
  }

  ThemeMode _getThemeModeFromString(String? themeString) {
    switch (themeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
