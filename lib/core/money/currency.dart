import 'package:intl/intl.dart';

/// The currencies LedgerZero offers in its pickers.
///
/// Every amount is stored as an `int` of hundredths of the currency unit
/// ("minor units", fixed scale 100) regardless of the currency. Currencies
/// without a minor unit (JPY) are stored the same way and only *displayed*
/// with [decimalDigits] = 0.
class SupportedCurrency {
  /// ISO 4217 code, e.g. `EUR`.
  final String code;

  /// Number of fraction digits shown when formatting.
  final int decimalDigits;

  const SupportedCurrency(this.code, {this.decimalDigits = 2});

  @override
  String toString() => code;
}

/// The single list of currencies used by Settings and the account editor.
const List<SupportedCurrency> supportedCurrencies = [
  SupportedCurrency('USD'),
  SupportedCurrency('EUR'),
  SupportedCurrency('GBP'),
  SupportedCurrency('CHF'),
  SupportedCurrency('CAD'),
  SupportedCurrency('AUD'),
  SupportedCurrency('CNY'),
  SupportedCurrency('JPY', decimalDigits: 0),
];

/// Codes of [supportedCurrencies], in display order.
final List<String> supportedCurrencyCodes = [
  for (final c in supportedCurrencies) c.code,
];

/// The currency used when nothing else is known.
const String defaultCurrencyCode = 'USD';

/// Fraction digits to display for [code]. Unknown codes use 2.
int currencyDecimalDigits(String? code) {
  if (code == null) {
    return 2;
  }
  final upper = code.toUpperCase();
  for (final c in supportedCurrencies) {
    if (c.code == upper) {
      return c.decimalDigits;
    }
  }
  // A few well known zero-decimal currencies outside the supported list,
  // so imported accounts in those currencies still display sensibly.
  const zeroDecimal = {'KRW', 'VND', 'ISK', 'CLP', 'HUF', 'TWD', 'UGX'};
  return zeroDecimal.contains(upper) ? 0 : 2;
}

/// The budget currency to propose on a fresh install: the currency of the
/// first device locale (in the user's order, e.g. `de_DE` -> EUR, `en_US`
/// -> USD, `de_CH` -> CHF) whose currency the app supports, else
/// [defaultCurrencyCode]. A locale without a country uses the language's
/// default country (`de` -> EUR). [localeTags] are `Locale.toString()`
/// values (`de_DE`); unparseable tags are skipped.
String defaultCurrencyForLocales(Iterable<String> localeTags) {
  for (final tag in localeTags) {
    final String? code;
    try {
      code = NumberFormat.simpleCurrency(locale: tag).currencyName;
    } catch (_) {
      continue;
    }
    if (code != null && supportedCurrencyCodes.contains(code.toUpperCase())) {
      return code.toUpperCase();
    }
  }
  return defaultCurrencyCode;
}
