class MathEvaluator {
  /// Evaluates a simple mathematical expression string (e.g., "50 + 20").
  /// Supports +, -, *, /.
  /// Returns the result as a double.
  /// Throws FormatException if the expression is invalid.
  static double evaluate(String expression) {
    if (expression.trim().isEmpty) {
      return 0.0;
    }

    // Remove all whitespace
    final cleanExpr = expression.replaceAll(' ', '');

    // Allow negative numbers at the start
    // We will parse strictly left-to-right for simplicity, or handle operator precedence if needed.
    // Given the task is for "budget entry", simple left-to-right or simple binary operations are usually enough.
    // However, let's support standard precedence (*, / before +, -).

    // For a robust implementation without external libraries, we can use a recursive descent parser or shunting-yard.
    // But for "budget entry", usually users enter something like "100+50" or "50-10".
    // Let's implement a basic parser that handles +, -, *, /.

    try {
      return _parseExpression(cleanExpr);
    } catch (e) {
      throw FormatException('Invalid expression: $expression');
    }
  }

  static double _parseExpression(String expr) {
    // 1. Tokenize
    final tokens = _tokenize(expr);
    if (tokens.isEmpty) {
      return 0.0;
    }

    // 2. Handle multiplication and division first
    final complexTokens = <String>[];
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == '*' || token == '/') {
        if (complexTokens.isEmpty) {
          throw const FormatException('Unexpected operator');
        }
        final prevVal = double.parse(complexTokens.removeLast());
        if (i + 1 >= tokens.length) {
          throw const FormatException('Missing operand');
        }
        final nextVal = double.parse(tokens[++i]);

        if (token == '*') {
          complexTokens.add((prevVal * nextVal).toString());
        } else {
          if (nextVal == 0) {
            throw const FormatException('Division by zero');
          }
          complexTokens.add((prevVal / nextVal).toString());
        }
      } else {
        complexTokens.add(token);
      }
    }

    // 3. Handle addition and subtraction
    double result = double.parse(complexTokens[0]);
    for (int i = 1; i < complexTokens.length; i += 2) {
      final op = complexTokens[i];
      final val = double.parse(complexTokens[i + 1]);

      if (op == '+') {
        result += val;
      } else if (op == '-') {
        result -= val;
      } else {
        throw FormatException('Unknown operator: $op');
      }
    }

    return result;
  }

  static List<String> _tokenize(String expr) {
    final tokens = <String>[];
    String buffer = '';

    for (int i = 0; i < expr.length; i++) {
      final char = expr[i];
      if ('+-*/'.contains(char)) {
        // Handle negative numbers at start or after another operator
        if (char == '-' && (buffer.isEmpty && (tokens.isEmpty || '+-*/'.contains(tokens.last)))) {
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
