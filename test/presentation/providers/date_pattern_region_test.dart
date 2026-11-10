import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';

void main() {
  group('the "follow language" date pattern', () {
    test('English follows the region', () {
      expect(datePatternFor('en', 'US'), 'MM/dd/yyyy');
      expect(datePatternFor('en', 'GB'), 'dd/MM/yyyy');
      expect(datePatternFor('en', 'IE'), 'dd/MM/yyyy');
      expect(datePatternFor('en', 'AU'), 'dd/MM/yyyy');
      expect(datePatternFor('en', 'IN'), 'dd/MM/yyyy');
      expect(datePatternFor('en', 'CA'), 'yyyy-MM-dd');
      expect(datePatternFor('en', null), 'MM/dd/yyyy');
    });

    test('German is dd.MM.yyyy in every region', () {
      expect(datePatternFor('de', 'DE'), 'dd.MM.yyyy');
      expect(datePatternFor('de', 'CH'), 'dd.MM.yyyy');
      expect(datePatternFor('de', 'AT'), 'dd.MM.yyyy');
    });

    test('the region comes from the first device locale in that language', () {
      const locales = [Locale('de', 'DE'), Locale('en', 'GB')];
      expect(deviceRegionFor('en', locales), 'GB');
      expect(deviceRegionFor('de', locales), 'DE');
      // No device locale in English: the first locale's region.
      expect(deviceRegionFor('en', const [Locale('tr', 'TR')]), 'TR');
      expect(deviceRegionFor('en', const []), isNull);
    });

    test('a UK phone in English formats 10 November as 10/11/2026', () {
      final formatter = AppFormatter.fromSettings(
        const SettingsState(dateFormat: AppDateFormat.system),
        deviceLocales: const [Locale('en', 'GB')],
      );
      expect(formatter.formatDate(DateTime.utc(2026, 11, 10)), '10/11/2026');
    });

    test('an explicit choice still wins', () {
      final formatter = AppFormatter.fromSettings(
        const SettingsState(dateFormat: AppDateFormat.iso8601),
        deviceLocales: const [Locale('en', 'GB')],
      );
      expect(formatter.formatDate(DateTime.utc(2026, 11, 10)), '2026-11-10');
    });
  });
}
