import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';

  @override
  ThemeMode build() {
    // We access sharedPreferencesProvider to load the initial state.
    // Since this is synchronous, and SharedPreferences is async,
    // we rely on the provider being overridden with an initialized instance.
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_themeKey);
    return _getThemeModeFromString(savedTheme);
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_themeKey, mode.toString());
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

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
