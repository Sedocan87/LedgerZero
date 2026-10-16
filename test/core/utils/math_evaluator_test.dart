import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/utils/math_evaluator.dart';

void main() {
  group('MathEvaluator (minor units)', () {
    test('evaluates simple addition', () {
      expect(MathEvaluator.evaluate('10+20'), 3000);
    });

    test('evaluates simple subtraction', () {
      expect(MathEvaluator.evaluate('30-10'), 2000);
    });

    test('evaluates multiplication', () {
      expect(MathEvaluator.evaluate('5*4'), 2000);
      expect(MathEvaluator.evaluate('12.50*3'), 3750);
    });

    test('evaluates division with rounding half away from zero', () {
      expect(MathEvaluator.evaluate('20/2'), 1000);
      expect(MathEvaluator.evaluate('100/3'), 3333);
      expect(MathEvaluator.evaluate('-0.05/2'), -3);
    });

    test('is exact for decimal fractions (0.1 + 0.2)', () {
      expect(MathEvaluator.evaluate('0.1+0.2'), 30);
      expect(MathEvaluator.evaluate('0.30-0.10-0.20'), 0);
    });

    test('accepts decimal commas', () {
      expect(MathEvaluator.evaluate('12,50+0,50', decimalSeparator: ','), 1300);
      expect(MathEvaluator.evaluate('12,50+0,50'), 1300);
    });

    test('handles negative numbers', () {
      expect(MathEvaluator.evaluate('-10+20'), 1000);
      expect(MathEvaluator.evaluate('10+-5'), 500);
    });

    test('respects precedence (* / before + -)', () {
      expect(MathEvaluator.evaluate('10+5*2'), 2000);
      expect(MathEvaluator.evaluate('10-6/2'), 700);
    });

    test('handles whitespace and empty input', () {
      expect(MathEvaluator.evaluate(' 10 + 20 '), 3000);
      expect(MathEvaluator.evaluate('  '), 0);
    });

    test('throws on invalid expression', () {
      expect(() => MathEvaluator.evaluate('10++20'), throwsFormatException);
      expect(() => MathEvaluator.evaluate('abc'), throwsFormatException);
      expect(() => MathEvaluator.evaluate('10/0'), throwsFormatException);
      expect(() => MathEvaluator.evaluate('10+'), throwsFormatException);
    });
  });
}
