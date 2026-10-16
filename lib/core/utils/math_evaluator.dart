import 'package:ledger_zero/core/money/money.dart';

/// Evaluates simple arithmetic typed into amount fields ("50 + 20",
/// "12,50*3", "100/3") exactly and returns minor units.
///
/// Operands are parsed with [MoneyParser] (either decimal style); `*` and
/// `/` treat the right operand as a plain factor. Intermediate results are
/// exact fractions; only the final result is rounded half away from zero to
/// minor units, so `0.1 + 0.2` is exactly `30`.
class MathEvaluator {
  /// Evaluates [expression] and returns the result in minor units.
  /// An empty expression is `0`. Throws [FormatException] when invalid.
  static int evaluate(String expression, {String decimalSeparator = '.'}) {
    if (expression.trim().isEmpty) {
      return 0;
    }
    final parser = MoneyParser(decimalSeparator: decimalSeparator);
    final cleanExpr = expression.replaceAll(RegExp(r'\s'), '');
    try {
      return _parseExpression(cleanExpr, parser).roundToMinor();
    } catch (e) {
      throw FormatException('Invalid expression: $expression');
    }
  }

  static _Fraction _parseExpression(String expr, MoneyParser parser) {
    final tokens = _tokenize(expr);
    if (tokens.isEmpty) {
      return _Fraction.zero;
    }

    _Fraction operand(String token) {
      if ('+-*/'.contains(token)) {
        throw const FormatException('Unexpected operator');
      }
      // Minor units, i.e. hundredths of the typed number.
      return _Fraction(BigInt.from(parser.parse(token)), BigInt.from(100));
    }

    // Multiplication and division first.
    final terms = <Object>[]; // _Fraction or operator String
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == '*' || token == '/') {
        if (terms.isEmpty || terms.last is! _Fraction) {
          throw const FormatException('Unexpected operator');
        }
        if (i + 1 >= tokens.length) {
          throw const FormatException('Missing operand');
        }
        final left = terms.removeLast() as _Fraction;
        final right = operand(tokens[++i]);
        if (token == '*') {
          terms.add(left * right);
        } else {
          if (right.isZero) {
            throw const FormatException('Division by zero');
          }
          terms.add(left / right);
        }
      } else if (token == '+' || token == '-') {
        terms.add(token);
      } else {
        terms.add(operand(token));
      }
    }

    if (terms.isEmpty || terms.first is! _Fraction) {
      throw const FormatException('Expression must start with a number');
    }
    var result = terms.first as _Fraction;
    for (var i = 1; i < terms.length; i += 2) {
      final op = terms[i];
      if (i + 1 >= terms.length || terms[i + 1] is! _Fraction) {
        throw const FormatException('Missing operand');
      }
      final value = terms[i + 1] as _Fraction;
      if (op == '+') {
        result = result + value;
      } else if (op == '-') {
        result = result - value;
      } else {
        throw FormatException('Unknown operator: $op');
      }
    }
    return result;
  }

  static List<String> _tokenize(String expr) {
    final tokens = <String>[];
    var buffer = '';

    for (var i = 0; i < expr.length; i++) {
      final char = expr[i];
      if ('+-*/'.contains(char)) {
        // Negative numbers at the start or after another operator.
        if (char == '-' &&
            buffer.isEmpty &&
            (tokens.isEmpty || '+-*/'.contains(tokens.last))) {
          buffer += char;
        } else {
          if (buffer.isNotEmpty) {
            tokens.add(buffer);
            buffer = '';
          }
          tokens.add(char);
        }
      } else {
        buffer += char;
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer);
    }

    return tokens;
  }
}

/// Exact rational number in major units.
class _Fraction {
  final BigInt numerator;
  final BigInt denominator;

  _Fraction(BigInt numerator, BigInt denominator)
    : numerator = denominator.isNegative ? -numerator : numerator,
      denominator = denominator.abs();

  static final _Fraction zero = _Fraction(BigInt.zero, BigInt.one);

  bool get isZero => numerator == BigInt.zero;

  _Fraction operator +(_Fraction o) => _Fraction(
    numerator * o.denominator + o.numerator * denominator,
    denominator * o.denominator,
  );

  _Fraction operator -(_Fraction o) => _Fraction(
    numerator * o.denominator - o.numerator * denominator,
    denominator * o.denominator,
  );

  _Fraction operator *(_Fraction o) =>
      _Fraction(numerator * o.numerator, denominator * o.denominator);

  _Fraction operator /(_Fraction o) =>
      _Fraction(numerator * o.denominator, denominator * o.numerator);

  /// Rounds to minor units (hundredths), half away from zero.
  int roundToMinor() {
    final scaled = numerator.abs() * BigInt.from(100);
    var q = scaled ~/ denominator;
    final r = scaled - q * denominator;
    if (r * BigInt.two >= denominator) {
      q += BigInt.one;
    }
    final value = numerator.isNegative ? -q : q;
    if (!value.isValidInt) {
      throw const FormatException('Result out of range');
    }
    return value.toInt();
  }
}
