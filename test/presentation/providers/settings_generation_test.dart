// After a factory reset cleared SharedPreferences, the preference-backed
// notifiers reload instead of keeping their in-memory state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/privacy_settings_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/providers/theme_provider.dart';
import 'package:ledger_zero/presentation/providers/tutorial_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'user_onboarded': true});
    prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    // Keep the notifiers alive as the app does.
    for (final p in <ProviderListenable<Object?>>[
      settingsProvider,
      themeProvider,
      tutorialProvider,
      privacySettingsProvider,
    ]) {
      c.listen(p, (_, _) {});
    }
    await c.read(settingsProvider.notifier).setCurrency('CHF');
    c.read(themeProvider.notifier).setTheme(ThemeMode.dark);
    await c.read(tutorialProvider.notifier).completeTutorial('budget');
    await c.read(privacySettingsProvider.notifier).setNotificationAmounts(true);
  });

  void expectReloaded() {
    expect(c.read(settingsProvider).currency, isNot('CHF'));
    expect(c.read(themeProvider).mode, ThemeMode.system);
    expect(c.read(tutorialProvider), isEmpty);
    expect(c.read(privacySettingsProvider).notificationAmounts, isFalse);
  }

  test('without a reload the notifiers keep the old values', () async {
    await prefs.clear();
    expect(c.read(settingsProvider).currency, 'CHF');
    expect(c.read(themeProvider).mode, ThemeMode.dark);
  });

  test('an explicit bump reloads every notifier', () async {
    await prefs.clear();
    c.read(settingsGenerationProvider.notifier).bump();
    expectReloaded();
  });

  test('undoing onboarding (a factory reset) reloads every notifier', () async {
    await prefs.clear();
    c.read(authProvider.notifier).setOnboarded(false);
    expectReloaded();
  });
}
