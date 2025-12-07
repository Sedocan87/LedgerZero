import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('format uses default locale and settings with explicit symbol', () {
      // Force symbol to be deterministic
      final result = CurrencyFormatter.format(1234.56, locale: 'en_US', symbol: '\$');
      expect(result, '\$1,234.56');
    });

    test('format supports different locales (de_DE)', () {
      final result = CurrencyFormatter.format(1234.56, locale: 'de_DE', symbol: '€');
      // 1.234,56 € or 1.234,56€ depending on intl version
      // Just check the number format and presence of symbol
      expect(result, contains('1.234,56'));
      expect(result, contains('€'));
    });

    test('format supports negative numbers', () {
      final result = CurrencyFormatter.format(-50.0, locale: 'en_US', symbol: '\$');
      expect(result, '-\$50.00');
    });

    test('formatSimple handles currency codes', () {
      final result = CurrencyFormatter.formatSimple(100, currency: 'EUR');
      expect(result, contains('100.00'));
      // EUR might result in € or EUR depending on environment, checking number format mainly
    });

    test('formatCompact formats large numbers', () {
      final result = CurrencyFormatter.formatCompact(1500000, locale: 'en_US', symbol: '\$');
      expect(result, '\$1.5M');
    });

    test('format respects decimalDigits and rounds half-even/nearest', () {
      // 10.5 rounds to 10 (even) or 11 depending on exact impl.
      // 10.5 -> 10 or 11. Let's accept either valid rounding behavior or test unambiguous cases.
      // 10.6 -> 11
      final result = CurrencyFormatter.format(10.6, locale: 'en_US', decimalDigits: 0, symbol: '\$');
      expect(result, '\$11');

      final result2 = CurrencyFormatter.format(10.1, locale: 'en_US', decimalDigits: 0, symbol: '\$');
      expect(result2, '\$10');
    });

    test('format rounds correctly', () {
       final result = CurrencyFormatter.format(10.567, locale: 'en_US', decimalDigits: 2, symbol: '\$');
       expect(result, '\$10.57');
    });
  });
}
