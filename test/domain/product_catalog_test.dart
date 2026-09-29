import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/product_catalog_source.dart';
import 'package:spending_tracker/domain/product_catalog.dart';

String sampleJson() =>
    File('test/fixtures/catalog/egypt_products_sample.json').readAsStringSync();

void main() {
  group('ProductCatalog.parse', () {
    test('reads the header, the additions and the products', () {
      final catalog = ProductCatalog.parse(sampleJson());
      expect(catalog.builtOn, DateTime(2026, 9, 28));
      expect(catalog.categories.map((c) => c.key), ['Pantry']);
      expect(catalog.categories.single.labelAr, 'بقالة');
      expect(catalog.categories.single.colorKey, 'Food');
      expect(catalog.subcategories.map((s) => s.key), ['Pasta', 'Nectar']);
      final pasta = catalog.byBarcode('6221007012345')!;
      expect(pasta.nameAr, 'مكرونة ريجينا قلم');
      expect(pasta.nameEn, 'Regina Penne');
      expect(pasta.brand, 'Regina');
      expect(pasta.size, '400 جم');
      expect(pasta.categoryKey, 'Pantry');
      expect(pasta.subcategoryKey, 'Pasta');
      expect(pasta.pricePiastres, 1850);
      expect(pasta.priceSource, 'seoudi');
      expect(pasta.priceDate, DateTime(2026, 9, 20));
    });

    test('a product with no price has a null price', () {
      final juice =
          ProductCatalog.parse(sampleJson()).byBarcode('6223000501234')!;
      expect(juice.pricePiastres, isNull);
      expect(juice.priceDate, isNull);
    });

    test('rows with no barcode or no Arabic name are skipped, and of two '
        'rows with one barcode the first is kept', () {
      final catalog = ProductCatalog.parse(sampleJson());
      expect(catalog.products, hasLength(3));
      expect(catalog.byBarcode('6220000000001'), isNull);
      expect(catalog.byBarcode('5449000000996')!.nameAr, 'كوكاكولا كانز');
    });

    test('an unknown code is null, and a code is trimmed first', () {
      final catalog = ProductCatalog.parse(sampleJson());
      expect(catalog.byBarcode('000'), isNull);
      expect(catalog.byBarcode(' 5449000000996 ')!.brand, 'Coca-Cola');
    });

    test('a UPC-A code finds its EAN-13 row and the other way round', () {
      final catalog = ProductCatalog.parse(
          '{"format":"product-catalog/1","builtOn":"2026-09-28",'
          '"country":"EG","catalogueAdditions":{"categories":[],'
          '"subcategories":[]},"products":[{"barcode":"0012345678905",'
          '"nameAr":"أ","categoryKey":"Food"},{"barcode":"123456789012",'
          '"nameAr":"ب","categoryKey":"Food"}]}');
      expect(catalog.byBarcode('012345678905')!.nameAr, 'أ');
      expect(catalog.byBarcode('0123456789012')!.nameAr, 'ب');
    });

    test('another format is refused', () {
      expect(() => ProductCatalog.parse('{"format":"something/2"}'),
          throwsFormatException);
      expect(() => ProductCatalog.parse('not json'), throwsFormatException);
    });
  });

  group('ProductCatalog.search', () {
    final catalog = ProductCatalog.parse(sampleJson());

    test('matches the Arabic name through the normaliser', () {
      expect(catalog.search('مكرونه').map((p) => p.barcode),
          ['6221007012345']);
    });

    test('matches the brand and the English name, ignoring case', () {
      expect(catalog.search('coca').map((p) => p.barcode), ['5449000000996']);
      expect(catalog.search('جهينه').map((p) => p.barcode),
          ['6223000501234']);
    });

    test('matches part of a barcode', () {
      expect(catalog.search('50123').map((p) => p.barcode),
          ['6223000501234']);
    });

    test('filters by category', () {
      expect(
          catalog.search('', categoryKey: 'Drinks').map((p) => p.barcode),
          unorderedEquals(['6223000501234', '5449000000996']));
    });
  });

  group('ProductCatalogSource', () {
    test('loads once and indexes by barcode', () async {
      var reads = 0;
      final source = ProductCatalogSource(read: () async {
        reads++;
        return sampleJson();
      });
      final first = await source.load();
      final second = await source.load();
      expect(reads, 1);
      expect(identical(first, second), isTrue);
      expect(first.byBarcode('6221007012345'), isNotNull);
    });

    test('a missing file is an empty catalogue', () async {
      final source = ProductCatalogSource(
          read: () async => throw Exception('Unable to load asset'));
      final catalog = await source.load();
      expect(catalog.isEmpty, isTrue);
      expect(catalog.byBarcode('6221007012345'), isNull);
    });

    test('a broken file is an empty catalogue', () async {
      final source = ProductCatalogSource(read: () async => '{"format":1');
      expect((await source.load()).isEmpty, isTrue);
    });
  });

  group('ensureCatalogueCategory', () {
    late FixtureSpendingRepository repo;
    final catalog = ProductCatalog.parse(sampleJson());

    setUp(() => repo = FixtureSpendingRepository());

    test('an existing category and a new subcategory: the subcategory is '
        'created from the additions under it', () async {
      final juice = catalog.byBarcode('6223000501234')!;
      final keys = await ensureCatalogueCategory(repo, catalog, juice);
      expect(keys, (categoryKey: 'Drinks', subcategoryKey: 'Nectar'));
      final subs = await repo.subcategories('Drinks');
      expect(subs.where((s) => s.key == 'Nectar').single.labelAr, 'عصائر');
    });

    test('a missing category is created once, by key', () async {
      final pasta = catalog.byBarcode('6221007012345')!;
      await ensureCatalogueCategory(repo, catalog, pasta);
      final keys = await ensureCatalogueCategory(repo, catalog, pasta);
      expect(keys, (categoryKey: 'Pantry', subcategoryKey: 'Pasta'));
      final categories = await repo.categories();
      expect(categories.where((c) => c.key == 'Pantry'), hasLength(1));
      expect(categories.firstWhere((c) => c.key == 'Pantry').labelAr,
          'بقالة');
      expect((await repo.subcategories('Pantry')).map((s) => s.key),
          ['Pasta']);
    });

    test('an archived category is not brought back: the line is left for '
        'the user to file', () async {
      await repo.archiveCategory('Drinks');
      final cola = catalog.byBarcode('5449000000996')!;
      final keys = await ensureCatalogueCategory(repo, catalog, cola);
      expect(keys, (categoryKey: null, subcategoryKey: null));
      expect((await repo.categories()).map((c) => c.key),
          isNot(contains('Drinks')));
    });

    test('a category neither in the app nor in the additions is left '
        'blank', () async {
      const odd = CatalogueProduct(
          barcode: '1', nameAr: 'غريب', categoryKey: 'Nowhere');
      final keys = await ensureCatalogueCategory(repo, catalog, odd);
      expect(keys, (categoryKey: null, subcategoryKey: null));
    });
  });

  group('ensureCatalogueAdditions', () {
    late FixtureSpendingRepository repo;
    final catalog = ProductCatalog.parse(sampleJson());

    setUp(() => repo = FixtureSpendingRepository());

    test('creates every category and subcategory the catalogue adds, once',
        () async {
      await ensureCatalogueAdditions(repo, catalog);
      await ensureCatalogueAdditions(repo, catalog);
      final categories = await repo.categories();
      expect(categories.where((c) => c.key == 'Pantry'), hasLength(1));
      expect((await repo.subcategories('Pantry')).map((s) => s.key),
          ['Pasta']);
      expect(
          (await repo.subcategories('Drinks')).where((s) => s.key == 'Nectar'),
          hasLength(1));
    });

    test('never brings back a category or subcategory the user archived',
        () async {
      await repo.createCategory(
          key: 'Pantry', labelAr: 'مخزن', iconName: 'category');
      await repo.archiveCategory('Pantry');
      await repo.createSubcategory(
          key: 'Nectar',
          categoryKey: 'Drinks',
          labelAr: 'نكتار',
          iconName: 'category');
      await repo.archiveSubcategory('Nectar');

      await ensureCatalogueAdditions(repo, catalog);

      expect((await repo.categories()).map((c) => c.key),
          isNot(contains('Pantry')));
      expect((await repo.archivedCategories()).map((c) => c.key),
          contains('Pantry'));
      expect((await repo.subcategories('Drinks')).map((s) => s.key),
          isNot(contains('Nectar')));
    });

    test('an empty catalogue adds nothing', () async {
      final before = (await repo.categories()).length;
      await ensureCatalogueAdditions(repo, ProductCatalog.empty);
      expect(await repo.categories(), hasLength(before));
    });
  });
}
