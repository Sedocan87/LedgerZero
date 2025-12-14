import 'package:intl/intl.dart';

/// Centralized currency formatting logic for LedgerZero.
class CurrencyFormatter {
  /// Formats the given amount as a currency string.
  ///
  /// [amount]: The numeric amount to format.
  /// [locale]: The locale to use for formatting (e.g., 'en_US', 'de_DE').
  /// [symbol]: Optional currency symbol override. If null, uses locale default.
  /// [decimalDigits]: Number of decimal places (default 2).
  static String format(
    double amount, {
    String? locale,
    String? symbol,
    int decimalDigits = 2,
  }) {
    final format = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return format.format(amount);
  }

  /// Formats the amount strictly with 2 decimal places and symbol.
  /// Useful for inputs or strict displays.
  static String formatSimple(double amount, {String? currency}) {
    return NumberFormat.simpleCurrency(name: currency).format(amount);
  }

  /// Formats compact currency (e.g., $1.2M).
  static String formatCompact(double amount, {String? locale, String? symbol}) {
    final format = NumberFormat.compactCurrency(locale: locale, symbol: symbol);
    return format.format(amount);
  }
}
