import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/search.dart';

void main() {
  group('normalizeForSearch', () {
    test('folds the alef forms, taa marbuta and alef maqsura', () {
      expect(normalizeForSearch('أإآ'), 'ااا');
      expect(normalizeForSearch('جبنة'), 'جبنه');
      expect(normalizeForSearch('مصطفى'), 'مصطفي');
    });

    test('drops tatweel and diacritics', () {
      expect(normalizeForSearch('شـــايٌ'), 'شاي');
    });

    test('turns Eastern Arabic and Persian digits into Latin ones', () {
      expect(normalizeForSearch('٣٠ جنيه'), '30 جنيه');
      expect(normalizeForSearch('۱۲'), '12');
    });

    test('makes the spellings of one word meet from either side', () {
      expect(normalizeForSearch('إندومى'), normalizeForSearch('اندومي'));
    });
  });

  group('matchesSearch', () {
    test('an empty or blank query matches everything', () {
      expect(matchesSearch('', ['شاي']), isTrue);
      expect(matchesSearch('   ', const []), isTrue);
    });

    test('finds the query inside any field, normalised on both sides', () {
      expect(matchesSearch('اندومي', ['إندومى بالخضار']), isTrue);
      expect(matchesSearch('جبنه', [null, 'جبنة رومي']), isTrue);
      expect(matchesSearch('٣٠', ['طماطم ب 30']), isTrue);
    });

    test('every word of the query must be found, in any field', () {
      expect(matchesSearch('طماطم كيلو', ['طماطم', 'اتنين كيلو']), isTrue);
      expect(matchesSearch('طماطم خيار', ['طماطم', 'اتنين كيلو']), isFalse);
    });

    test('no field holding the query means no match', () {
      expect(matchesSearch('قهوة', ['شاي', null]), isFalse);
    });
  });
}
