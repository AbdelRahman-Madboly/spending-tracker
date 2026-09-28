import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';

/// Test double for [BarcodeScanService] — mobile_scanner talks to the
/// platform camera through platform channels that don't run under
/// `flutter test`, so `AddSheet` is exercised through this fake instead.
/// Mirrors the fake used for [PhotoCaptureService] in
/// add_sheet_photo_test.dart.
class FakeBarcodeScanService implements BarcodeScanService {
  FakeBarcodeScanService([this.result]);

  /// The value returned by the next [scan] call — null means "user backed
  /// out without scanning anything".
  String? result;
  int calls = 0;

  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    return result;
  }
}

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required FixtureSpendingRepository repository,
    required FakeBarcodeScanService scanService,
    ValueChanged<DraftEntry>? onSubmit,
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: repository,
            onSubmit: onSubmit ?? (_) {},
            barcodeScanService: scanService,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'a known barcode selects the matching item as the draft instantly, '
      'with the amount pre-filled', (tester) async {
    final repository = FixtureSpendingRepository();
    final learned = await repository.createItem(
      nameAr: 'مياه معدنية',
      categoryKey: 'Drinks',
      defaultAmountPiastres: 1000,
      barcode: '6224000123456',
    );
    final scanService = FakeBarcodeScanService('6224000123456');
    DraftEntry? captured;
    await pumpSheet(
      tester,
      repository: repository,
      scanService: scanService,
      onSubmit: (d) => captured = d,
    );

    await tester.tap(find.byKey(const Key('barcode-button')));
    await tester.pumpAndSettle();

    expect(scanService.calls, 1);
    // No creation dialog — the known code resolves straight to a draft.
    expect(find.byKey(const Key('new-item-name')), findsNothing);
    expect(find.textContaining('مياه معدنية'), findsWidgets);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.itemId, learned.id);
    expect(captured!.amountPiastres, 1000);
    expect(captured!.categoryKey, 'Drinks');
    expect(captured!.source, EntrySource.barcode);
  });

  testWidgets(
      'an unrecognised barcode opens the new-item dialog with the barcode '
      'attached, and saving teaches the app so the next scan of the same '
      'code resolves instantly', (tester) async {
    const code = '9999999999999';
    final repository = FixtureSpendingRepository();
    final scanService = FakeBarcodeScanService(code);
    final captures = <DraftEntry>[];
    await pumpSheet(
      tester,
      repository: repository,
      scanService: scanService,
      onSubmit: captures.add,
    );

    // First scan: unrecognised, so the creation dialog opens with the
    // barcode visibly attached.
    await tester.tap(find.byKey(const Key('barcode-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new-item-name')), findsOneWidget);
    expect(find.byKey(const Key('new-item-barcode')), findsOneWidget);
    expect(find.textContaining(code), findsOneWidget);

    await tester.enterText(find.byKey(const Key('new-item-name')), 'مياه صغيرة');
    await tester.enterText(find.byKey(const Key('new-item-amount')), '7.5');
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-item-save')));
    await tester.pumpAndSettle();

    // The freshly-created item is selected as the draft immediately.
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captures, hasLength(1));
    expect(captures[0].description, 'مياه صغيرة');
    expect(captures[0].amountPiastres, 750);
    expect(captures[0].source, EntrySource.barcode);
    final firstItemId = captures[0].itemId;
    expect(firstItemId, isNotNull);

    // The barcode is now attached to that item in the catalogue.
    final learned = await repository.itemByBarcode(code);
    expect(learned, isNotNull);
    expect(learned!.id, firstItemId);
    expect(learned.nameAr, 'مياه صغيرة');

    // Second scan of the exact same code: resolves straight to the draft,
    // no dialog this time.
    await tester.tap(find.byKey(const Key('barcode-button')));
    await tester.pumpAndSettle();

    expect(scanService.calls, 2);
    expect(find.byKey(const Key('new-item-name')), findsNothing);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captures, hasLength(2));
    expect(captures[1].itemId, firstItemId);
    expect(captures[1].source, EntrySource.barcode);
  });

  testWidgets('backing out of the scanner without a result does nothing',
      (tester) async {
    final repository = FixtureSpendingRepository();
    final scanService = FakeBarcodeScanService(null);
    await pumpSheet(
      tester,
      repository: repository,
      scanService: scanService,
    );

    await tester.tap(find.byKey(const Key('barcode-button')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('new-item-name')), findsNothing);
    final saveButton =
        tester.widget<FilledButton>(find.byKey(const Key('save-button')));
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('barcode button has at least a 48dp tap target', (tester) async {
    final repository = FixtureSpendingRepository();
    final scanService = FakeBarcodeScanService(null);
    await pumpSheet(tester, repository: repository, scanService: scanService);

    final size = tester.getSize(find.byKey(const Key('barcode-button')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
