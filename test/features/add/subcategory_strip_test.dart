import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/widgets/subcategory_strip.dart';

const _subcategories = [
  SubcategoryView(
      key: 'Soda', categoryKey: 'Drinks', labelAr: 'صودا', iconName: 'local_bar'),
  SubcategoryView(
      key: 'Water',
      categoryKey: 'Drinks',
      labelAr: 'مياه',
      iconName: 'water_drop'),
  SubcategoryView(
      key: 'Juice',
      categoryKey: 'Drinks',
      labelAr: 'عصير',
      iconName: 'emoji_food_beverage'),
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
          body: SubcategoryStrip(
            subcategories: _subcategories,
            selectedKey: selectedKey,
            onSelected: onSelected,
          ),
        ),
      ),
    ));
  }

  testWidgets('renders a leading الكل plus one chip per subcategory',
      (tester) async {
    await pumpStrip(tester, selectedKey: null, onSelected: (_) {});

    expect(find.text('الكل'), findsOneWidget);
    for (final s in _subcategories) {
      expect(find.text(s.labelAr), findsOneWidget);
    }
  });

  testWidgets('every chip meets the 48dp minimum tap target', (tester) async {
    await pumpStrip(tester, selectedKey: null, onSelected: (_) {});

    expect(
      tester.getSize(find.byKey(const Key('subcategory-all'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('subcategory-Soda'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('tapping a subcategory chip selects that subcategory key',
      (tester) async {
    String? selected;
    await pumpStrip(
      tester,
      selectedKey: null,
      onSelected: (key) => selected = key,
    );

    await tester.tap(find.byKey(const Key('subcategory-Soda')));
    await tester.pumpAndSettle();

    expect(selected, 'Soda');
  });

  testWidgets('tapping الكل selects null', (tester) async {
    String? selected = 'Soda';
    await pumpStrip(
      tester,
      selectedKey: 'Soda',
      onSelected: (key) => selected = key,
    );

    await tester.tap(find.byKey(const Key('subcategory-all')));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
