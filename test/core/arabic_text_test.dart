import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/arabic_text.dart';

void main() {
  group('normalizeArabic', () {
    test('folds the alef forms to a bare alef', () {
      expect(normalizeArabic('أإآا'), 'اااا');
    });

    test('folds taa marbuta to haa and alef maqsura to yaa', () {
      expect(normalizeArabic('جبنة'), 'جبنه');
      expect(normalizeArabic('مصطفى'), 'مصطفي');
    });

    test('drops tatweel and diacritics', () {
      expect(normalizeArabic('شـــاي'), 'شاي');
      expect(normalizeArabic('خُبْزٌ'), 'خبز');
    });

    test('trims, collapses spaces and lowercases Latin letters', () {
      expect(normalizeArabic('  Pepsi   كانز '), 'pepsi كانز');
    });

    test('makes different spellings of the same word meet', () {
      expect(normalizeArabic('إندومي'), normalizeArabic('اندومى'));
    });
  });
}
