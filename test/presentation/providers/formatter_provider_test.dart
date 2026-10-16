import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

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

  test('platform locale is used when no language is chosen', () {
    final fmt = AppFormatter.fromSettings(
      const SettingsState(),
      platformLocale: const Locale('de', 'AT'),
    );
    expect(fmt.locale, 'de');
    final fallback = AppFormatter.fromSettings(
      const SettingsState(),
      platformLocale: const Locale('fr'),
    );
    expect(fallback.locale, 'en');
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
