import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/widgets/new_item_dialog.dart';

const _categories = [
  CategoryView(key: 'Drinks', labelAr: 'مشروبات', iconName: 'local_drink'),
  CategoryView(key: 'Food', labelAr: 'أكل', iconName: 'restaurant'),
];

/// Pumps a screen with a single button that opens the dialog when tapped,
/// storing the pending result Future in [resultBox] so the test can await
/// it after driving the dialog's fields.
Future<void> _pumpAndOpen(
  WidgetTester tester,
  List<Future<NewItemDraft?>?> resultBox, {
  String initialCategoryKey = 'Drinks',
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              resultBox[0] = showNewItemDialog(
                context: context,
                categories: _categories,
                initialCategoryKey: initialCategoryKey,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('save is disabled until a name and a valid amount are entered',
      (tester) async {
    final resultBox = <Future<NewItemDraft?>?>[null];
    await _pumpAndOpen(tester, resultBox);

    final save = find.byKey(const Key('new-item-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('new-item-name')), 'شاي');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('new-item-amount')), '15');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets(
      'saving returns the name, amount in piastres and pre-filled category',
      (tester) async {
    final resultBox = <Future<NewItemDraft?>?>[null];
    await _pumpAndOpen(tester, resultBox, initialCategoryKey: 'Drinks');

    await tester.enterText(find.byKey(const Key('new-item-name')), 'شاي');
    await tester.enterText(find.byKey(const Key('new-item-amount')), '15');
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-item-save')));
    await tester.pumpAndSettle();

    final captured = await resultBox[0]!;
    expect(captured, isNotNull);
    expect(captured!.nameAr, 'شاي');
    expect(captured.categoryKey, 'Drinks');
    expect(captured.amountPiastres, 1500);
  });

  testWidgets('cancel closes the dialog and returns null', (tester) async {
    final resultBox = <Future<NewItemDraft?>?>[null];
    await _pumpAndOpen(tester, resultBox);

    await tester.tap(find.byKey(const Key('new-item-cancel')));
    await tester.pumpAndSettle();

    expect(await resultBox[0]!, isNull);
  });

  testWidgets(
      'showEditItemDialog pre-fills the existing item\'s name, category and '
      'price, and saving returns the edited values', (tester) async {
    const item = QuickPickItem(
      id: 'i1',
      nameAr: 'شويبس',
      categoryKey: 'Drinks',
      defaultAmountPiastres: 4000,
    );
    Future<NewItemDraft?>? result;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                result = showEditItemDialog(
                  context: context,
                  categories: _categories,
                  item: item,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Pre-filled with the item's current values, not blank fields. A
    // TextField's entered value isn't a `Text` widget, so this reads the
    // controller through the field itself rather than via `find.text`.
    final nameField =
        tester.widget<TextField>(find.byKey(const Key('new-item-name')));
    final amountField =
        tester.widget<TextField>(find.byKey(const Key('new-item-amount')));
    expect(nameField.controller!.text, 'شويبس');
    expect(amountField.controller!.text, '40');
    expect(find.text('تعديل العنصر'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('new-item-name')), 'شويبس جديد');
    await tester.enterText(find.byKey(const Key('new-item-amount')), '45');
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-item-save')));
    await tester.pumpAndSettle();

    final captured = await result!;
    expect(captured, isNotNull);
    expect(captured!.nameAr, 'شويبس جديد');
    expect(captured.categoryKey, 'Drinks');
    expect(captured.amountPiastres, 4500);
  });
}
