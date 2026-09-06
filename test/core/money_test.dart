import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/money.dart';

void main() {
  test('whole pounds render without decimals', () {
    expect(formatPiastres(4000), '40');
    expect(formatPiastres(0), '0');
  });

  test('thousands get a comma separator', () {
    expect(formatPiastres(891500), '8,915');
  });

  test('piastres render with two decimals when present', () {
    expect(formatPiastres(82340), '823.40');
  });

  test('negative amounts keep a leading minus', () {
    expect(formatPiastres(-269200), '-2,692');
  });

  test('currency suffix is appended on request', () {
    expect(formatPiastres(4000, withCurrency: true), '40 ج.م');
  });
}
