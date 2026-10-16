import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> container([
    Map<String, Object> saved = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'defaults: follow the system, no high contrast, animations on',
    () async {
      final state = (await container()).read(themeProvider);
      expect(state.mode, ThemeMode.system);
      expect(state.isHighContrast, isFalse);
      expect(state.reducedMotion, isFalse);
    },
  );

  test('restores the saved settings', () async {
    final state = (await container({
      'theme_mode': 'ThemeMode.dark',
      'high_contrast_mode': true,
      'reduced_motion_mode': true,
    })).read(themeProvider);
    expect(state.mode, ThemeMode.dark);
    expect(state.isHighContrast, isTrue);
    expect(state.reducedMotion, isTrue);
  });

  test('an unknown saved value falls back to the system mode', () async {
    final c = await container({'theme_mode': 'purple'});
    expect(c.read(themeProvider).mode, ThemeMode.system);
  });

  test('changes are applied and survive a restart', () async {
    final c = await container();
    c.read(themeProvider.notifier)
      ..setTheme(ThemeMode.light)
      ..toggleHighContrast(true)
      ..toggleReducedMotion(true);
    expect(c.read(themeProvider).mode, ThemeMode.light);

    // A new container reads what was persisted.
    final prefs = c.read(sharedPreferencesProvider);
    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    final state = restarted.read(themeProvider);
    expect(state.mode, ThemeMode.light);
    expect(state.isHighContrast, isTrue);
    expect(state.reducedMotion, isTrue);
  });
}
