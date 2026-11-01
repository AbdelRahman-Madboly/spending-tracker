import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';

/// A product sold loose by a unit (milk by the litre at the market): a tap
/// on it asks how much was bought and at what price per unit, instead of
/// putting a price straight into the keypad.
void main() {
  late FixtureSpendingRepository repo;
  DraftEntry? captured;

  setUp(() {
    repo = FixtureSpendingRepository();
    captured = null;
  });

  Future<QuickPickItem> cowMilk() => repo.createItem(
        nameAr: 'لبن بقري سايب',
        categoryKey: 'Drinks',
        subcategoryKey: 'Milk',
        defaultAmountPiastres: 2500,
        unit: 'liter',
        defaultQuantityMilli: 2000,
      );

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: repo,
            onSubmit: (d) => captured = d,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder tile(String name) =>
      find.descendant(of: find.byType(GridView), matching: find.text(name));

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  String totalText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('unit-total'))).data!;

  testWidgets('the tile shows the price per litre', (tester) async {
    await cowMilk();
    await pump(tester);
    expect(
      find.descendant(
          of: find.byType(GridView), matching: find.text('25 ج.م / لتر')),
      findsOneWidget,
    );
  });

  testWidgets('a tap opens the quantity step on the usual 2 litres at 25, '
      'and saving records 2 × 25 = 50', (tester) async {
    final milk = await cowMilk();
    await pump(tester);
    await tester.tap(tile('لبن بقري سايب'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-step')), findsOneWidget);
    expect(fieldText(tester, 'unit-quantity'), '2');
    expect(fieldText(tester, 'unit-price'), '25');
    expect(find.text('سعر اللتر'), findsOneWidget);
    expect(totalText(tester), '50 ج.م');

    await tapKey(tester, 'unit-save');
    expect(captured, isNotNull);
    expect(captured!.itemId, milk.id);
    expect(captured!.amountPiastres, 5000);
    expect(captured!.quantityMilli, 2000);
    expect(captured!.unit, 'liter');
    expect(captured!.unitPricePiastres, 2500);
    expect(captured!.categoryKey, 'Drinks');
    expect(captured!.subcategoryKey, 'Milk');
    expect(captured!.description, 'لبن بقري سايب');
  });

  testWidgets('the litre chips are نص، 1، 1.5، 2، 3 and نص is half a litre',
      (tester) async {
    await cowMilk();
    await pump(tester);
    await tester.tap(tile('لبن بقري سايب'));
    await tester.pumpAndSettle();

    for (final (milli, label) in [
      (500, 'نص'),
      (1000, '1'),
      (1500, '1.5'),
      (2000, '2'),
      (3000, '3'),
    ]) {
      expect(
        find.descendant(
            of: find.byKey(Key('unit-quick-$milli')),
            matching: find.text(label)),
        findsOneWidget,
      );
    }
    // A litre product is never asked about kilos.
    expect(
      find.descendant(
          of: find.byKey(const Key('unit-step')), matching: find.text('كيلو')),
      findsNothing,
    );

    await tapKey(tester, 'unit-quick-500');
    expect(fieldText(tester, 'unit-quantity'), '0.5');
    expect(totalText(tester), '12.50 ج.م');
    await tapKey(tester, 'unit-save');
    expect(captured!.quantityMilli, 500);
    expect(captured!.amountPiastres, 1250);
  });

  testWidgets('any amount can be typed: 0.75 of a litre at 25 is 18.75',
      (tester) async {
    await cowMilk();
    await pump(tester);
    await tester.tap(tile('لبن بقري سايب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-quantity')), '0.75');
    await tester.pumpAndSettle();
    expect(totalText(tester), '18.75 ج.م');
    await tester.enterText(find.byKey(const Key('unit-quantity')), '2.5');
    await tester.enterText(find.byKey(const Key('unit-price')), '27');
    await tester.pumpAndSettle();
    expect(totalText(tester), '67.50 ج.م');
    await tapKey(tester, 'unit-save');
    expect(captured!.quantityMilli, 2500);
    expect(captured!.unitPricePiastres, 2700);
    expect(captured!.amountPiastres, 6750);
  });

  testWidgets('a product with no price yet needs the price per litre before '
      'it can be saved', (tester) async {
    await repo.createItem(
      nameAr: 'لبن جاموسي سايب',
      categoryKey: 'Drinks',
      unit: 'liter',
    );
    await pump(tester);
    await tester.tap(tile('لبن جاموسي سايب'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'unit-price'), '');
    expect(fieldText(tester, 'unit-quantity'), '1');

    await tapKey(tester, 'unit-save');
    expect(captured, isNull);
    expect(find.text('اكتب سعر اللتر'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('unit-price')), '30');
    await tapKey(tester, 'unit-quick-2000');
    await tapKey(tester, 'unit-save');
    expect(captured!.amountPiastres, 6000);
    expect(captured!.unitPricePiastres, 3000);
  });

  testWidgets('a quantity that is not a number is refused', (tester) async {
    await cowMilk();
    await pump(tester);
    await tester.tap(tile('لبن بقري سايب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-quantity')), '');
    await tester.pumpAndSettle();
    expect(totalText(tester), '—');
    await tapKey(tester, 'unit-save');
    expect(captured, isNull);
    expect(find.text('اكتب الكمية'), findsOneWidget);
  });

  testWidgets('a product sold by the gram offers 250, 500 and 1000 grams',
      (tester) async {
    await repo.createItem(
      nameAr: 'جبنة رومي',
      categoryKey: 'Food',
      defaultAmountPiastres: 40,
      unit: 'g',
    );
    await pump(tester);
    await tester.tap(tile('جبنة رومي'));
    await tester.pumpAndSettle();
    for (final grams in [250, 500, 1000]) {
      expect(
        find.descendant(
            of: find.byKey(Key('unit-quick-${grams * 1000}')),
            matching: find.text('$grams')),
        findsOneWidget,
      );
    }
    await tapKey(tester, 'unit-quick-250000');
    await tapKey(tester, 'unit-save');
    expect(captured!.quantityMilli, 250000);
    expect(captured!.unit, 'g');
    expect(captured!.amountPiastres, 10000);
  });

  testWidgets('closing the step records nothing and keeps the sheet',
      (tester) async {
    await cowMilk();
    await pump(tester);
    await tester.tap(tile('لبن بقري سايب'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-step')), findsNothing);
    expect(captured, isNull);
    expect(find.byKey(const Key('save-button')), findsOneWidget);
  });

  testWidgets('a piece product still fills the keypad in one tap',
      (tester) async {
    await pump(tester);
    await tester.tap(tile('شويبس'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-step')), findsNothing);
    await tapKey(tester, 'save-button');
    expect(captured!.amountPiastres, 4000);
    expect(captured!.quantityMilli, isNull);
    expect(captured!.unit, isNull);
  });

  testWidgets('the step lays out in the dark theme with 48dp targets',
      (tester) async {
    await cowMilk();
    await pump(tester, dark: true);
    await tester.tap(tile('لبن بقري سايب'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final key in ['unit-quick-500', 'unit-save']) {
      expect(tester.getSize(find.byKey(Key(key))).height,
          greaterThanOrEqualTo(48));
    }
  });
}
