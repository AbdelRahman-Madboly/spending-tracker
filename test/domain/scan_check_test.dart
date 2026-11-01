import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/product_catalog.dart';
import 'package:spending_tracker/domain/scan_check.dart';

void main() {
  final catalog = ProductCatalog.parse(
    File('test/fixtures/catalog/egypt_products_sample.json').readAsStringSync(),
  );

  group('readProductAnswer', () {
    test('reads a plain JSON answer', () {
      final info = readProductAnswer(
        '{"found": true, "nameAr": "شاي العروسة", "nameEn": "El Arosa Tea", '
        '"brand": "العروسة", "size": "250 جم", "priceEgp": "42.50", '
        '"priceSource": "Carrefour Egypt"}',
      )!;
      expect(info.nameAr, 'شاي العروسة');
      expect(info.nameEn, 'El Arosa Tea');
      expect(info.brand, 'العروسة');
      expect(info.size, '250 جم');
      expect(info.pricePiastres, 4250);
      expect(info.priceSource, 'Carrefour Egypt');
    });

    test('finds the JSON block inside prose and a code fence', () {
      final info = readProductAnswer(
        'I searched for the barcode. Here is what I found:\n'
        '```json\n{"nameAr": "", "nameEn": "Lipton Yellow Label", '
        '"brand": "Lipton", "size": "100 bags", "priceEgp": 95, '
        '"priceSource": "talabat"}\n```\nPrices vary {a lot}.',
      )!;
      expect(info.nameEn, 'Lipton Yellow Label');
      expect(info.displayName, 'Lipton Yellow Label');
      expect(info.pricePiastres, 9500);
    });

    test('a price written with its currency is still read', () {
      final info = readProductAnswer(
        '{"nameAr": "بسكويت", "priceEgp": "EGP 12,50"}',
      )!;
      expect(info.pricePiastres, 1250);
    });

    test('no price is a product with its price unknown', () {
      final info = readProductAnswer('{"nameAr": "مكرونة", "priceEgp": null}')!;
      expect(info.pricePiastres, isNull);
    });

    test('not found, no name, prose only or broken JSON is null', () {
      expect(readProductAnswer('{"found": false}'), isNull);
      expect(readProductAnswer('{"nameAr": "", "nameEn": ""}'), isNull);
      expect(readProductAnswer('Sorry, I could not find this product.'),
          isNull);
      expect(readProductAnswer('{"nameAr": "شاي", '), isNull);
      expect(readProductAnswer(''), isNull);
    });
  });

  group('checkBarcode', () {
    late FixtureSpendingRepository repo;

    setUp(() => repo = FixtureSpendingRepository());

    test('a code the user has is منتجاتي at its last price', () async {
      final item = await repo.createItem(
        nameAr: 'بيبسي كانز',
        categoryKey: 'Drinks',
        defaultAmountPiastres: 1500,
        barcode: '5449000000996',
      );
      var asked = 0;
      final found = await checkBarcode(
        '5449000000996',
        repository: repo,
        catalog: catalog,
        lookupName: (_) async {
          asked++;
          return 'x';
        },
      );
      expect(found.source, ScanSource.mine);
      expect(found.item?.id, item.id);
      expect(found.name, 'بيبسي كانز');
      expect(found.pricePiastres, 1500);
      expect(found.priceIsEstimate, isFalse);
      expect(found.categoryKey, 'Drinks');
      expect(asked, 0);
    });

    test('a catalogue code is الدليل with its details and typical price, '
        'and nothing is written', () async {
      final categories = (await repo.categories()).length;
      final items = (await repo.allItems()).length;
      final found = await checkBarcode(
        '6221007012345',
        repository: repo,
        catalog: catalog,
      );
      expect(found.source, ScanSource.catalogue);
      expect(found.name, 'مكرونة ريجينا قلم');
      expect(found.brand, 'Regina');
      expect(found.size, '400 جم');
      expect(found.pricePiastres, 1850);
      expect(found.priceIsEstimate, isTrue);
      expect(found.product?.barcode, '6221007012345');
      expect(found.categoryKey, 'Pantry');
      expect((await repo.categories()).length, categories);
      expect((await repo.allItems()).length, items);
    });

    test('an unknown code asks Open Food Facts first', () async {
      var searched = 0;
      final found = await checkBarcode(
        '1234567890123',
        repository: repo,
        catalog: catalog,
        lookupName: (_) async => 'Nutella 400 g',
        searchOnline: (_) async {
          searched++;
          return null;
        },
      );
      expect(found.source, ScanSource.openFoodFacts);
      expect(found.name, 'Nutella 400 g');
      expect(found.pricePiastres, isNull);
      expect(searched, 0);
    });

    test('then the web search, whose price is an estimate', () async {
      final found = await checkBarcode(
        '1234567890123',
        repository: repo,
        catalog: catalog,
        lookupName: (_) async => null,
        searchOnline: (_) async => const ProductInfo(
          nameAr: 'نوتيلا',
          nameEn: 'Nutella',
          brand: 'Ferrero',
          size: '400 جم',
          pricePiastres: 21000,
          priceSource: 'Carrefour',
        ),
      );
      expect(found.source, ScanSource.webSearch);
      expect(found.name, 'نوتيلا');
      expect(found.nameEn, 'Nutella');
      expect(found.pricePiastres, 21000);
      expect(found.priceIsEstimate, isTrue);
      expect(found.priceNote, 'Carrefour');
    });

    test('a failing lookup falls through to unknown with the code kept',
        () async {
      final found = await checkBarcode(
        '1234567890123',
        repository: repo,
        catalog: catalog,
        lookupName: (_) async => throw StateError('offline'),
        searchOnline: (_) async => throw StateError('offline'),
      );
      expect(found.source, ScanSource.unknown);
      expect(found.code, '1234567890123');
      expect(found.name, isEmpty);
      expect(found.pricePiastres, isNull);
    });
  });

  group('readProductPhoto', () {
    late FixtureSpendingRepository repo;

    setUp(() => repo = FixtureSpendingRepository());

    ScanFinding unknown() =>
        const ScanFinding(code: '1234567890123', source: ScanSource.unknown);

    test('the online reading of the pack fills the name, brand and size',
        () async {
      final found = await readProductPhoto(
        unknown(),
        repository: repo,
        catalog: catalog,
        online: const ProductInfo(
          nameAr: 'جبنة دومتي',
          nameEn: 'Domty Cheese',
          brand: 'Domty',
          size: '250 جم',
        ),
      );
      expect(found!.source, ScanSource.photo);
      expect(found.name, 'جبنة دومتي');
      expect(found.brand, 'Domty');
      expect(found.code, '1234567890123');
    });

    test('offline, a Latin brand word finds the user\'s product', () async {
      await repo.createItem(
        nameAr: 'Pepsi',
        categoryKey: 'Drinks',
        defaultAmountPiastres: 1200,
      );
      final found = await readProductPhoto(
        unknown(),
        repository: repo,
        catalog: catalog,
        ocrText: 'PEPSI\n330 ml',
      );
      expect(found!.source, ScanSource.photo);
      expect(found.name, 'Pepsi');
      expect(found.categoryKey, 'Drinks');
      expect(found.pricePiastres, 1200);
      expect(found.item, isNotNull,
          reason: 'an item with no barcode of its own learns this one');
    });

    test('offline, Latin words find a catalogue product', () async {
      final found = await readProductPhoto(
        unknown(),
        repository: repo,
        catalog: catalog,
        ocrText: 'REGINA\nPenne rigate\n400g',
      );
      expect(found!.source, ScanSource.photo);
      expect(found.name, 'مكرونة ريجينا قلم');
      expect(found.categoryKey, 'Pantry');
      expect(found.product, isNotNull);
    });

    test('offline, unmatched Latin words become the name to confirm',
        () async {
      final found = await readProductPhoto(
        unknown(),
        repository: repo,
        catalog: catalog,
        ocrText: 'Zabado\nStrawberry yoghurt',
      );
      expect(found!.source, ScanSource.photo);
      expect(found.name, 'Zabado Strawberry yoghurt');
    });

    test('nothing read is null', () async {
      expect(
        await readProductPhoto(unknown(),
            repository: repo, catalog: catalog, ocrText: '12 3'),
        isNull,
      );
    });
  });
}
