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

  test('parsePiastres reads whole pounds', () {
    expect(parsePiastres('15'), 1500);
    expect(parsePiastres('0'), 0);
  });

  test('parsePiastres reads one or two decimal digits', () {
    expect(parsePiastres('15.5'), 1550);
    expect(parsePiastres('15.05'), 1505);
    expect(parsePiastres('15.50'), 1550);
  });

  test('parsePiastres accepts Arabic-Indic digits', () {
    expect(parsePiastres('١٥.٥'), 1550);
  });

  test('parsePiastres rejects invalid or negative input', () {
    expect(parsePiastres(''), isNull);
    expect(parsePiastres('abc'), isNull);
    expect(parsePiastres('-5'), isNull);
    expect(parsePiastres('1.2.3'), isNull);
    expect(parsePiastres('1.234'), isNull);
  });

  test('parsePiastres rejects amounts above the 1,000,000 EGP ceiling', () {
    expect(parsePiastres('1000000.01'), isNull);
    expect(parsePiastres('999999999999'), isNull);
  });

  test('parsePiastres accepts amounts at or just under the ceiling', () {
    expect(parsePiastres('1000000'), 100000000);
    expect(parsePiastres('999999.99'), 99999999);
  });
}
