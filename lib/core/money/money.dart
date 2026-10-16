/// Exact money handling for LedgerZero.
///
/// Every amount in the app is an `int` of hundredths of the currency unit
/// ("minor units"). `1250` means 12.50 in any currency. Doubles are only
/// produced at the display edge ([Money.toMajorDouble]) for chart
/// coordinates and percentages.
library;

export 'currency.dart';
export 'money_formatter.dart';
export 'money_parser.dart';

/// Helpers for amounts stored as minor units.
abstract final class Money {
  /// Minor units per major unit. Fixed for every currency.
  static const int scale = 100;

  /// Converts a major-unit number (e.g. `12.345` from a JSON import) to
  /// minor units, rounding half away from zero.
  ///
  /// Doubles are converted through their shortest round-trip decimal
  /// representation, so `1.005` becomes `101` and `0.1 + 0.2` becomes `30`,
  /// rather than inheriting binary floating point error.
  static int fromMajor(num major) {
    if (major is int) {
      return major * scale;
    }
    final value = major.toDouble();
    if (!value.isFinite) {
      throw ArgumentError.value(major, 'major', 'must be finite');
    }
    return fromDecimalString(value.toString())!;
  }

  /// Parses a plain decimal string ("-12.345", "1e-3", "+7") in major units
  /// into minor units, rounding half away from zero. Uses `.` as the decimal
  /// separator and accepts no grouping. Returns `null` when [input] is not a
  /// plain decimal number.
  static int? fromDecimalString(String input) {
    final match = _plainDecimal.firstMatch(input.trim());
    if (match == null) {
      return null;
    }
    final negative = match.group(1) == '-';
    final intPart = match.group(2) ?? '';
    final fracPart = match.group(3) ?? '';
    if (intPart.isEmpty && fracPart.isEmpty) {
      return null;
    }
    final exponent = match.group(4) == null ? 0 : int.parse(match.group(4)!);
    final minor = _roundDigits(intPart + fracPart, fracPart.length - exponent);
    return negative ? -minor : minor;
  }

  /// Rounds the non-negative integer formed by [digits] scaled by
  /// 10^-[fractionDigits] to minor units (2 fraction digits), half away from
  /// zero.
  static int _roundDigits(String digits, int fractionDigits) {
    var value = BigInt.parse(digits.isEmpty ? '0' : digits);
    // We want value * 10^(2 - fractionDigits).
    final shift = 2 - fractionDigits;
    if (shift >= 0) {
      value *= BigInt.from(10).pow(shift);
    } else {
      final divisor = BigInt.from(10).pow(-shift);
      final quotient = value ~/ divisor;
      final remainder = value - quotient * divisor;
      value = remainder * BigInt.two >= divisor
          ? quotient + BigInt.one
          : quotient;
    }
    if (!value.isValidInt) {
      throw ArgumentError('Amount out of range: $digits');
    }
    return value.toInt();
  }

  static final RegExp _plainDecimal = RegExp(
    r'^([+-])?(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
  );

  /// Converts minor units to a major-unit double. Only for chart
  /// coordinates and ratios; never sum or store the result.
  static double toMajorDouble(int minor) => minor / scale;

  /// Divides [minor] by [divisor], rounding half away from zero.
  /// Used for averages and "per month" goal amounts.
  static int divideRounded(int minor, int divisor) {
    if (divisor == 0) {
      throw ArgumentError.value(divisor, 'divisor', 'must not be zero');
    }
    final negative = (minor < 0) != (divisor < 0);
    final a = minor.abs();
    final b = divisor.abs();
    var q = a ~/ b;
    if ((a % b) * 2 >= b) {
      q += 1;
    }
    return negative ? -q : q;
  }

  /// Formats minor units as a plain decimal string with exactly two fraction
  /// digits and no grouping, e.g. `-1250` -> `-12.50`. Suitable for CSV
  /// exports and machine readable output.
  static String toDecimalString(int minor, {String decimalSeparator = '.'}) {
    final negative = minor < 0;
    final abs = minor.abs();
    final major = abs ~/ scale;
    final cents = (abs % scale).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$major$decimalSeparator$cents';
  }

  /// Sums minor-unit amounts.
  static int sum(Iterable<int> amounts) =>
      amounts.fold<int>(0, (total, amount) => total + amount);
}
