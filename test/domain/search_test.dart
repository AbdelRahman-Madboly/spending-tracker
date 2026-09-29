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

    test('drops the invisible direction marks and zero-width joiners', () {
      // An Arabic keyboard puts a left-to-right mark before an English
      // word typed into a right-to-left field; the manual pack carries
      // right-to-left marks before "30W".
      expect(normalizeForSearch('\u200EUdemy\u200E'), 'udemy');
      expect(normalizeForSearch('شاحن \u200F30W'), 'شاحن 30w');
      expect(
        normalizeForSearch(
          '\u061C\u202Bتا\u200Cكسي\u202C\u2066\u2069\uFEFF\u200B',
        ),
        'تاكسي',
      );
    });

    test('treats a no-break space as a space', () {
      expect(normalizeForSearch('Schweppes\u00A0soda'), 'schweppes soda');
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

    test('a query typed with direction marks still finds Latin text', () {
      expect(
        matchesSearch('\u200EUdemy', ['Udemy Personal Plan (سنوي)']),
        isTrue,
      );
      expect(matchesSearch('Taxi\u200E', ['Taxi']), isTrue);
      expect(
        matchesSearch('\u200Fschweppes\u00A0soda', ['Schweppes soda']),
        isTrue,
      );
      expect(
        matchesSearch('Zolo 30W', ['شاحن Anker Zolo 1C \u200F30W']),
        isTrue,
      );
      expect(matchesSearch('\u200E', ['شاي']), isTrue);
    });

    test('no field holding the query means no match', () {
      expect(matchesSearch('قهوة', ['شاي', null]), isFalse);
    });
  });
}
