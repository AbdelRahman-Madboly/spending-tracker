import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/quantity.dart';

void main() {
  group('parseQuantityMilli', () {
    test('reads whole and fractional quantities as milli-units', () {
      expect(parseQuantityMilli('1'), 1000);
      expect(parseQuantityMilli('1.5'), 1500);
      expect(parseQuantityMilli('0.25'), 250);
      expect(parseQuantityMilli('2.125'), 2125);
    });

    test('accepts Eastern Arabic digits and the Arabic decimal comma', () {
      expect(parseQuantityMilli('١٫٥'), 1500);
    });

    test('refuses empty, zero, malformed and over-precise input', () {
      expect(parseQuantityMilli(''), isNull);
      expect(parseQuantityMilli('0'), isNull);
      expect(parseQuantityMilli('1.2.3'), isNull);
      expect(parseQuantityMilli('1.2345'), isNull);
      expect(parseQuantityMilli('-1'), isNull);
    });
  });

  group('formatQuantityMilli', () {
    test('drops trailing zeros of the fraction', () {
      expect(formatQuantityMilli(1000), '1');
      expect(formatQuantityMilli(1500), '1.5');
      expect(formatQuantityMilli(250), '0.25');
      expect(formatQuantityMilli(2125), '2.125');
    });
  });
}
