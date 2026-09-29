import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/parsing/catalogue_matcher.dart';
import 'package:spending_tracker/domain/parsing/line_parser.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';

import 'parser_catalogue_fixture.dart';

void main() {
  final parser = ArabicLineParser(parserCatalogueFixture());
  final afternoon = DateTime(2026, 9, 29, 14, 30);

  List<ParsedLine> parse(String text, {DateTime? at}) =>
      parser.parse(text, capturedAt: at ?? afternoon);

  ParsedLine one(String text) {
    final lines = parse(text);
    expect(lines, hasLength(1), reason: '"$text" gave $lines');
    return lines.single;
  }

  /// Checks the fields that matter for a spoken line in one go.
  void expectLine(
    ParsedLine line, {
    required String name,
    required int? amount,
    int quantityMilli = 1000,
    String? unit,
    int? unitPrice,
  }) {
    expect(line.name, name, reason: '$line');
    expect(line.amountPiastres, amount, reason: '$line');
    expect(line.quantityMilli, quantityMilli, reason: '$line');
    expect(line.unit, unit, reason: '$line');
    expect(line.unitPricePiastres, unitPrice, reason: '$line');
  }

  group('spec §9.1 spoken cases', () {
    test('"٢ كيلو طماطم ب ٣٠ و عيش ب ١٠" is two lines', () {
      final lines = parse('٢ كيلو طماطم ب ٣٠ و عيش ب ١٠');
      expect(lines, hasLength(2));
      expectLine(
        lines[0],
        name: 'طماطم',
        amount: 3000,
        quantityMilli: 2000,
        unit: 'kg',
      );
      expectLine(lines[1], name: 'عيش', amount: 1000);
    });

    test('"نص كيلو جبنة بـ ٨٥"', () {
      expectLine(
        one('نص كيلو جبنة بـ ٨٥'),
        name: 'جبنة',
        amount: 8500,
        quantityMilli: 500,
        unit: 'kg',
      );
    });

    test('"تلت علب تونة الواحدة ب ٤٥" is three at 45 each', () {
      expectLine(
        one('تلت علب تونة الواحدة ب ٤٥'),
        name: 'تونة',
        amount: 13500,
        quantityMilli: 3000,
        unit: 'box',
        unitPrice: 4500,
      );
    });

    test('"ازازتين مية ب عشرين جنيه": مية is water, not a hundred', () {
      expectLine(
        one('ازازتين مية ب عشرين جنيه'),
        name: 'مية',
        amount: 2000,
        quantityMilli: 2000,
        unit: 'bottle',
      );
    });

    test('"خمسة وعشرين جنيه ونص سجاير"', () {
      expectLine(
        one('خمسة وعشرين جنيه ونص سجاير'),
        name: 'سجاير',
        amount: 2550,
      );
    });

    test('"كيس عيش ب ٥ و كانز بيبسي ب ٢٠ وكمان شيبسي ب ١٠" is three '
        'lines', () {
      final lines = parse('كيس عيش ب ٥ و كانز بيبسي ب ٢٠ وكمان شيبسي ب ١٠');
      expect(lines, hasLength(3));
      expectLine(lines[0], name: 'عيش', amount: 500, unit: 'bag');
      expectLine(lines[1], name: 'بيبسي', amount: 2000, unit: 'can');
      expectLine(lines[2], name: 'شيبسي', amount: 1000);
      expect(lines[2].itemId, 'item-14');
    });

    test('"Indomi two 24"', () {
      final line = one('Indomi two 24');
      expectLine(line, name: 'إندومي', amount: 2400, quantityMilli: 2000);
      expect(line.itemId, 'item-05');
    });

    test('a line with no price has no amount and is low', () {
      final line = one('عيش');
      expect(line.amountPiastres, isNull);
      expect(line.confidence, ParseConfidence.low);
      expect(line.flags, contains(ParseFlag.noAmount));
    });
  });

  group('price markers and currency', () {
    test('ب glued to its digits', () {
      expectLine(one('عيش ب١٠'), name: 'عيش', amount: 1000);
      expectLine(one('عيش بـ١٠'), name: 'عيش', amount: 1000);
    });

    test('ب followed by a number word', () {
      expectLine(one('فول ب خمستاشر'), name: 'فول', amount: 1500);
    });

    test('a number before جنيه is the price even with another number', () {
      expectLine(
        one('٣ طماطم ٣٠ جنيه'),
        name: 'طماطم',
        amount: 3000,
        quantityMilli: 3000,
      );
    });

    test('ج and ج.م after a number', () {
      expectLine(one('شاي ١٠ ج'), name: 'شاي', amount: 1000);
      expectLine(one('شاي ١٠ ج.م'), name: 'شاي', amount: 1000);
    });

    test('LE and EGP on either side of the number', () {
      expectLine(one('10 LE water'), name: 'water', amount: 1000);
      expectLine(one('EGP 25 coffee'), name: 'coffee', amount: 2500);
    });

    test('قرش is piastres', () {
      expectLine(one('مناديل ٥٠ قرش'), name: 'مناديل', amount: 50);
    });

    test('N جنيه ونص adds fifty piastres', () {
      expectLine(one('قهوة ١٥ جنيه ونص'), name: 'قهوة', amount: 1550);
      expectLine(one('قهوة ١٥ جنيه و نص'), name: 'قهوة', amount: 1550);
    });

    test('decimal amounts with the Arabic decimal comma', () {
      expectLine(one('قهوة ١٢٫٥'), name: 'قهوة', amount: 1250);
    });

    test('number words for hundreds and thousands', () {
      expectLine(one('مية وخمسين جنيه بنزين'), name: 'بنزين', amount: 15000);
      expectLine(one('ميتين جنيه كهربا'), name: 'كهربا', amount: 20000);
      expectLine(one('تلتمية جنيه نت'), name: 'نت', amount: 30000);
      expectLine(one('الف جنيه ايجار'), name: 'ايجار', amount: 100000);
      expectLine(one('تلات آلاف جنيه جمعية'), name: 'جمعية', amount: 300000);
      expectLine(one('ستمية وخمسة وسبعين زيارة'), name: 'زيارة', amount: 67500);
    });

    test('مية after ب is a hundred', () {
      expectLine(one('جزمة ب مية'), name: 'جزمة', amount: 10000);
    });

    test('a bare number word is the price', () {
      expectLine(one('عيش خمسة'), name: 'عيش', amount: 500);
      expectLine(one('chips twenty'), name: 'شيبسي', amount: 2000);
    });
  });

  group('unit prices', () {
    test('"X الكيلو" is a unit price times the stated kilos', () {
      expectLine(
        one('بطاطس ٢ كيلو ١٢ الكيلو'),
        name: 'بطاطس',
        amount: 2400,
        quantityMilli: 2000,
        unit: 'kg',
        unitPrice: 1200,
      );
    });

    test('"الكيلو ب X"', () {
      expectLine(
        one('٣ كيلو برتقال الكيلو ب ١٥'),
        name: 'برتقال',
        amount: 4500,
        quantityMilli: 3000,
        unit: 'kg',
        unitPrice: 1500,
      );
    });

    test('a total and a unit price give the quantity', () {
      expectLine(
        one('ماندولين شيكولاته ٣٠ الواحده ب ٦'),
        name: 'مولتو ماندولين شوكولاتة',
        amount: 3000,
        quantityMilli: 5000,
        unitPrice: 600,
      );
    });

    test('"كل واحدة ب X" before a count', () {
      expectLine(
        one('كل واحدة ب ١٠ اتنين كانز'),
        name: '',
        amount: 2000,
        quantityMilli: 2000,
        unit: 'can',
        unitPrice: 1000,
      );
    });

    test('a bare count right after a price at the end of the line is a '
        'unit price, low', () {
      final line = one('انودي ١٢ اتنين');
      expectLine(
        line,
        name: 'إندومي',
        amount: 2400,
        quantityMilli: 2000,
        unitPrice: 1200,
      );
      expect(line.confidence, ParseConfidence.low);
      expect(line.flags, contains(ParseFlag.ambiguousAmount));
    });

    test('a count before the name leaves the price a total', () {
      expectLine(
        one('٣٠ اتنين هوهوز'),
        name: 'هوهوز',
        amount: 3000,
        quantityMilli: 2000,
      );
      expectLine(
        one('باتية اتنين ٤٠'),
        name: 'باتية',
        amount: 4000,
        quantityMilli: 2000,
      );
    });
  });

  group('quantities and units', () {
    test('fractions of a kilo', () {
      expectLine(
        one('ربع كيلو جبنة رومي ب ٧٠'),
        name: 'جبنة رومي',
        amount: 7000,
        quantityMilli: 250,
        unit: 'kg',
      );
      expectLine(
        one('تلت كيلو زيتون ب ٢٠'),
        name: 'زيتون',
        amount: 2000,
        quantityMilli: 333,
        unit: 'kg',
      );
    });

    test('كيلو ونص and N ونص', () {
      expectLine(
        one('كيلو ونص لحمة ب ٤٥٠'),
        name: 'لحمة',
        amount: 45000,
        quantityMilli: 1500,
        unit: 'kg',
      );
      expectLine(
        one('٢ ونص كيلو رز ب ٥٠'),
        name: 'رز',
        amount: 5000,
        quantityMilli: 2500,
        unit: 'kg',
      );
    });

    test('dual forms carry a count of two', () {
      expectLine(
        one('علبتين تونة ب ٩٠'),
        name: 'تونة',
        amount: 9000,
        quantityMilli: 2000,
        unit: 'box',
      );
      expectLine(
        one('كيلوين رز ب ٦٠'),
        name: 'رز',
        amount: 6000,
        quantityMilli: 2000,
        unit: 'kg',
      );
      expectLine(
        one('كيسين عيش ب ١٠'),
        name: 'عيش',
        amount: 1000,
        quantityMilli: 2000,
        unit: 'bag',
      );
    });

    test('unit synonyms', () {
      expect(one('باكو شاي ب ٢٥').unit, 'pack');
      expect(one('شريط برشام ب ٤٠').unit, 'strip');
      expect(one('حتة جاتوه ب ٣٥').unit, 'piece');
      expect(one('قطعة جاتوه ب ٣٥').unit, 'piece');
      expect(one('زجاجة زيت ب ٩٠').unit, 'bottle');
      expect(one('٢ ك طماطم ب ٣٠').unit, 'kg');
      expect(one('١ كجم طماطم ب ١٥').unit, 'kg');
    });

    test('people', () {
      expectLine(
        one('مواصلات ٤ افراد ٨٠'),
        name: 'مواصلات',
        amount: 8000,
        quantityMilli: 4000,
        unit: 'person',
      );
      expectLine(
        one('سينما شخصين ب ٣٠٠'),
        name: 'سينما',
        amount: 30000,
        quantityMilli: 2000,
        unit: 'person',
      );
    });

    test('a number attached to a unit is the quantity, the other the '
        'price', () {
      expectLine(
        one('٢ كيلو طماطم ٣٠'),
        name: 'طماطم',
        amount: 3000,
        quantityMilli: 2000,
        unit: 'kg',
      );
      expectLine(
        one('طماطم ٣٠ ٢ كيلو'),
        name: 'طماطم',
        amount: 3000,
        quantityMilli: 2000,
        unit: 'kg',
      );
    });

    test('a later counted unit wins over a bare one', () {
      expectLine(
        one('كيس عيش ١٥ تلت اكياس'),
        name: 'عيش',
        amount: 1500,
        quantityMilli: 3000,
        unit: 'bag',
      );
    });

    test('a trailing fraction with no unit stays in the name', () {
      expectLine(one('لبن نص ٣٠'), name: 'لبن نص', amount: 3000);
    });
  });

  group('splitting', () {
    test('on newline, ، , and +', () {
      expect(parse('شاي ١٠\nسكر ٣٠'), hasLength(2));
      expect(parse('طماطم ب 30، خيار ب 20'), hasLength(2));
      expect(parse('شاي ١٠, سكر ٣٠'), hasLength(2));
      expect(parse('طماطم ٣٠ + خيار ٢٠'), hasLength(2));
    });

    test('a comma between digits is a thousands separator', () {
      expectLine(one('موبايل 1,500'), name: 'موبايل', amount: 150000);
    });

    test('و splits only when both sides have an amount', () {
      final laundry = one('غسيل و كوي جاكيت ٥٠');
      expectLine(laundry, name: 'غسيل وكوي جاكيت', amount: 5000);
      final items = parse('طماطم ب 30 و عيش ب 10');
      expect(items.map((l) => l.name), ['طماطم', 'عيش']);
    });

    test('a و with an amountless left side joins it to the right', () {
      final lines = parse('عيش و فول ب ٢٠ و طماطم ب ٣٠');
      expect(lines.map((l) => l.name), ['عيش وفول', 'طماطم']);
      expect(lines.map((l) => l.amountPiastres), [2000, 3000]);
    });

    test('a و glued to ب splits like "و ب"', () {
      for (final text in ['عيش ب 40 وب 20 لبن', 'عيش بـ٤٠ وبـ٢٠ لبن']) {
        final lines = parse(text);
        expect(lines, hasLength(2), reason: '"$text" gave $lines');
        expectLine(lines[0], name: 'عيش', amount: 4000);
        expectLine(lines[1], name: 'لبن', amount: 2000);
      }
    });

    test('و inside a number phrase never splits', () {
      expectLine(one('سجاير خمسة و عشرين'), name: 'سجاير', amount: 2500);
    });

    test('blank lines are ignored', () {
      expect(parse('\n  \nشاي ١٠\n\n'), hasLength(1));
      expect(parse(''), isEmpty);
    });
  });

  group('normalisation', () {
    test('tatweel and diacritics leave the name', () {
      expectLine(one('شـــايٌ ١٠'), name: 'شاي', amount: 1000);
    });

    test('Latin and Eastern digits read the same', () {
      expect(one('شاي 10').amountPiastres, one('شاي ١٠').amountPiastres);
    });

    test('the raw text is kept as written', () {
      expect(one('شـــايٌ ١٠').rawText, 'شـــايٌ ١٠');
    });
  });

  group('dates', () {
    test('the capture day by default', () {
      expect(one('شاي ١٠').date, DateTime(2026, 9, 29));
    });

    test('before five in the morning is the previous day', () {
      final lines = parse('شاي ١٠', at: DateTime(2026, 9, 30, 4, 59));
      expect(lines.single.date, DateTime(2026, 9, 29));
      final five = parse('شاي ١٠', at: DateTime(2026, 9, 30, 5));
      expect(five.single.date, DateTime(2026, 9, 30));
    });

    test('a d/m line dates the lines after it', () {
      final lines = parse('شاي ١٠\n٢٠/٩\nسكر ٣٠\nعيش ٥');
      expect(lines, hasLength(3));
      expect(lines[0].date, DateTime(2026, 9, 29));
      expect(lines[0].flags, isNot(contains(ParseFlag.dateFromText)));
      expect(lines[1].date, DateTime(2026, 9, 20));
      expect(lines[2].date, DateTime(2026, 9, 20));
      expect(lines[2].flags, contains(ParseFlag.dateFromText));
    });

    test('d/m/yy and d/m/yyyy', () {
      expect(parse('٥/١٠/٢٥\nشاي ١٠').single.date, DateTime(2025, 10, 5));
      expect(parse('5/10/2025\nشاي ١٠').single.date, DateTime(2025, 10, 5));
    });

    test('a d/m far after the capture date belongs to last year', () {
      final lines = parse('٣٠/١٢\nشاي ١٠', at: DateTime(2027, 1, 2, 12));
      expect(lines.single.date, DateTime(2026, 12, 30));
    });

    test('an impossible date is not a date line', () {
      final lines = parse('٣٢/١٣\nشاي ١٠');
      expect(lines.last.date, DateTime(2026, 9, 29));
    });

    test('an impossible d/m line is not read as a price', () {
      final line = parse('31/9\nشاي ١٠').first;
      expect(line.amountPiastres, isNull, reason: '$line');
      expect(line.name, isEmpty, reason: '$line');
      expect(line.flags, contains(ParseFlag.noAmount));
    });

    test('a d/m inside a line is neither the price nor the name', () {
      expectLine(one('عيش ٥ ٢٧/٩'), name: 'عيش', amount: 500);
    });
  });

  group('confidence', () {
    test('an exact item with a price is high', () {
      final line = one('تاكسي ٤٥');
      expect(line.confidence, ParseConfidence.high);
      expect(line.categoryKey, 'Transport');
      expect(line.flags, isEmpty);
    });

    test('a typo match is medium and flagged', () {
      final line = one('تاكس ٢٥');
      expect(line.name, 'تاكسي');
      expect(line.confidence, ParseConfidence.medium);
      expect(line.flags, contains(ParseFlag.fuzzyMatch));
    });

    test('no category is low', () {
      final line = one('حاجة غريبة ٣٠');
      expect(line.categoryKey, isNull);
      expect(line.confidence, ParseConfidence.low);
      expect(line.flags, contains(ParseFlag.noCategory));
    });

    test('two bare digits are ambiguous', () {
      final line = one('طماطم ٣ ٣٠');
      expect(line.amountPiastres, 3000);
      expect(line.quantityMilli, 3000);
      expect(line.confidence, ParseConfidence.low);
      expect(line.flags, contains(ParseFlag.ambiguousAmount));
    });
  });

  group('products sold by the litre or the gram', () {
    final milkParser = ArabicLineParser(ParserCatalogue(
      items: const [
        CatalogueItem('cow', 'لبن بقري سايب', 'Drinks', 'Milk',
            unit: 'liter', unitPricePiastres: 2500, usualQuantityMilli: 2000),
        CatalogueItem('buffalo', 'لبن جاموسي سايب', 'Drinks', 'Milk',
            unit: 'liter'),
      ],
      subcategories: const [CatalogueSubcategory('Milk', 'Drinks', 'لبن')],
    ));
    ParsedLine milk(String text) {
      final lines = milkParser.parse(text, capturedAt: afternoon);
      expect(lines, hasLength(1), reason: '"$text" gave $lines');
      return lines.single;
    }

    test('لتر and جرام are units', () {
      expectLine(one('2 لتر زيت ب 150'),
          name: 'زيت', amount: 15000, quantityMilli: 2000, unit: 'liter');
      expectLine(one('نص لتر عصير ب 20'),
          name: 'عصير', amount: 2000, quantityMilli: 500, unit: 'liter');
      expectLine(one('لترين مياه ب 16'),
          name: 'مياه', amount: 1600, quantityMilli: 2000, unit: 'liter');
      expectLine(one('250 جرام جبنة ب 40'),
          name: 'جبنة', amount: 4000, quantityMilli: 250000, unit: 'g');
    });

    test('"2 لتر لبن بقري سايب" is priced at 25 a litre', () {
      final line = milk('2 لتر لبن بقري سايب');
      expect(line.itemId, 'cow');
      expectLine(line,
          name: 'لبن بقري سايب',
          amount: 5000,
          quantityMilli: 2000,
          unit: 'liter',
          unitPrice: 2500);
      expect(line.flags, isNot(contains(ParseFlag.noAmount)));
    });

    test('the product alone is its usual 2 litres', () {
      expectLine(milk('لبن بقري سايب'),
          name: 'لبن بقري سايب',
          amount: 5000,
          quantityMilli: 2000,
          unit: 'liter',
          unitPrice: 2500);
    });

    test('"نص لتر" of it is 12.50', () {
      expectLine(milk('نص لتر لبن بقري سايب'),
          name: 'لبن بقري سايب',
          amount: 1250,
          quantityMilli: 500,
          unit: 'liter',
          unitPrice: 2500);
    });

    test('"2 لتر لبن بقري سايب ب 25" reads 25 as the price of a litre', () {
      expectLine(milk('2 لتر لبن بقري سايب ب 25'),
          name: 'لبن بقري سايب',
          amount: 5000,
          quantityMilli: 2000,
          unit: 'liter',
          unitPrice: 2500);
    });

    test('a different price is the total paid', () {
      expectLine(milk('2 لتر لبن بقري سايب ب 60'),
          name: 'لبن بقري سايب',
          amount: 6000,
          quantityMilli: 2000,
          unit: 'liter');
    });

    test('a product with no price yet keeps asking for the amount', () {
      final line = milk('3 لتر لبن جاموسي سايب');
      expectLine(line,
          name: 'لبن جاموسي سايب',
          amount: null,
          quantityMilli: 3000,
          unit: 'liter');
      expect(line.flags, contains(ParseFlag.noAmount));
    });
  });
}
