import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/money/money.dart';

String _clean(String s) => s.replaceAll(' ', ' ').replaceAll(' ', ' ');

void main() {
  group('MoneyFormatter', () {
    test('en / USD', () {
      final f = MoneyFormatter(locale: 'en', defaultCurrency: 'USD');
      expect(f.format(123450), r'$1,234.50');
      expect(f.format(-1250), r'-$12.50');
      expect(f.format(0), r'$0.00');
      expect(f.format(1250, signed: true), r'+$12.50');
    });

    test('de / EUR uses comma decimals and symbol after the number', () {
      final f = MoneyFormatter(locale: 'de', defaultCurrency: 'EUR');
      expect(_clean(f.format(123450)), '1.234,50 €');
      expect(_clean(f.format(-1250)), '-12,50 €');
    });

    test('number-format setting overrides the locale separators', () {
      final f = MoneyFormatter(
        locale: 'en',
        defaultCurrency: 'EUR',
        decimalSeparator: ',',
      );
      expect(f.format(123450), '€1.234,50');
      final g = MoneyFormatter(
        locale: 'de',
        defaultCurrency: 'EUR',
        decimalSeparator: '.',
      );
      expect(_clean(g.format(123450)), '1,234.50 €');
    });

    test('per-call currency overrides the default', () {
      final f = MoneyFormatter(locale: 'en', defaultCurrency: 'USD');
      expect(f.format(1250, currency: 'EUR'), '€12.50');
      expect(f.format(1250, currency: 'CHF'), contains('CHF'));
    });

    test('zero-decimal currencies are shown without decimals', () {
      final f = MoneyFormatter(locale: 'en', defaultCurrency: 'JPY');
      expect(f.format(123400), '¥1,234');
      expect(f.format(123450), '¥1,235'); // rounded for display only
      expect(f.format(-123450), '-¥1,235');
    });

    test('never shows negative zero', () {
      // 0.30 - 0.10 - 0.20 in minor units is exactly 0
      final f = MoneyFormatter(locale: 'en', defaultCurrency: 'USD');
      expect(f.format(30 - 10 - 20), r'$0.00');
    });

    test('formatForInput round-trips through the parser', () {
      for (final locale in ['en', 'de']) {
        final f = MoneyFormatter(locale: locale);
        for (final v in [0, 5, -5, 1250, -123456, 100000000]) {
          expect(f.parser.parse(f.formatForInput(v)), v);
        }
      }
      expect(MoneyFormatter(locale: 'de').formatForInput(1250), '12,50');
      expect(MoneyFormatter(locale: 'en').formatForInput(1250), '12.50');
    });

    test('formatNumber and formatCompact', () {
      final f = MoneyFormatter(locale: 'en', defaultCurrency: 'USD');
      expect(f.formatNumber(123450), '1,234.50');
      expect(f.formatCompact(123456700), r'$1.23M');
    });
  });
}
