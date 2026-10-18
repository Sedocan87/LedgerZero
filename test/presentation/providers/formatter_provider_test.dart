import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _clean(String s) => s.replaceAll(' ', ' ');

void main() {
  test('follows the language by default (de -> decimal comma)', () {
    final fmt = AppFormatter.fromSettings(
      const SettingsState(currency: 'EUR', language: Locale('de')),
    );
    expect(fmt.decimalSeparator, ',');
    expect(_clean(fmt.formatMoney(123450)), '1.234,50 €');
    expect(fmt.formatAmountForInput(1250), '12,50');
    expect(fmt.parseAmount('12,50'), 1250);
    expect(fmt.parseAmount('12.50'), 1250);
    expect(fmt.parseAmount('abc'), isNull);
  });

  test('number-format setting overrides the language', () {
    final fmt = AppFormatter.fromSettings(
      const SettingsState(
        currency: 'USD',
        language: Locale('de'),
        numberFormat: AppNumberFormat.dot,
      ),
    );
    expect(fmt.decimalSeparator, '.');
    expect(fmt.formatAmountForInput(1250), '12.50');
  });

  test('device locales are used when no language is chosen', () {
    final fmt = AppFormatter.fromSettings(
      const SettingsState(),
      deviceLocales: const [Locale('de', 'AT')],
    );
    expect(fmt.locale, 'de');
    final fallback = AppFormatter.fromSettings(
      const SettingsState(),
      deviceLocales: const [Locale('fr')],
    );
    expect(fallback.locale, 'en');
  });

  test('the formatter follows the UI locale, not only the first device '
      'locale', () {
    // Device languages: French, then German. The UI shows German
    // (resolveAppLocale), so amounts must use the decimal comma too.
    const devices = [Locale('fr', 'FR'), Locale('de', 'DE')];
    expect(resolveAppLocale(null, devices), const Locale('de'));
    // No supported language on the device: English, not the first
    // supported locale.
    expect(resolveAppLocale(null, const [Locale('fr')]), const Locale('en'));
    expect(resolveAppLocale(null, const []), const Locale('en'));
    final fmt = AppFormatter.fromSettings(
      const SettingsState(currency: 'EUR'),
      deviceLocales: devices,
    );
    expect(fmt.locale, 'de');
    expect(fmt.decimalSeparator, ',');
    // The chosen language wins over every device locale.
    expect(resolveAppLocale(const Locale('en'), devices), const Locale('en'));
  });

  test('appFormatterProvider uses the resolved app locale', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocalesProvider.overrideWithValue(const [
          Locale('fr'),
          Locale('de'),
        ]),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(appLocaleProvider), const Locale('de'));
    expect(container.read(appFormatterProvider).locale, 'de');
    await container
        .read(settingsProvider.notifier)
        .setLanguage(const Locale('en'));
    expect(container.read(appFormatterProvider).locale, 'en');
  });

  test('date format and first day of week settings are honoured', () {
    final day = DateTime.utc(2024, 12, 31);
    String format(AppDateFormat f) =>
        AppFormatter.fromSettings(SettingsState(dateFormat: f)).formatDate(day);
    expect(format(AppDateFormat.iso8601), '2024-12-31');
    expect(format(AppDateFormat.european), '31.12.2024');
    expect(format(AppDateFormat.us), '12/31/2024');

    final monday = AppFormatter.fromSettings(
      const SettingsState(firstDayOfWeek: AppFirstDayOfWeek.monday),
    );
    // 2024-12-31 is a Tuesday.
    expect(monday.startOfWeek(day), DateTime.utc(2024, 12, 30));
    final sunday = AppFormatter.fromSettings(const SettingsState());
    expect(sunday.startOfWeek(day), DateTime.utc(2024, 12, 29));
  });

  test('calendar days are shown as stored, not shifted to local time', () {
    final fmt = AppFormatter.fromSettings(const SettingsState());
    expect(fmt.formatDate(DateTime.utc(2024, 1, 1)), '2024-01-01');
  });
}
