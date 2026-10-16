import 'package:intl/intl.dart';
import 'package:ledger_zero/core/money/money.dart';

/// Parses user or bank supplied amount text into minor units.
///
/// Accepts both decimal styles regardless of locale where the input is
/// unambiguous ("12,50", "12.50", "1.234,56", "1,234.56", "1 234,56",
/// "1'234.56"), an optional sign ("-12", "+12", "12-", "(12.50)"), and an
/// optional currency symbol or code before or after the number ("€12,50",
/// "12,50 €", "EUR 12.50"). Rejects anything else.
///
/// Ambiguous input with a single separator followed by exactly three digits
/// ("1.234" / "1,234") is resolved with [decimalSeparator]: if the separator
/// is the locale's decimal separator it is a decimal point, otherwise it is a
/// thousands separator.
///
/// More than two fraction digits are rounded half away from zero.
class MoneyParser {
  /// The decimal separator of the active locale / number format setting.
  final String decimalSeparator;

  const MoneyParser({this.decimalSeparator = '.'})
    : assert(decimalSeparator == '.' || decimalSeparator == ',');

  /// A parser using the decimal separator of [locale] (e.g. `de` -> `,`).
  factory MoneyParser.forLocale(String? locale) {
    return MoneyParser(decimalSeparator: decimalSeparatorForLocale(locale));
  }

  /// Parses [input], returning `null` when it is empty or not an amount.
  int? tryParse(String? input) {
    if (input == null) {
      return null;
    }
    try {
      return parse(input);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] or throws a [FormatException].
  int parse(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      throw const FormatException('Empty amount');
    }

    var negative = false;

    // Accounting style negative: (12.50)
    if (text.startsWith('(') && text.endsWith(')')) {
      negative = true;
      text = text.substring(1, text.length - 1).trim();
    }

    text = _stripCurrency(text);

    // Leading sign, possibly before a currency symbol ("-€12" / "€-12").
    final leading = _signAt(text, 0);
    if (leading != null) {
      negative = negative != (leading == '-');
      text = _stripCurrency(text.substring(1).trim());
      final again = _signAt(text, 0);
      if (again != null) {
        throw FormatException('Duplicate sign', input);
      }
    } else if (text.isNotEmpty) {
      // Trailing sign ("12,50-"), common in German bank exports.
      final trailing = _signAt(text, text.length - 1);
      if (trailing != null) {
        negative = negative != (trailing == '-');
        text = _stripCurrency(text.substring(0, text.length - 1).trim());
      }
    }

    // Remove grouping spaces and apostrophes.
    text = text.replaceAll(_groupingChars, '');
    if (text.isEmpty || !_numberChars.hasMatch(text)) {
      throw FormatException('Not an amount', input);
    }
    if (!text.contains(RegExp(r'\d'))) {
      throw FormatException('No digits', input);
    }

    final normalized = _normalizeSeparators(text, input);
    final minor = Money.fromDecimalString(normalized);
    if (minor == null) {
      throw FormatException('Not an amount', input);
    }
    return negative ? -minor : minor;
  }

  /// Turns [text] (digits, `.` and `,` only) into a `.`-decimal string.
  String _normalizeSeparators(String text, String original) {
    final dots = '.'.allMatches(text).length;
    final commas = ','.allMatches(text).length;

    if (dots == 0 && commas == 0) {
      return text;
    }

    if (dots > 0 && commas > 0) {
      // The separator that appears last is the decimal separator.
      final lastDot = text.lastIndexOf('.');
      final lastComma = text.lastIndexOf(',');
      final decimal = lastDot > lastComma ? '.' : ',';
      final group = decimal == '.' ? ',' : '.';
      if (decimal.allMatches(text).length > 1) {
        throw FormatException('Multiple decimal separators', original);
      }
      final decimalIndex = text.lastIndexOf(decimal);
      final intPart = text.substring(0, decimalIndex);
      if (intPart.contains(decimal)) {
        throw FormatException('Separator order', original);
      }
      _validateGrouping(intPart, group, original);
      return '${intPart.replaceAll(group, '')}.${text.substring(decimalIndex + 1)}';
    }

    final sep = dots > 0 ? '.' : ',';
    final count = dots > 0 ? dots : commas;
    if (count > 1) {
      // "1.234.567" -> grouping only.
      _validateGrouping(text, sep, original);
      return text.replaceAll(sep, '');
    }

    final index = text.indexOf(sep);
    final before = text.substring(0, index);
    final after = text.substring(index + 1);
    final looksGrouped =
        before.isNotEmpty && !before.startsWith('0') && after.length == 3;
    if (looksGrouped && sep != decimalSeparator) {
      // "1,234" in en, "1.234" in de: thousands separator.
      _validateGrouping(text, sep, original);
      return text.replaceAll(sep, '');
    }
    return '$before.$after';
  }

  void _validateGrouping(String intPart, String group, String original) {
    final groups = intPart.split(group);
    if (groups.first.isEmpty || groups.first.length > 3) {
      throw FormatException('Invalid digit grouping', original);
    }
    for (var i = 1; i < groups.length; i++) {
      final g = groups[i];
      final isLast = i == groups.length - 1;
      // Allow Indian style 2-digit groups before the final 3-digit group.
      if (isLast ? g.length != 3 : (g.length != 3 && g.length != 2)) {
        throw FormatException('Invalid digit grouping', original);
      }
    }
  }

  static String? _signAt(String text, int index) {
    if (text.isEmpty || index < 0 || index >= text.length) {
      return null;
    }
    final c = text[index];
    if (c == '-' || c == '−' || c == '–') {
      return '-';
    }
    if (c == '+') {
      return '+';
    }
    return null;
  }

  static String _stripCurrency(String text) {
    var result = text;
    for (final token in _currencyTokens) {
      final upper = result.toUpperCase();
      if (upper.startsWith(token)) {
        result = result.substring(token.length).trim();
        break;
      }
    }
    for (final token in _currencyTokens) {
      final upper = result.toUpperCase();
      if (upper.endsWith(token)) {
        result = result.substring(0, result.length - token.length).trim();
        break;
      }
    }
    return result;
  }

  /// Currency codes and symbols that may surround a number, longest first so
  /// "CA$" is stripped before "$".
  static final List<String> _currencyTokens = () {
    final tokens = <String>{
      for (final c in supportedCurrencies) c.code,
      r'$',
      '€',
      '£',
      '¥',
      '₹',
      '₩',
      '₽',
      '₺',
      '₪',
      '₫',
      '₱',
      '₦',
      '₴',
      'CHF',
      'FR.',
      'KR',
      'ZŁ',
      'R\$',
      'US\$',
      'CA\$',
      'A\$',
      'AU\$',
      'C\$',
      'CN¥',
      'JP¥',
      'HK\$',
      'NZ\$',
      'S\$',
      'MX\$',
    };
    for (final c in supportedCurrencies) {
      try {
        tokens.add(
          NumberFormat.simpleCurrency(
            locale: 'en',
            name: c.code,
          ).currencySymbol.toUpperCase(),
        );
      } catch (_) {
        // Symbol data missing for this currency; the code still works.
      }
    }
    tokens.removeWhere((t) => t.isEmpty);
    final list = tokens.toList()..sort((a, b) => b.length.compareTo(a.length));
    return list;
  }();

  static final RegExp _groupingChars = RegExp('[\\s   \'’]');
  static final RegExp _numberChars = RegExp(r'^[0-9.,]+$');
}

/// The decimal separator conventionally used by [locale] ("," for de, fr,
/// ...; "." for en, ...). Unknown locales use ".".
String decimalSeparatorForLocale(String? locale) {
  if (locale == null || locale.isEmpty) {
    return '.';
  }
  try {
    final symbols = NumberFormat.decimalPattern(locale).symbols;
    return symbols.DECIMAL_SEP == ',' ? ',' : '.';
  } catch (_) {
    return '.';
  }
}
