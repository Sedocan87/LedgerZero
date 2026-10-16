import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/money/money.dart';

void main() {
  const en = MoneyParser(decimalSeparator: '.');
  const de = MoneyParser(decimalSeparator: ',');

  group('MoneyParser accepts both decimal styles', () {
    for (final parser in [en, de]) {
      final label = 'decimal "${parser.decimalSeparator}"';
      test('$label: unambiguous inputs', () {
        expect(parser.parse('12,50'), 1250);
        expect(parser.parse('12.50'), 1250);
        expect(parser.parse('1.234,56'), 123456);
        expect(parser.parse('1,234.56'), 123456);
        expect(parser.parse('-12'), -1200);
        expect(parser.parse('12'), 1200);
        expect(parser.parse('€12,50'), 1250);
        expect(parser.parse('12,50 €'), 1250);
        expect(parser.parse(r'$1,234.56'), 123456);
        expect(parser.parse('EUR 12.50'), 1250);
        expect(parser.parse('-€12,50'), -1250);
        expect(parser.parse('€-12,50'), -1250);
        expect(parser.parse('12,50-'), -1250);
        expect(parser.parse('(12.50)'), -1250);
        expect(parser.parse('+7'), 700);
        expect(parser.parse('  0,5 '), 50);
        expect(parser.parse('.75'), 75);
        expect(parser.parse('1 234,56'), 123456);
        expect(parser.parse("1'234.56"), 123456);
        expect(parser.parse('1.234.567'), 123456700);
        expect(parser.parse('1,234,567.89'), 123456789);
        expect(parser.parse('0,001'), 0);
        expect(parser.parse('−5'), -500); // unicode minus
      });
    }

    test('ambiguous single separator with three digits follows locale', () {
      expect(en.parse('1,234'), 123400);
      expect(en.parse('1.234'), 123); // decimal in en, rounded
      expect(de.parse('1.234'), 123400);
      expect(de.parse('1,234'), 123);
    });

    test('rounds extra fraction digits half away from zero', () {
      expect(en.parse('12.345'), 1235);
      expect(en.parse('-12.345'), -1235);
      expect(de.parse('0,005'), 1);
    });
  });

  group('MoneyParser rejects garbage', () {
    for (final input in [
      '',
      '   ',
      'abc',
      '12abc',
      '1.2.3,4,5',
      '1,23,4',
      '--5',
      '-',
      '€',
      '12..5',
      '1e5',
      '12 34 5x',
      '1.234,56.78',
    ]) {
      test('"$input"', () {
        expect(en.tryParse(input), isNull);
        expect(de.tryParse(input), isNull);
        expect(() => en.parse(input), throwsFormatException);
      });
    }

    test('null', () {
      expect(en.tryParse(null), isNull);
    });
  });

  test('forLocale picks the locale decimal separator', () {
    expect(MoneyParser.forLocale('de').decimalSeparator, ',');
    expect(MoneyParser.forLocale('en').decimalSeparator, '.');
    expect(MoneyParser.forLocale(null).decimalSeparator, '.');
    expect(decimalSeparatorForLocale('de_DE'), ',');
  });
}
