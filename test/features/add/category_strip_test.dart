import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/widgets/category_strip.dart';

const _categories = [
  CategoryView(key: 'Drinks', labelAr: 'مشروبات', iconName: 'local_drink'),
  CategoryView(key: 'Snacks', labelAr: 'سناكس', iconName: 'cookie'),
  CategoryView(key: 'Food', labelAr: 'أكل', iconName: 'restaurant'),
  CategoryView(
      key: 'Transport', labelAr: 'مواصلات', iconName: 'directions_bus'),
  CategoryView(key: 'Bills', labelAr: 'فواتير', iconName: 'receipt_long'),
  CategoryView(
      key: 'Personal Care', labelAr: 'عناية شخصية', iconName: 'content_cut'),
  CategoryView(key: 'Shopping', labelAr: 'تسوق', iconName: 'shopping_bag'),
  CategoryView(
      key: 'Family/Social', labelAr: 'عائلة وزيارات', iconName: 'groups'),
  CategoryView(key: 'Gifts', labelAr: 'هدايا', iconName: 'card_giftcard'),
  CategoryView(key: 'Loans', labelAr: 'سلف', iconName: 'handshake'),
];

void main() {
  Future<void> pumpStrip(
    WidgetTester tester, {
    String? selectedKey,
    required ValueChanged<String?> onSelected,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: CategoryStrip(
            categories: _categories,
            selectedKey: selectedKey,
            onSelected: onSelected,
          ),
        ),
      ),
    ));
  }

  testWidgets('renders الكل plus all ten category chips', (tester) async {
    await pumpStrip(tester, selectedKey: null, onSelected: (_) {});

    expect(find.text('الكل'), findsOneWidget);
    for (final c in _categories) {
      expect(find.text(c.labelAr), findsOneWidget);
    }
  });

  testWidgets('every chip meets the 48dp minimum tap target', (tester) async {
    await pumpStrip(tester, selectedKey: null, onSelected: (_) {});

    expect(
      tester.getSize(find.byKey(const Key('category-all'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('category-Drinks'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('chip icons stay on the 16/20/24 icon scale (spec §7.2)',
      (tester) async {
    await pumpStrip(tester, selectedKey: 'Food', onSelected: (_) {});
    final sizes = tester
        .widgetList<Icon>(find.descendant(
            of: find.byType(CategoryStrip), matching: find.byType(Icon)))
        .map((icon) => icon.size)
        .toSet();
    expect(sizes, everyElement(isIn([16.0, 20.0, 24.0])));
  });

  testWidgets('tapping a category chip selects that category key',
      (tester) async {
    String? selected;
    await pumpStrip(
      tester,
      selectedKey: null,
      onSelected: (key) => selected = key,
    );

    await tester.tap(find.text('مشروبات'));
    await tester.pumpAndSettle();

    expect(selected, 'Drinks');
  });

  testWidgets('tapping الكل selects null', (tester) async {
    String? selected = 'Drinks';
    await pumpStrip(
      tester,
      selectedKey: 'Drinks',
      onSelected: (key) => selected = key,
    );

    await tester.tap(find.text('الكل'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
