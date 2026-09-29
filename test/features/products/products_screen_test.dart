import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/product_catalog_source.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/product_catalog.dart';
import 'package:spending_tracker/features/capture/permission_prompt.dart';
import 'package:spending_tracker/features/products/products_screen.dart';

import '../capture/permission_fakes.dart';

/// A scanner that hands back the codes queued in [next], one per scan.
class _Scanner implements BarcodeScanService {
  final next = <String?>[];
  int calls = 0;

  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    return next.isEmpty ? null : next.removeAt(0);
  }

  @override
  Future<List<String>> scanMany(BuildContext context) async => const [];
}

ProductCatalog _catalog() => ProductCatalog.parse(
    File('test/fixtures/catalog/egypt_products_sample.json')
        .readAsStringSync());

void main() {
  late FixtureSpendingRepository repo;
  late _Scanner scanner;

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ProductsScreen(
          repository: repo,
          catalog: ProductCatalogSource.fixed(_catalog()),
          scanner: scanner,
          permissionService:
              FakePermissionService(AppPermissionStatus.granted),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('products-search')), text);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  setUp(() {
    repo = FixtureSpendingRepository();
    scanner = _Scanner();
  });

  group('منتجاتي', () {
    testWidgets('lists the user\'s items with category, price and barcode',
        (tester) async {
      await repo.createItem(
          nameAr: 'كوكاكولا',
          categoryKey: 'Drinks',
          defaultAmountPiastres: 1500,
          barcode: '5449000000996');
      await pump(tester);
      final row = find.byKey(const Key('product-i1'));
      expect(find.descendant(of: row, matching: find.text('شويبس')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('مشروبات')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('40')),
          findsWidgets);
      await search(tester, 'كوكا');
      final cola = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('product-'));
      expect(cola, findsOneWidget);
      // Brand and size come from the catalogue entry of its barcode.
      expect(find.descendant(of: cola, matching: find.textContaining('330 مل')),
          findsOneWidget);
      expect(find.descendant(of: cola, matching: find.text('5449000000996')),
          findsOneWidget);
    });

    testWidgets('search reads Arabic spelling variants and barcodes',
        (tester) async {
      await repo.createItem(
          nameAr: 'مكرونة', categoryKey: 'Food', barcode: '6221007012345');
      await pump(tester);
      await search(tester, 'مكرونه');
      expect(find.text('مكرونة'), findsOneWidget);
      expect(find.text('شويبس'), findsNothing);
      await search(tester, '70123');
      expect(find.text('مكرونة'), findsOneWidget);
      await search(tester, 'لا يوجد');
      expect(find.byKey(const Key('products-empty')), findsOneWidget);
    });

    testWidgets('a category chip filters the list', (tester) async {
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-filter-Transport')));
      expect(find.text('تاكسي'), findsOneWidget);
      expect(find.text('شويبس'), findsNothing);
      await tap(tester, find.byKey(const Key('products-filter-all')));
      expect(find.text('شويبس'), findsOneWidget);
    });

    testWidgets('editing a product saves its name, subcategory, price and '
        'barcode', (tester) async {
      await pump(tester);
      await tap(tester, find.byKey(const Key('product-i2')));
      expect(fieldText(tester, 'product-name'), 'إندومي');
      await tester.enterText(
          find.byKey(const Key('product-name')), 'إندومي خضار');
      await tester.enterText(find.byKey(const Key('product-price')), '12.50');
      await tester.enterText(
          find.byKey(const Key('product-barcode')), '6221000000123');
      await tap(tester, find.byKey(const Key('product-subcategory-Groceries')));
      await tap(tester, find.byKey(const Key('product-save')));

      final item = (await repo.allItems()).firstWhere((i) => i.id == 'i2');
      expect(item.nameAr, 'إندومي خضار');
      expect(item.defaultAmountPiastres, 1250);
      expect(item.subcategoryKey, 'Groceries');
      expect(item.barcode, '6221000000123');
      expect(find.text('إندومي خضار'), findsOneWidget);
    });

    testWidgets('a barcode another product holds is refused in Arabic and '
        'nothing is saved', (tester) async {
      await repo.createItem(
          nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6221');
      await pump(tester);
      await tap(tester, find.byKey(const Key('product-i2')));
      await tester.enterText(find.byKey(const Key('product-name')), 'تغيير');
      await tester.enterText(find.byKey(const Key('product-barcode')), '6221');
      await tap(tester, find.byKey(const Key('product-save')));

      expect(find.text('الباركود ده مسجل على «بيبسي»'), findsOneWidget);
      expect(find.byKey(const Key('product-editor')), findsOneWidget);
      final item = (await repo.allItems()).firstWhere((i) => i.id == 'i2');
      expect(item.nameAr, 'إندومي');
      expect(item.barcode, isNull);
    });

    testWidgets('the barcode field can be filled by scanning',
        (tester) async {
      scanner.next.add('6224000000001');
      await pump(tester);
      await tap(tester, find.byKey(const Key('product-i2')));
      await tap(tester, find.byKey(const Key('product-barcode-scan')));
      expect(fieldText(tester, 'product-barcode'), '6224000000001');
    });

    testWidgets('archiving moves a product to المؤرشفة, and bringing it back '
        'returns it', (tester) async {
      await pump(tester);
      await tap(tester, find.byKey(const Key('product-i1')));
      await tap(tester, find.byKey(const Key('product-archive')));
      expect(find.text('شويبس'), findsNothing);
      expect((await repo.archivedItems()).map((i) => i.id), contains('i1'));

      await tap(tester, find.byKey(const Key('products-filter-archived')));
      expect(find.text('شويبس'), findsOneWidget);
      await tap(tester, find.byKey(const Key('product-i1')));
      await tap(tester, find.byKey(const Key('product-unarchive')));
      expect((await repo.allItems()).map((i) => i.id), contains('i1'));
    });

    testWidgets('bringing back a product whose barcode another holds now '
        'says why and keeps it archived', (tester) async {
      final old = await repo.createItem(
          nameAr: 'بيبسي كانز', categoryKey: 'Drinks', barcode: '6221');
      await repo.archiveItem(old.id);
      await repo.createItem(
          nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6221');
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-filter-archived')));
      await tap(tester, find.byKey(Key('product-${old.id}')));
      await tap(tester, find.byKey(const Key('product-unarchive')));
      expect(find.text('الباركود ده مسجل على «بيبسي»'), findsOneWidget);
      expect((await repo.archivedItems()).map((i) => i.id), contains(old.id));
    });

    testWidgets('the editor shows the price paid each time, newest first',
        (tester) async {
      Future<void> buy(DateTime day, int amount) => repo.saveCapture(
            CaptureDraft(
              kind: CaptureKind.manual,
              date: day,
              lines: [
                CaptureLine(
                    amountPiastres: amount,
                    categoryKey: 'Food',
                    itemId: 'i2',
                    description: 'إندومي'),
              ],
            ),
          );
      await buy(DateTime(2026, 9, 1), 900);
      await buy(DateTime(2026, 9, 15), 1100);
      await pump(tester);
      await tap(tester, find.byKey(const Key('product-i2')));
      await tester.ensureVisible(find.byKey(const Key('product-history')));
      final first = find.byKey(const Key('price-0'));
      final second = find.byKey(const Key('price-1'));
      expect(find.descendant(of: first, matching: find.textContaining('11')),
          findsWidgets);
      expect(find.descendant(of: first, matching: find.textContaining('15')),
          findsWidgets);
      expect(find.descendant(of: second, matching: find.textContaining('9')),
          findsWidgets);
    });
  });

  group('adding', () {
    testWidgets('a product added by hand is saved', (tester) async {
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-add')));
      await tester.enterText(find.byKey(const Key('product-name')), 'سجائر');
      await tester.enterText(find.byKey(const Key('product-price')), '80');
      await tap(tester, find.byKey(const Key('product-category-Shopping')));
      await tap(tester, find.byKey(const Key('product-save')));
      final item = (await repo.allItems()).firstWhere((i) => i.nameAr == 'سجائر');
      expect(item.categoryKey, 'Shopping');
      expect(item.defaultAmountPiastres, 8000);
    });

    testWidgets('a new product needs a name and a category', (tester) async {
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-add')));
      await tap(tester, find.byKey(const Key('product-save')));
      expect(find.text('اكتب اسم المنتج'), findsOneWidget);
      expect(find.text('اختار الفئة'), findsOneWidget);
      expect(find.byKey(const Key('product-editor')), findsOneWidget);
    });

    testWidgets('scanning a known code opens that product', (tester) async {
      final item = await repo.createItem(
          nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6221');
      scanner.next.add('6221');
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-scan-add')));
      expect(fieldText(tester, 'product-name'), 'بيبسي');
      await tap(tester, find.byKey(const Key('product-save')));
      expect((await repo.allItems()).where((i) => i.barcode == '6221'),
          hasLength(1));
      expect((await repo.itemByBarcode('6221'))!.id, item.id);
    });

    testWidgets('scanning a catalogue code prefills it, and saving adds it',
        (tester) async {
      scanner.next.add('6221007012345');
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-scan-add')));
      expect(fieldText(tester, 'product-name'), 'مكرونة ريجينا قلم');
      expect(fieldText(tester, 'product-price'), '18.50');
      expect(fieldText(tester, 'product-barcode'), '6221007012345');
      await tap(tester, find.byKey(const Key('product-save')));
      final item = (await repo.itemByBarcode('6221007012345'))!;
      expect(item.nameAr, 'مكرونة ريجينا قلم');
      expect(item.categoryKey, 'Pantry');
      expect(item.subcategoryKey, 'Pasta');
      expect(item.defaultAmountPiastres, 1850);
    });

    testWidgets('scanning an unknown code opens a new product holding it',
        (tester) async {
      scanner.next.add('9999');
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-scan-add')));
      expect(fieldText(tester, 'product-name'), '');
      expect(fieldText(tester, 'product-barcode'), '9999');
    });

    testWidgets('backing out of the scanner opens nothing', (tester) async {
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-scan-add')));
      expect(scanner.calls, 1);
      expect(find.byKey(const Key('product-editor')), findsNothing);
    });
  });

  group('الدليل', () {
    testWidgets('browses the catalogue with brand, size, price and barcode, '
        'searchable by brand', (tester) async {
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-tab-catalogue')));
      final row = find.byKey(const Key('catalogue-6221007012345'));
      expect(find.descendant(of: row, matching: find.text('مكرونة ريجينا قلم')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('Regina')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('400 جم')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('18.50')),
          findsOneWidget);
      await search(tester, 'جهينه');
      expect(find.byKey(const Key('catalogue-6223000501234')), findsOneWidget);
      expect(find.byKey(const Key('catalogue-6221007012345')), findsNothing);
    });

    testWidgets('أضف لمنتجاتي copies a product into the user\'s items '
        'without recording a purchase', (tester) async {
      final before = (await repo.watchTransactions().first).length;
      await pump(tester);
      await tap(tester, find.byKey(const Key('products-tab-catalogue')));
      await tap(tester, find.byKey(const Key('catalogue-6221007012345')));
      await tap(tester, find.byKey(const Key('catalogue-add-mine')));

      final item = (await repo.itemByBarcode('6221007012345'))!;
      expect(item.nameAr, 'مكرونة ريجينا قلم');
      expect(item.categoryKey, 'Pantry');
      expect(item.defaultAmountPiastres, 1850);
      expect((await repo.watchTransactions().first).length, before);

      // It is now in منتجاتي, and the catalogue says so.
      await tap(tester, find.byKey(const Key('catalogue-6221007012345')));
      expect(find.byKey(const Key('catalogue-in-mine')), findsOneWidget);
    });

    testWidgets('an empty catalogue says so', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: ProductsScreen(
          repository: repo,
          catalog: ProductCatalogSource.fixed(ProductCatalog.empty),
          scanner: scanner,
        ),
      ));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('products-tab-catalogue')));
      expect(find.byKey(const Key('products-empty')), findsOneWidget);
    });
  });

  testWidgets('every tappable control clears 48dp, in dark mode too',
      (tester) async {
    await pump(tester, dark: true);
    for (final key in [
      'products-add',
      'products-scan-add',
      'products-filter-all',
      'products-tab-catalogue',
    ]) {
      expect(tester.getSize(find.byKey(Key(key))).height,
          greaterThanOrEqualTo(48), reason: key);
    }
    expect(tester.getSize(find.byKey(const Key('product-i1'))).height,
        greaterThanOrEqualTo(48));
  });
}
