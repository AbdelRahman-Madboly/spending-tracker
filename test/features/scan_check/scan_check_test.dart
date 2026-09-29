import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/net/network_gate.dart';
import 'package:spending_tracker/domain/online_features.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/data/net/product_lookup.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/data/product_catalog_source.dart';
import 'package:spending_tracker/data/text_recognition_service.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/product_catalog.dart';
import 'package:spending_tracker/domain/scan_check.dart';
import 'package:spending_tracker/features/capture/permission_prompt.dart';
import 'package:spending_tracker/features/review/review_sheet.dart';
import 'package:spending_tracker/features/scan_check/scan_check.dart';

import '../../data/net/gemini_client_test.dart' show MemoryKeyStore;
import '../capture/permission_fakes.dart';

/// Counts every write that would record a purchase.
class _SpyRepo extends FixtureSpendingRepository {
  int purchases = 0;

  @override
  Future<void> saveEntry(DraftEntry draft) {
    purchases++;
    return super.saveEntry(draft);
  }

  @override
  Future<String> saveCapture(CaptureDraft draft) {
    purchases++;
    return super.saveCapture(draft);
  }
}

class _Scanner implements BarcodeScanService {
  _Scanner(this.codes);

  final List<String?> codes;
  int calls = 0;

  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    return codes.isEmpty ? null : codes.removeAt(0);
  }

  @override
  Future<List<String>> scanMany(BuildContext context) async => const [];
}

class _Lookup implements ProductLookup {
  _Lookup(this.name);

  final String? name;

  @override
  Future<String?> nameFor(String barcode) async => name;
}

class _Online implements OnlineProductReader {
  _Online({this.found, this.fromPhoto});

  final ProductInfo? found;
  final ProductInfo? fromPhoto;

  @override
  Future<bool> canSearch() async => found != null;

  @override
  Future<ProductInfo?> search(String code) async => found;

  @override
  Future<bool> canReadPhoto() async => fromPhoto != null;

  @override
  Future<ProductInfo?> readPhoto(Uint8List jpeg) async => fromPhoto;
}

class _Photos implements PhotoCaptureService {
  final deleted = <String>[];
  int taken = 0;

  @override
  Future<PhotoCaptureResult> captureFromCamera() async {
    taken++;
    return const PhotoCaptureResult(
        PhotoCaptureOutcome.attached, 'attachments/pack.jpg');
  }

  @override
  Future<File> resolve(String relativePath) async =>
      File('/nowhere/$relativePath');

  @override
  Future<void> delete(String relativePath) async => deleted.add(relativePath);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ocr implements TextRecognitionService {
  _Ocr(this.text);

  final String text;

  @override
  Future<String> recognize(String absolutePath) async => text;
}

final _catalog = ProductCatalog.parse(
  File('test/fixtures/catalog/egypt_products_sample.json').readAsStringSync(),
);

void main() {
  late _SpyRepo repo;
  late _Scanner scanner;
  late _Photos photos;

  Future<void> run(
    WidgetTester tester,
    List<String?> codes, {
    ProductLookup? lookup,
    OnlineProductReader? online,
    bool realOnline = false,
    NetworkGate? gate,
    String ocr = '',
  }) async {
    scanner = _Scanner([...codes]);
    photos = _Photos();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => scanAndCheck(
                context,
                repo,
                scanner: scanner,
                productLookup: lookup,
                onlineReader: realOnline ? null : online ?? _Online(),
                networkGate: gate,
                geminiKeyStore: MemoryKeyStore('k-1'),
                productCatalog: ProductCatalogSource.fixed(_catalog),
                photoCaptureService: photos,
                textRecognition: _Ocr(ocr),
                readPhotoBytes: (_) async => Uint8List.fromList([1, 2, 3]),
                permissionService:
                    FakePermissionService(AppPermissionStatus.granted),
                clock: () => DateTime(2026, 9, 29, 12),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  Finder chip(String label) => find.descendant(
      of: find.byKey(const Key('scan-source')), matching: find.text(label));

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  setUp(() => repo = _SpyRepo());

  group('the result card', () {
    testWidgets('a product of منتجاتي shows its digits, name and price, and '
        'writes nothing on its own', (tester) async {
      await repo.createItem(
          nameAr: 'بيبسي كانز',
          categoryKey: 'Drinks',
          defaultAmountPiastres: 1500,
          barcode: '5449000000996');
      final items = (await repo.allItems()).length;
      await run(tester, ['5449000000996']);

      expect(find.byKey(const Key('scan-result')), findsOneWidget);
      final digits = tester.widget<Text>(find.byKey(const Key('scan-code')));
      expect(digits.data, '5449000000996');
      expect(digits.textDirection, TextDirection.ltr);
      expect(digits.style?.fontFamily, 'monospace');
      expect(chip('منتجاتي'), findsOneWidget);
      expect(find.text('بيبسي كانز'), findsOneWidget);
      expect(find.textContaining('15'), findsWidgets);
      expect(find.text('احفظ التعديل'), findsOneWidget);
      expect(repo.purchases, 0);
      expect((await repo.allItems()).length, items);
    });

    testWidgets('a catalogue product shows الدليل, its brand and size and '
        'its typical price to confirm', (tester) async {
      await run(tester, ['6221007012345']);
      expect(chip('الدليل'), findsOneWidget);
      expect(find.text('مكرونة ريجينا قلم'), findsOneWidget);
      expect(find.textContaining('400 جم'), findsOneWidget);
      expect(find.textContaining('Regina'), findsWidgets);
      final price =
          tester.widget<TextField>(find.byKey(const Key('scan-price')));
      expect(price.controller!.text, '18.50');
      expect(find.textContaining('تقريبي'), findsOneWidget);
      expect(find.text('أضف لمنتجاتي'), findsOneWidget);
    });

    testWidgets('an Open Food Facts name shows its source', (tester) async {
      await run(tester, ['1234567890123'], lookup: _Lookup('Nutella 400 g'));
      expect(chip('Open Food Facts'), findsOneWidget);
      expect(find.text('Nutella 400 g'), findsOneWidget);
      expect(find.text('السعر مش معروف'), findsOneWidget);
    });

    testWidgets('a web search result shows بحث أونلاين with an estimated '
        'price', (tester) async {
      await run(tester, ['1234567890123'],
          online: _Online(
              found: const ProductInfo(
                  nameAr: 'نوتيلا',
                  brand: 'Ferrero',
                  pricePiastres: 21000,
                  priceSource: 'Carrefour')));
      expect(chip('بحث أونلاين'), findsOneWidget);
      expect(find.text('نوتيلا'), findsOneWidget);
      expect(find.textContaining('Carrefour'), findsOneWidget);
      final price =
          tester.widget<TextField>(find.byKey(const Key('scan-price')));
      expect(price.controller!.text, '210');
    });

    testWidgets('an unknown code still shows its digits, and the price field '
        'is focused', (tester) async {
      await run(tester, ['1234567890123']);
      expect(chip('مش معروف'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('scan-code'))).data,
          '1234567890123');
      expect(find.text('السعر مش معروف'), findsOneWidget);
      final price =
          tester.widget<TextField>(find.byKey(const Key('scan-price')));
      expect(price.focusNode!.hasFocus, isTrue);
      expect(find.byKey(const Key('scan-name')), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('أضف لمنتجاتي needs a price first', (tester) async {
      final items = (await repo.allItems()).length;
      await run(tester, ['6223000501234']); // الدليل, no price
      await tapKey(tester, 'scan-save');
      expect(find.text('اكتب السعر'), findsOneWidget);
      expect((await repo.allItems()).length, items);
      expect(find.byKey(const Key('scan-result')), findsOneWidget);
    });

    testWidgets('أضف لمنتجاتي creates the product with its barcode and no '
        'purchase', (tester) async {
      await run(tester, ['6223000501234']);
      await tester.enterText(find.byKey(const Key('scan-price')), '32.5');
      await tapKey(tester, 'scan-save');

      final item = await repo.itemByBarcode('6223000501234');
      expect(item, isNotNull);
      expect(item!.nameAr, 'عصير جهينة مانجو');
      expect(item.categoryKey, 'Drinks');
      expect(item.defaultAmountPiastres, 3250);
      expect(repo.purchases, 0);
      expect(find.byKey(const Key('scan-result')), findsNothing);
    });

    testWidgets('an unknown product needs its name and category too, typed '
        'in the card', (tester) async {
      await run(tester, ['1234567890123']);
      await tester.enterText(find.byKey(const Key('scan-price')), '20');
      await tapKey(tester, 'scan-save');
      expect(find.text('اكتب اسم المنتج'), findsOneWidget);
      expect(find.text('اختار الفئة'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('scan-name')), 'زبادي');
      await tapKey(tester, 'scan-category-Food');
      await tapKey(tester, 'scan-save');
      final item = await repo.itemByBarcode('1234567890123');
      expect(item!.nameAr, 'زبادي');
      expect(item.categoryKey, 'Food');
      expect(item.defaultAmountPiastres, 2000);
      expect(repo.purchases, 0);
    });

    testWidgets('عدل then احفظ التعديل updates منتجاتي', (tester) async {
      final mine = await repo.createItem(
          nameAr: 'بيبسي كانز',
          categoryKey: 'Drinks',
          defaultAmountPiastres: 1500,
          barcode: '5449000000996');
      await run(tester, ['5449000000996']);
      await tapKey(tester, 'scan-edit');
      await tester.enterText(find.byKey(const Key('scan-price')), '17');
      await tapKey(tester, 'scan-save');

      final item = await repo.itemByBarcode('5449000000996');
      expect(item!.id, mine.id);
      expect(item.defaultAmountPiastres, 1700);
      expect(repo.purchases, 0);
    });

    testWidgets('سجل كمصروف needs a price, then opens review with the one '
        'line', (tester) async {
      await run(tester, ['1234567890123'], lookup: _Lookup('Nutella'));
      await tapKey(tester, 'scan-record');
      expect(find.text('اكتب السعر'), findsOneWidget);
      expect(find.byType(ReviewSheet), findsNothing);

      await tester.enterText(find.byKey(const Key('scan-price')), '210');
      await tapKey(tester, 'scan-record');
      expect(find.byType(ReviewSheet), findsOneWidget);
      final name = tester.widget<TextField>(find.byKey(const Key('line-name')));
      expect(name.controller!.text, 'Nutella');
      expect(repo.purchases, 0);
    });

    testWidgets('امسح تاني scans the next product', (tester) async {
      await run(tester, ['5449000000996', '6221007012345']);
      await tapKey(tester, 'scan-again');
      expect(scanner.calls, 2);
      expect(tester.widget<Text>(find.byKey(const Key('scan-code'))).data,
          '6221007012345');
    });

    testWidgets('إلغاء closes the card and writes nothing', (tester) async {
      final items = (await repo.allItems()).length;
      await run(tester, ['6221007012345']);
      await tapKey(tester, 'scan-cancel');
      expect(find.byKey(const Key('scan-result')), findsNothing);
      expect((await repo.allItems()).length, items);
      expect(repo.purchases, 0);
      expect(scanner.calls, 1);
    });
  });

  group('the photo of the pack', () {
    testWidgets('fills the name from the offline reading, and the photo is '
        'not kept when nothing is bought', (tester) async {
      await run(tester, ['1234567890123'], ocr: 'Zabado\nStrawberry yoghurt');
      await tapKey(tester, 'scan-photo');
      expect(photos.taken, 1);
      expect(chip('صورة المنتج'), findsOneWidget);
      final name = tester.widget<TextField>(find.byKey(const Key('scan-name')));
      expect(name.controller!.text, 'Zabado Strawberry yoghurt');

      await tapKey(tester, 'scan-cancel');
      expect(photos.deleted, ['attachments/pack.jpg']);
    });

    testWidgets('Gemini\'s reading of the photo wins when it is on',
        (tester) async {
      await run(tester, ['1234567890123'],
          ocr: 'Domty',
          online: _Online(
              fromPhoto: const ProductInfo(
                  nameAr: 'جبنة دومتي', brand: 'Domty', size: '250 جم')));
      await tapKey(tester, 'scan-photo');
      expect(chip('صورة المنتج'), findsOneWidget);
      final name = tester.widget<TextField>(find.byKey(const Key('scan-name')));
      expect(name.controller!.text, 'جبنة دومتي');
    });

    testWidgets('bought, the photo goes to review as the purchase\'s photo',
        (tester) async {
      await run(tester, ['1234567890123'], ocr: 'Zabado');
      await tapKey(tester, 'scan-photo');
      await tester.enterText(find.byKey(const Key('scan-price')), '15');
      await tapKey(tester, 'scan-record');
      expect(find.byType(ReviewSheet), findsOneWidget);
      final sheet = tester.widget<ReviewSheet>(find.byType(ReviewSheet));
      expect(sheet.request.attachments.single.path, 'attachments/pack.jpg');
      expect(photos.deleted, isEmpty);
    });
  });

  group('the network', () {
    late int built;
    NetworkGate gateAnswering(String text) => NetworkGate(repo,
        clientFactory: () {
          built++;
          return MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': text},
                      ],
                    },
                  },
                ],
              })),
              200));
        });

    setUp(() => built = 0);

    testWidgets('with the switches off nothing is sent, the photo included',
        (tester) async {
      await repo.setSetting(onlineFeaturesSettingKey, 'true');
      await repo.setSetting(OnlineFeature.gemini.settingKey, 'true');
      final gate = NetworkGate(repo,
          clientFactory: () => throw StateError('no client may be built'));
      await repo.setSetting(OnlineFeature.gemini.settingKey, 'false');
      await run(tester, ['1234567890123'],
          realOnline: true, gate: gate, ocr: 'Zabado');
      expect(chip('مش معروف'), findsOneWidget);
      await tapKey(tester, 'scan-photo');
      expect(chip('صورة المنتج'), findsOneWidget);
    });

    testWidgets('the web search is sent only once its own switch is on',
        (tester) async {
      await repo.setSetting(onlineFeaturesSettingKey, 'true');
      await repo.setSetting(OnlineFeature.gemini.settingKey, 'true');
      final gate = gateAnswering('{"nameAr": "نوتيلا", "priceEgp": 210}');
      await run(tester, ['1234567890123', '1234567890123'],
          realOnline: true, gate: gate);
      expect(built, 0);
      expect(chip('مش معروف'), findsOneWidget);
      await tapKey(tester, 'scan-cancel');

      await repo.setSetting(OnlineFeature.productWebSearch.settingKey, 'true');
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(built, 1);
      expect(chip('بحث أونلاين'), findsOneWidget);
      expect(find.text('نوتيلا'), findsOneWidget);
    });
  });
}
