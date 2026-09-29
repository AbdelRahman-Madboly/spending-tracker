import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';
import 'package:spending_tracker/domain/smart_parse.dart';

void main() {
  const catalogue = SmartCatalogue(
    categories: [
      CategoryView(key: 'Food', labelAr: 'أكل', iconName: 'restaurant'),
      CategoryView(key: 'Transport', labelAr: 'مواصلات', iconName: 'bus'),
    ],
    subcategories: [
      SubcategoryView(
          key: 'Bread', categoryKey: 'Food', labelAr: 'عيش', iconName: 'x'),
      SubcategoryView(
          key: 'Taxi', categoryKey: 'Transport', labelAr: 'تاكسي', iconName: 'x'),
    ],
    items: [
      QuickPickItem(
          id: 'item-bread',
          nameAr: 'عيش بلدي',
          categoryKey: 'Food',
          subcategoryKey: 'Bread'),
    ],
  );
  final day = DateTime(2026, 9, 22);

  String response(Map<String, Object?> body) => jsonEncode(body);

  group('the request', () {
    test('the schema limits keys to the catalogue and asks for strings', () {
      final schema = smartResponseSchema(catalogue);
      final line = ((schema['properties'] as Map)['lines'] as Map)['items']
          as Map;
      final props = line['properties'] as Map;
      expect((props['categoryKey'] as Map)['enum'], ['Food', 'Transport']);
      expect((props['subcategoryKey'] as Map)['enum'], ['Bread', 'Taxi']);
      expect((props['itemId'] as Map)['enum'], ['item-bread']);
      expect((props['amount'] as Map)['type'], 'string');
      expect((props['quantity'] as Map)['type'], 'string');
      expect((props['unit'] as Map)['enum'],
          containsAll(['none', 'kg', 'bag', 'bottle', 'piece']));
      expect(schema['required'], containsAll(['cleanText', 'lines']));
    });

    test('the prompt names the categories, subcategories and items', () {
      final prompt = smartPrompt(catalogue, SmartInputKind.text);
      expect(prompt, contains('Food: أكل'));
      expect(prompt, contains('Taxi (Transport): تاكسي'));
      expect(prompt, contains('item-bread: عيش بلدي'));
      expect(prompt, contains('Egyptian Arabic'));
      expect(prompt, contains('Do not invent'));
    });

    test('an item without an id enum stays out of the schema when there '
        'are no items', () {
      const empty = SmartCatalogue(
          categories: [
            CategoryView(key: 'Food', labelAr: 'أكل', iconName: 'x'),
          ],
          subcategories: [],
          items: []);
      final line = ((smartResponseSchema(empty)['properties'] as Map)['lines']
          as Map)['items'] as Map;
      expect((line['properties'] as Map).containsKey('itemId'), isFalse);
      expect((line['properties'] as Map).containsKey('subcategoryKey'),
          isFalse);
    });
  });

  group('reading the answer', () {
    test('reads lines into parsed lines with piastres and milli-units', () {
      final result = readSmartResult(
          response({
            'cleanText': 'طماطم 2 كيلو ب 30\nتاكسي ب 45.5',
            'lines': [
              {
                'name': 'طماطم',
                'quantity': '2',
                'unit': 'kg',
                'amount': '30',
                'unitPrice': '15',
                'categoryKey': 'Food',
              },
              {
                'name': 'تاكسي',
                'quantity': '1',
                'unit': 'none',
                'amount': '45.50',
                'categoryKey': 'Transport',
                'subcategoryKey': 'Taxi',
              },
            ],
          }),
          catalogue,
          day: day)!;
      expect(result.cleanText, 'طماطم 2 كيلو ب 30\nتاكسي ب 45.5');
      expect(result.date, isNull);
      final [tomato, taxi] = result.lines;
      expect(tomato.name, 'طماطم');
      expect(tomato.quantityMilli, 2000);
      expect(tomato.unit, 'kg');
      expect(tomato.amountPiastres, 3000);
      expect(tomato.unitPricePiastres, 1500);
      expect(tomato.categoryKey, 'Food');
      expect(tomato.date, day);
      expect(taxi.unit, isNull);
      expect(taxi.amountPiastres, 4550);
      expect(taxi.subcategoryKey, 'Taxi');
      expect(taxi.flags, isEmpty);
    });

    test('an item id takes that item\'s category and subcategory', () {
      final result = readSmartResult(
          response({
            'cleanText': 'عيش ب 10',
            'lines': [
              {
                'name': 'عيش',
                'quantity': '1',
                'unit': 'bag',
                'amount': '10',
                'categoryKey': 'Transport',
                'itemId': 'item-bread',
              },
            ],
          }),
          catalogue,
          day: day)!;
      final line = result.lines.single;
      expect(line.itemId, 'item-bread');
      expect(line.categoryKey, 'Food');
      expect(line.subcategoryKey, 'Bread');
    });

    test('an unknown item id is dropped and a subcategory of another '
        'category is cleared', () {
      final line = readSmartResult(
          response({
            'cleanText': 'x',
            'lines': [
              {
                'name': 'عيش',
                'quantity': '1',
                'unit': 'none',
                'amount': '10',
                'categoryKey': 'Food',
                'subcategoryKey': 'Taxi',
                'itemId': 'made-up',
              },
            ],
          }),
          catalogue,
          day: day)!
          .lines
          .single;
      expect(line.itemId, isNull);
      expect(line.subcategoryKey, isNull);
      expect(line.categoryKey, 'Food');
    });

    test('a line with no amount is kept and flagged', () {
      final line = readSmartResult(
          response({
            'cleanText': 'عيش',
            'lines': [
              {
                'name': 'عيش',
                'quantity': '',
                'unit': 'none',
                'amount': '',
                'categoryKey': 'Food',
              },
            ],
          }),
          catalogue,
          day: day)!
          .lines
          .single;
      expect(line.amountPiastres, isNull);
      expect(line.quantityMilli, 1000);
      expect(line.flags, contains(ParseFlag.noAmount));
      expect(line.confidence, ParseConfidence.low);
    });

    test('a unit price with no total gives total = unit x quantity', () {
      final line = readSmartResult(
          response({
            'cleanText': 'انودي 2 الواحدة ب 15',
            'lines': [
              {
                'name': 'انودي',
                'quantity': '2.5',
                'unit': 'kg',
                'amount': '',
                'unitPrice': '15',
                'categoryKey': 'Food',
              },
            ],
          }),
          catalogue,
          day: day)!
          .lines
          .single;
      expect(line.amountPiastres, 3750);
      expect(line.unitPricePiastres, 1500);
      expect(line.flags, isNot(contains(ParseFlag.noAmount)));
      expect(line.confidence, ParseConfidence.medium);
    });

    test('a date dates every line; a future or malformed one is ignored', () {
      Map<String, Object?> dated(String date) => {
            'date': date,
            'cleanText': 'عيش ب 10',
            'lines': [
              {
                'name': 'عيش',
                'quantity': '1',
                'unit': 'none',
                'amount': '10',
                'categoryKey': 'Food',
              },
            ],
          };
      final result =
          readSmartResult(response(dated('2026-09-20')), catalogue, day: day)!;
      expect(result.date, DateTime(2026, 9, 20));
      expect(result.lines.single.date, DateTime(2026, 9, 20));
      expect(result.lines.single.flags, contains(ParseFlag.dateFromText));

      for (final bad in ['2026-09-23', '20/9', '2026-13-40']) {
        final r = readSmartResult(response(dated(bad)), catalogue, day: day)!;
        expect(r.date, isNull, reason: bad);
        expect(r.lines.single.date, day, reason: bad);
      }
    });

    test('anything that does not match the schema gives null', () {
      final good = {
        'name': 'عيش',
        'quantity': '1',
        'unit': 'none',
        'amount': '10',
        'categoryKey': 'Food',
      };
      for (final bad in <String>[
        'not json',
        '[]',
        response({'lines': []}),
        response({'cleanText': 'x'}),
        response({'cleanText': 'x', 'lines': 'none'}),
        response({
          'cleanText': 'x',
          'lines': [
            {...good, 'categoryKey': 'Cars'},
          ],
        }),
        response({
          'cleanText': 'x',
          'lines': [
            {...good, 'amount': 'ten'},
          ],
        }),
        response({
          'cleanText': 'x',
          'lines': [
            {...good, 'amount': 10},
          ],
        }),
        response({
          'cleanText': 'x',
          'lines': [
            {...good, 'quantity': 'lots'},
          ],
        }),
        response({
          'cleanText': 'x',
          'lines': [
            {...good, 'unit': 'ton'},
          ],
        }),
        response({
          'cleanText': 'x',
          'lines': [
            {...good, 'name': '  '},
          ],
        }),
        response({
          'cleanText': 'x',
          'lines': ['عيش ب 10'],
        }),
      ]) {
        expect(readSmartResult(bad, catalogue, day: day), isNull, reason: bad);
      }
    });
  });
}
