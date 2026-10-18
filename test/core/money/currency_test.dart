import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/money/currency.dart';

void main() {
  test('defaultCurrencyForLocales follows the first supported locale', () {
    expect(defaultCurrencyForLocales(['de_DE']), 'EUR');
    expect(defaultCurrencyForLocales(['fr_CH']), 'CHF');
    expect(defaultCurrencyForLocales(['ja_JP']), 'JPY');
    expect(defaultCurrencyForLocales(['en_CA', 'en_US']), 'CAD');
    // Unsupported (BRL) is skipped; an invalid tag too.
    expect(defaultCurrencyForLocales(['pt_BR', 'und', 'en_AU']), 'AUD');
    expect(defaultCurrencyForLocales(['pt_BR']), defaultCurrencyCode);
    expect(defaultCurrencyForLocales([]), defaultCurrencyCode);
  });
}
