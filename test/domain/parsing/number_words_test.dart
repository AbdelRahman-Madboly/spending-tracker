import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/parsing/number_words.dart';

void main() {
  group('parseNumberWords', () {
    final cases = <String, int>{
      // 1-10, Egyptian and MSA spellings, with and without taa marbuta.
      'واحد': 1,
      'واحدة': 1,
      'اتنين': 2,
      'اثنين': 2,
      'تلاتة': 3,
      'ثلاثة': 3,
      'اربعة': 4,
      'أربعة': 4,
      'خمسة': 5,
      'خمسه': 5,
      'ستة': 6,
      'سبعة': 7,
      'تمانية': 8,
      'ثمانية': 8,
      'تسعة': 9,
      'عشرة': 10,
      // 11-19.
      'حداشر': 11,
      'اتناشر': 12,
      'تلتاشر': 13,
      'اربعتاشر': 14,
      'خمستاشر': 15,
      'ستاشر': 16,
      'سبعتاشر': 17,
      'تمنتاشر': 18,
      'تسعتاشر': 19,
      // Tens.
      'عشرين': 20,
      'تلاتين': 30,
      'ثلاثين': 30,
      'اربعين': 40,
      'خمسين': 50,
      'ستين': 60,
      'سبعين': 70,
      'تمانين': 80,
      'تسعين': 90,
      // Hundreds.
      'مية': 100,
      'ميه': 100,
      'مائة': 100,
      'ميتين': 200,
      'تلتمية': 300,
      'ربعمية': 400,
      'خمسمية': 500,
      'ستمية': 600,
      'سبعمية': 700,
      'تمنمية': 800,
      'تسعمية': 900,
      // Thousands.
      'الف': 1000,
      'ألف': 1000,
      'الفين': 2000,
      'تلات آلاف': 3000,
      'خمس الاف': 5000,
      'عشرين الف': 20000,
      // Compounds joined with و, attached or standalone.
      'خمسة وعشرين': 25,
      'خمسة و عشرين': 25,
      'مية وخمسين': 150,
      'ميت': 100,
      'ستمية وخمسة وسبعين': 675,
      'الف وخمسمية': 1500,
      'اتنين الف وتلتمية وعشرة': 2310,
      // English one to ten, and twenty.
      'one': 1,
      'two': 2,
      'Three': 3,
      'ten': 10,
      'twenty': 20,
    };
    for (final MapEntry(key: text, value: expected) in cases.entries) {
      test('"$text" is $expected', () {
        expect(parseNumberWords(text), expected);
      });
    }

    test('anything that is not a whole number phrase is null', () {
      expect(parseNumberWords('طماطم'), isNull);
      expect(parseNumberWords('خمسة طماطم'), isNull);
      expect(parseNumberWords(''), isNull);
      expect(parseNumberWords('و'), isNull);
    });
  });

  group('readNumberWords', () {
    test('reads the longest number phrase from a position', () {
      final words = ['كيس', 'خمسة', 'و', 'عشرين', 'جنيه'];
      final read = readNumberWords(words, 1)!;
      expect(read.value, 25);
      expect(read.length, 3);
    });

    test('stops before a و that is not followed by a number word', () {
      final words = ['عشرين', 'و', 'عيش'];
      final read = readNumberWords(words, 0)!;
      expect(read.value, 20);
      expect(read.length, 1);
    });

    test('does not swallow ونص, which the caller reads as a half', () {
      final words = ['خمسة', 'ونص'];
      expect(readNumberWords(words, 0)!.length, 1);
    });

    test('multiplies a digit count by الاف', () {
      final words = ['3', 'الاف'];
      final read = readNumberWords(words, 0)!;
      expect(read.value, 3000);
      expect(read.length, 2);
    });

    test('is null at a word that starts no number', () {
      expect(readNumberWords(['طماطم', 'خمسة'], 0), isNull);
    });
  });
}
