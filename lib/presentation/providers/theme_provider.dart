import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';

class ThemeState {
  final ThemeMode mode;
  final bool isHighContrast;

  const ThemeState({
    required this.mode,
    required this.isHighContrast,
  });

  ThemeState copyWith({ThemeMode? mode, bool? isHighContrast}) {
    return ThemeState(
      mode: mode ?? this.mode,
      isHighContrast: isHighContrast ?? this.isHighContrast,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _themeKey = 'theme_mode';
  static const String _highContrastKey = 'high_contrast_mode';

  @override
  ThemeState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_themeKey);
    final isHighContrast = prefs.getBool(_highContrastKey) ?? false;

    return ThemeState(
      mode: _getThemeModeFromString(savedTheme),
      isHighContrast: isHighContrast,
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
