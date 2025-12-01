import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences sharedPreferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  test('ThemeNotifier initializes with system theme when no preference saved', () {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
    );

    expect(container.read(themeProvider), ThemeMode.system);
  });

  test('ThemeNotifier initializes with saved theme', () async {
    await sharedPreferences.setString('theme_mode', 'ThemeMode.dark');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
    );

    expect(container.read(themeProvider), ThemeMode.dark);
  });

  test('ThemeNotifier updates theme and saves to preferences', () {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
    );

    container.read(themeProvider.notifier).setTheme(ThemeMode.light);

    expect(container.read(themeProvider), ThemeMode.light);
    expect(sharedPreferences.getString('theme_mode'), 'ThemeMode.light');
  });
}
