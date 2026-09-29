import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/parsing/catalogue_matcher.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';

import 'parser_catalogue_fixture.dart';

void main() {
  group('levenshtein', () {
    test('counts insertions, deletions and substitutions', () {
      expect(levenshtein('', ''), 0);
      expect(levenshtein('abc', 'abc'), 0);
      expect(levenshtein('abc', ''), 3);
      expect(levenshtein('kitten', 'sitting'), 3);
      expect(levenshtein('تاكس', 'تاكسي'), 1);
      expect(levenshtein('انودي', 'اندومي'), 2);
    });
  });

  group('matchCatalogue', () {
    final catalogue = parserCatalogueFixture();

    test('an exact name, in any spelling, is a high-confidence match', () {
      final match = catalogue.match('اندومى');
      expect(match.itemId, 'item-05');
      expect(match.name, 'إندومي');
      expect(match.categoryKey, 'Food');
      expect(match.subcategoryKey, 'Lunch');
      expect(match.confidence, ParseConfidence.high);
    });

    final typos = <String, (String, String)>{
      'تاكس': ('item-07', 'تاكسي'),
      'انودي': ('item-05', 'إندومي'),
      'شكولاته': ('item-06', 'شوكولاتة'),
      'كوشري': ('item-13', 'كشري'),
    };
    for (final MapEntry(key: typed, value: (id, name)) in typos.entries) {
      test('the typo "$typed" is a medium match to $name', () {
        final match = catalogue.match(typed);
        expect(match.itemId, id);
        expect(match.name, name);
        expect(match.confidence, ParseConfidence.medium);
      });
    }

    test('a learned alias is an exact match and takes the item name', () {
      final match = catalogue.match('swhipps');
      expect(match.itemId, 'item-03');
      expect(match.name, 'شويبس');
      expect(match.confidence, ParseConfidence.high);
    });

    test('a name under four letters must match exactly', () {
      // "جبن" (cheese) is one edit from "لبن" (milk): too short to guess.
      expect(catalogue.match('جبن').itemId, isNull);
      expect(catalogue.match('لب').itemId, isNull);
      expect(catalogue.match('لبن').itemId, 'item-04');
    });

    test('a four-letter name tolerates one edit, not two', () {
      expect(catalogue.match('تاكس').itemId, 'item-07');
      expect(catalogue.match('تكسي').itemId, 'item-07');
      // One substitution and one missing letter away from تاكسي.
      expect(catalogue.match('طاكس').itemId, isNull);
    });

    test('an exact keyword beats an item one edit away', () {
      // بيبسي is one letter from the شيبسي item, but it is its own word.
      final match = catalogue.match('بيبسي');
      expect(match.itemId, isNull);
      expect(match.name, 'بيبسي');
      expect(match.subcategoryKey, 'Soda');
    });

    test('a typo match must keep the first letter', () {
      // Both are two edits from مياه.
      expect(catalogue.match('جمعية').itemId, isNull);
      expect(catalogue.match('زيارة').itemId, isNull);
    });

    test('a leading item word links the item but keeps the written name', () {
      final match = catalogue.match('مواصلات المدينة');
      expect(match.itemId, 'item-08');
      expect(match.name, 'مواصلات المدينة');
      expect(match.categoryKey, 'Transport');
      expect(match.subcategoryKey, 'PublicTransport');
      expect(match.confidence, ParseConfidence.medium);
    });

    test('with no item, a subcategory label gives the category', () {
      final match = catalogue.match('عصير');
      expect(match.itemId, isNull);
      expect(match.name, 'عصير');
      expect(match.categoryKey, 'Drinks');
      expect(match.subcategoryKey, 'Juice');
      expect(match.confidence, ParseConfidence.medium);
    });

    test('with no item, a built-in keyword gives the category', () {
      final match = catalogue.match('مترو');
      expect(match.categoryKey, 'Transport');
      expect(match.subcategoryKey, 'PublicTransport');
      expect(catalogue.match('كيس عيش بلدي').subcategoryKey, 'Groceries');
    });

    test('a keyword whose subcategory is missing from the catalogue is '
        'ignored', () {
      final bare = ParserCatalogue(items: const [], subcategories: const []);
      expect(bare.match('مترو').categoryKey, isNull);
    });

    test('an unknown name is low with no category', () {
      final match = catalogue.match('حاجة غريبة');
      expect(match.itemId, isNull);
      expect(match.categoryKey, isNull);
      expect(match.name, 'حاجة غريبة');
      expect(match.confidence, ParseConfidence.low);
    });

    test('an empty name matches nothing', () {
      expect(catalogue.match('').confidence, ParseConfidence.low);
    });
  });
}
