import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/money/money.dart';

void main() {
  group('Money.fromMajor', () {
    test('converts integers exactly', () {
      expect(Money.fromMajor(12), 1200);
      expect(Money.fromMajor(-3), -300);
      expect(Money.fromMajor(0), 0);
    });

    test('avoids binary floating point error (0.1 + 0.2)', () {
      expect(0.1 + 0.2 == 0.3, isFalse);
      expect(Money.fromMajor(0.1 + 0.2), 30);
      expect(Money.fromMajor(0.1) + Money.fromMajor(0.2), 30);
    });

    test('rounds half away from zero', () {
      expect(Money.fromMajor(12.345), 1235);
      expect(Money.fromMajor(-12.345), -1235);
      expect(Money.fromMajor(1.005), 101);
      expect(Money.fromMajor(-1.005), -101);
      expect(Money.fromMajor(0.004), 0);
      expect(Money.fromMajor(-0.004), 0);
      expect(Money.fromMajor(0.005), 1);
      expect(Money.fromMajor(19.99), 1999);
    });

    test('handles exponent notation and large values', () {
      expect(Money.fromMajor(1e-7), 0);
      expect(Money.fromMajor(1.5e6), 150000000);
      expect(Money.fromMajor(12345678.91), 1234567891);
    });

    test('rejects non-finite values', () {
      expect(() => Money.fromMajor(double.nan), throwsArgumentError);
      expect(() => Money.fromMajor(double.infinity), throwsArgumentError);
    });
  });

  group('Money.fromDecimalString', () {
    test('parses plain decimals', () {
      expect(Money.fromDecimalString('12.50'), 1250);
      expect(Money.fromDecimalString('-0.07'), -7);
      expect(Money.fromDecimalString('+7'), 700);
      expect(Money.fromDecimalString('.5'), 50);
      expect(Money.fromDecimalString('2.675'), 268);
    });

    test('returns null for garbage', () {
      expect(Money.fromDecimalString(''), isNull);
      expect(Money.fromDecimalString('abc'), isNull);
      expect(Money.fromDecimalString('1,5'), isNull);
      expect(Money.fromDecimalString('.'), isNull);
    });
  });

  group('Money helpers', () {
    test('sum of integers is exact where double sums are not', () {
      // budgeted 0.30, activity -0.10 and -0.20: available must be exactly 0
      expect(0.30 + -0.10 + -0.20, isNot(0.0));
      expect(Money.sum([30, -10, -20]), 0);
    });

    test('toMajorDouble', () {
      expect(Money.toMajorDouble(1250), 12.5);
      expect(Money.toMajorDouble(-5), -0.05);
    });

    test('divideRounded rounds half away from zero', () {
      expect(Money.divideRounded(1000, 3), 333);
      expect(Money.divideRounded(1001, 2), 501);
      expect(Money.divideRounded(-1001, 2), -501);
      expect(Money.divideRounded(5, -2), -3);
      expect(() => Money.divideRounded(1, 0), throwsArgumentError);
    });

    test('toDecimalString', () {
      expect(Money.toDecimalString(1250), '12.50');
      expect(Money.toDecimalString(-5), '-0.05');
      expect(Money.toDecimalString(0), '0.00');
      expect(Money.toDecimalString(123456, decimalSeparator: ','), '1234,56');
    });
  });

  group('currencies', () {
    test('one list with decimal digits', () {
      expect(supportedCurrencyCodes, containsAll(['USD', 'EUR', 'JPY', 'CNY']));
      expect(
        supportedCurrencyCodes.toSet().length,
        supportedCurrencyCodes.length,
      );
      expect(currencyDecimalDigits('JPY'), 0);
      expect(currencyDecimalDigits('eur'), 2);
      expect(currencyDecimalDigits(null), 2);
    });
  });
}
