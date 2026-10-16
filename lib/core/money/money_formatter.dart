import 'package:intl/intl.dart';
import 'package:ledger_zero/core/money/money.dart';

/// Formats minor-unit amounts for display.
///
/// The number pattern (symbol position, spacing) comes from [locale]; the
/// decimal and grouping separators come from [decimalSeparator] so the
/// user's "number format" setting is honoured independently of language.
class MoneyFormatter {
  /// Locale used for the currency pattern, e.g. `en` or `de`.
  final String locale;

  /// Currency used when a call does not pass one.
  final String defaultCurrency;

  /// `.` or `,`.
  final String decimalSeparator;

  /// The grouping separator implied by [decimalSeparator].
  String get groupSeparator => decimalSeparator == ',' ? '.' : ',';

  MoneyFormatter({
    required this.locale,
    this.defaultCurrency = defaultCurrencyCode,
    String? decimalSeparator,
  }) : decimalSeparator = decimalSeparator ?? decimalSeparatorForLocale(locale);

  /// The parser matching this formatter's decimal separator.
  MoneyParser get parser => MoneyParser(decimalSeparator: decimalSeparator);

  static const String _placeholder = '';

  final Map<String, NumberFormat> _currencyFormats = {};
  final Map<String, NumberFormat> _compactFormats = {};

  /// The symbol for [currency] in [locale], e.g. `€`, `$`, `CHF`.
  String symbolFor(String? currency) {
    final code = (currency == null || currency.isEmpty)
        ? defaultCurrency
        : currency;
    try {
      return NumberFormat.simpleCurrency(
        locale: _safeLocale,
        name: code,
      ).currencySymbol;
    } catch (_) {
      return code;
    }
  }

  /// Formats [minor] with currency symbol, e.g. `$1,234.50`, `1.234,50 €`,
  /// `¥1,235` (JPY is shown without decimals).
  ///
  /// With [signed] a leading `+` is added to positive amounts.
  String format(int minor, {String? currency, bool signed = false}) {
    final code = (currency == null || currency.isEmpty)
        ? defaultCurrency
        : currency;
    final digits = currencyDecimalDigits(code);
    final fmt = _currencyFormats.putIfAbsent(
      '$code/$digits',
      () => NumberFormat.currency(
        locale: _safeLocale,
        symbol: _placeholder,
        decimalDigits: digits,
      ),
    );
    final value = _displayValue(minor, digits);
    var text = _applySeparators(fmt.format(value));
    text = text.replaceAll(_placeholder, symbolFor(code));
    if (signed && minor > 0) {
      text = '+$text';
    }
    return text;
  }

  /// Compact form for chart axes and tiles, e.g. `$1.2K`.
  String formatCompact(int minor, {String? currency}) {
    final code = (currency == null || currency.isEmpty)
        ? defaultCurrency
        : currency;
    final fmt = _compactFormats.putIfAbsent(
      code,
      () => NumberFormat.compactCurrency(
        locale: _safeLocale,
        symbol: _placeholder,
        decimalDigits: currencyDecimalDigits(code) == 0 ? 0 : null,
      ),
    );
    final text = _applySeparators(fmt.format(Money.toMajorDouble(minor)));
    return text.replaceAll(_placeholder, symbolFor(code));
  }

  /// Formats [minor] as a plain number for text fields: no symbol, no
  /// grouping, always two fraction digits ("12,50" / "12.50" / "-3.00").
  /// The result round-trips through [parser].
  String formatForInput(int minor) {
    return Money.toDecimalString(minor, decimalSeparator: decimalSeparator);
  }

  /// Formats [minor] as a number with grouping but without a symbol, e.g.
  /// `1.234,50`.
  String formatNumber(int minor, {String? currency}) {
    final digits = currencyDecimalDigits(currency ?? defaultCurrency);
    final fmt = NumberFormat.decimalPatternDigits(
      locale: _safeLocale,
      decimalDigits: digits,
    );
    return _applySeparators(fmt.format(_displayValue(minor, digits)));
  }

  /// Rounds minor units to the currency's display precision and returns
  /// major units. Computation stays in integers until this final step.
  num _displayValue(int minor, int digits) {
    if (digits >= 2) {
      return minor / Money.scale;
    }
    final factor = digits == 1 ? 10 : Money.scale;
    final rounded = Money.divideRounded(minor, factor);
    return digits == 1 ? rounded / 10 : rounded;
  }

  /// Rewrites the locale's separators to the configured ones.
  String _applySeparators(String formatted) {
    final symbols = _symbols;
    final localeDecimal = symbols.DECIMAL_SEP;
    final localeGroup = symbols.GROUP_SEP;
    if (localeDecimal == decimalSeparator &&
        (localeGroup == groupSeparator || !formatted.contains(localeGroup))) {
      return formatted;
    }
    final buffer = StringBuffer();
    for (final rune in formatted.runes) {
      final char = String.fromCharCode(rune);
      if (char == localeDecimal) {
        buffer.write(decimalSeparator);
      } else if (char == localeGroup) {
        buffer.write(groupSeparator);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  late final _symbols = NumberFormat.decimalPattern(_safeLocale).symbols;

  late final String _safeLocale = () {
    try {
      NumberFormat.decimalPattern(locale);
      return locale;
    } catch (_) {
      return 'en';
    }
  }();
}
