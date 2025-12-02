import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/utils/math_evaluator.dart';

void main() {
  group('MathEvaluator', () {
    test('evaluates simple addition', () {
      expect(MathEvaluator.evaluate('10+20'), 30.0);
    });

    test('evaluates simple subtraction', () {
      expect(MathEvaluator.evaluate('30-10'), 20.0);
    });

    test('evaluates multiplication', () {
      expect(MathEvaluator.evaluate('5*4'), 20.0);
    });

    test('evaluates division', () {
      expect(MathEvaluator.evaluate('20/2'), 10.0);
    });

    test('handles negative numbers', () {
      expect(MathEvaluator.evaluate('-10+20'), 10.0);
      expect(MathEvaluator.evaluate('10+-5'), 5.0);
    });

    test('respects precedence (* / before + -)', () {
      expect(MathEvaluator.evaluate('10+5*2'), 20.0); // 10 + 10 = 20
      expect(MathEvaluator.evaluate('10-6/2'), 7.0);  // 10 - 3 = 7
    });

    test('handles whitespace', () {
      expect(MathEvaluator.evaluate(' 10 + 20 '), 30.0);
    });

    test('throws on invalid expression', () {
      expect(() => MathEvaluator.evaluate('10++20'), throwsFormatException);
      expect(() => MathEvaluator.evaluate('abc'), throwsFormatException);
    });
  });
}
