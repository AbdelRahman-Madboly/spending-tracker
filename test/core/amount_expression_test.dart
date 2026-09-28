import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/amount_expression.dart';

void main() {
  group('evaluateAmountExpression', () {
    test('a plain amount is its piastres', () {
      expect(evaluateAmountExpression('35'), 3500);
      expect(evaluateAmountExpression('7.5'), 750);
      expect(evaluateAmountExpression('0.25'), 25);
    });

    test('multiplication binds tighter than addition', () {
      expect(evaluateAmountExpression('2×35+10'), 8000);
      expect(evaluateAmountExpression('10+2×35'), 8000);
    });

    test('subtraction and division', () {
      expect(evaluateAmountExpression('100−15'), 8500);
      expect(evaluateAmountExpression('100÷4'), 2500);
      expect(evaluateAmountExpression('50−10÷2'), 4500);
    });

    test('a fractional quantity times a price rounds to the piastre', () {
      // 1.5 kilo at 33.33: 49.995 rounds half up to 50.00.
      expect(evaluateAmountExpression('1.5×33.33'), 5000);
      // 10 split three ways: 3.333... rounds to 3.33.
      expect(evaluateAmountExpression('10÷3'), 333);
    });

    test('ASCII operators and Eastern Arabic digits are accepted', () {
      expect(evaluateAmountExpression('2*35+10'), 8000);
      expect(evaluateAmountExpression('100/4-5'), 2000);
      expect(evaluateAmountExpression('٢×٣٥'), 7000);
      expect(evaluateAmountExpression('٧٫٥'), 750);
    });

    test('a trailing operator is ignored so the total evaluates while typing',
        () {
      expect(evaluateAmountExpression('35+'), 3500);
      expect(evaluateAmountExpression('2×'), 200);
    });

    test('empty, malformed, negative and divide-by-zero give null', () {
      expect(evaluateAmountExpression(''), isNull);
      expect(evaluateAmountExpression('+'), isNull);
      expect(evaluateAmountExpression('×5'), isNull);
      expect(evaluateAmountExpression('3++4'), isNull);
      expect(evaluateAmountExpression('1.2.3'), isNull);
      expect(evaluateAmountExpression('5.123'), isNull);
      expect(evaluateAmountExpression('10−20'), isNull);
      expect(evaluateAmountExpression('5÷0'), isNull);
    });

    test('a result past the parse ceiling is refused', () {
      expect(evaluateAmountExpression('1000000×2'), isNull);
    });
  });
}
