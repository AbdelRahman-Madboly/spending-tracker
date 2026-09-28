import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/app.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/settings/settings_screen.dart';

void main() {
  Future<void> pumpSettings(
      WidgetTester tester, FixtureSpendingRepository repository) async {
    // Tall enough that the whole settings list (salary, ten categories,
    // twelve items and the about block) is mounted without scrolling — a
    // ListView only mounts children within the viewport, and this suite
    // needs to find items at every position in the list.
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Pumped under the real app theme (as add_sheet_test.dart already
    // does) rather than a bare MaterialApp — otherwise the 48dp tap-target
    // assertion below passes under Flutter's stock M3 theme rather than
    // what actually ships.
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SettingsScreen(repository: repository),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the current salary, editable, and saving records a new '
      'salary period rather than mutating it', (tester) async {
    final repository = FixtureSpendingRepository();
    await pumpSettings(tester, repository);

    expect(find.text('9,000'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('settings-salary-field')), '7500');
    await tester.tap(find.byKey(const Key('settings-salary-save')));
    await tester.pumpAndSettle();

    final summary = await repository.watchCurrentPeriod().first;
    expect(summary.salaryPiastres, 750000);
  });

  testWidgets('lists all ten categories with their Arabic labels and icons',
      (tester) async {
    final repository = FixtureSpendingRepository();
    await pumpSettings(tester, repository);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-category-Drinks')),
        matching: find.text('مشروبات'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-category-Family/Social')),
        matching: find.text('عائلة وزيارات'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.local_drink), findsOneWidget);
    expect(find.byIcon(Icons.groups), findsOneWidget);

    final categoryTiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          (w.key! as ValueKey).value.toString().startsWith('settings-category-'),
    );
    expect(categoryTiles, findsNWidgets(10));
  });

  testWidgets(
      'lists the item catalogue with name, category and price, and '
      'archiving one removes it from the list', (tester) async {
    final repository = FixtureSpendingRepository();
    await pumpSettings(tester, repository);

    expect(find.text('شويبس'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);

    await tester.tap(find.byKey(const Key('archive-item-i1')));
    await tester.pumpAndSettle();

    expect(find.text('شويبس'), findsNothing);

    // Archiving is a soft delete, not a deletion: the quick-pick grid must
    // no longer offer it, without touching entries that already reference
    // it.
    final topItems = await repository.topItems(20);
    expect(topItems.map((i) => i.id), isNot(contains('i1')));
  });

  testWidgets(
      'tapping an item opens an edit dialog pre-filled with its current '
      'values, and saving updates its name, category and price in the list',
      (tester) async {
    final repository = FixtureSpendingRepository();
    await pumpSettings(tester, repository);

    await tester.tap(find.text('شويبس'));
    await tester.pumpAndSettle();

    expect(find.text('تعديل العنصر'), findsOneWidget);
    // A TextField's entered value isn't a `Text` widget, so the pre-fill is
    // checked through the field's controller rather than `find.text`.
    final nameField =
        tester.widget<TextField>(find.byKey(const Key('new-item-name')));
    final amountField =
        tester.widget<TextField>(find.byKey(const Key('new-item-amount')));
    expect(nameField.controller!.text, 'شويبس');
    expect(amountField.controller!.text, '40');

    await tester.enterText(
        find.byKey(const Key('new-item-name')), 'شويبس مانجا');
    await tester.enterText(find.byKey(const Key('new-item-amount')), '45');
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-item-save')));
    await tester.pumpAndSettle();

    expect(find.text('شويبس مانجا'), findsOneWidget);
    expect(find.text('شويبس'), findsNothing);

    final updated =
        (await repository.allItems()).firstWhere((i) => i.id == 'i1');
    expect(updated.categoryKey, 'Drinks');
    expect(updated.defaultAmountPiastres, 4500);
  });

  testWidgets('shows the app name and version in the about section',
      (tester) async {
    final repository = FixtureSpendingRepository();
    await pumpSettings(tester, repository);

    expect(find.text('مصاريفي'), findsOneWidget);
    expect(find.textContaining('1.0.0'), findsOneWidget);
  });

  testWidgets('every tappable control clears the 48dp minimum tap target',
      (tester) async {
    final repository = FixtureSpendingRepository();
    await pumpSettings(tester, repository);

    final saveHeight =
        tester.getSize(find.byKey(const Key('settings-salary-save'))).height;
    expect(saveHeight, greaterThanOrEqualTo(48));

    final archiveHeight =
        tester.getSize(find.byKey(const Key('archive-item-i1'))).height;
    expect(archiveHeight, greaterThanOrEqualTo(48));

    final addCategorySize =
        tester.getSize(find.byKey(const Key('add-category')));
    expect(addCategorySize.height, greaterThanOrEqualTo(48));
    expect(addCategorySize.width, greaterThanOrEqualTo(48));

    final expandSize =
        tester.getSize(find.byKey(const Key('expand-category-Drinks')));
    expect(expandSize.height, greaterThanOrEqualTo(48));
    expect(expandSize.width, greaterThanOrEqualTo(48));

    final addItemSize = tester.getSize(find.byKey(const Key('add-item')));
    expect(addItemSize.height, greaterThanOrEqualTo(48));
    expect(addItemSize.width, greaterThanOrEqualTo(48));
  });

  group('category management', () {
    testWidgets(
        'tapping a category opens an edit dialog pre-filled with its label, '
        'and saving renames it without changing its key', (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('settings-category-Drinks')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category-dialog-name')), findsOneWidget);
      final nameField = tester
          .widget<TextField>(find.byKey(const Key('category-dialog-name')));
      expect(nameField.controller!.text, 'مشروبات');

      await tester.enterText(
          find.byKey(const Key('category-dialog-name')), 'مشروبات وعصائر');
      await tester.tap(find.byKey(const Key('category-dialog-save')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-category-Drinks')),
          matching: find.text('مشروبات وعصائر'),
        ),
        findsOneWidget,
      );
      final renamed = (await repository.categories())
          .firstWhere((c) => c.key == 'Drinks');
      expect(renamed.labelAr, 'مشروبات وعصائر');
    });

    testWidgets(
        'the icon picker lets you change a category\'s icon, and saving '
        'persists the new icon', (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('settings-category-Drinks')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category-dialog-icon-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('icon-option-pets')), findsOneWidget);
      await tester.tap(find.byKey(const Key('icon-option-pets')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category-dialog-save')));
      await tester.pumpAndSettle();

      final updated = (await repository.categories())
          .firstWhere((c) => c.key == 'Drinks');
      expect(updated.iconName, 'pets');
    });

    testWidgets(
        'the add-category button creates a new category shown in the list',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('add-category')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('category-dialog-name')), 'رياضة');
      await tester.pump();
      await tester.tap(find.byKey(const Key('category-dialog-save')));
      await tester.pumpAndSettle();

      expect(find.text('رياضة'), findsOneWidget);
      expect(await (repository.categories()).then((c) => c.length), 11);
    });

    testWidgets(
        'archiving a category with children asks for confirmation with the '
        'real subcategory/item counts, and confirming removes it from the '
        'list', (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('archive-category-Drinks')));
      await tester.pumpAndSettle();

      // Drinks has 5 subcategories (Soda, Water, Milk, Juice, HotDrinks)
      // and 2 items (شويبس, عصير) in the fixture catalogue.
      final confirmMessage = tester
          .widget<Text>(find.byKey(const Key('archive-confirm-message')))
          .data!;
      expect(confirmMessage, contains('5 فئة فرعية'));
      expect(confirmMessage, contains('2 منتج'));

      await tester.tap(find.byKey(const Key('archive-confirm-confirm')));
      await tester.pumpAndSettle();

      // Gone from the active list...
      expect(find.byKey(const ValueKey('settings-category-Drinks')),
          findsNothing);
      expect((await repository.categories()).map((c) => c.key),
          isNot(contains('Drinks')));
      // ...but not deleted: it now shows up in the archived section.
      expect(find.byKey(const Key('settings-archived-category-Drinks')),
          findsOneWidget);
    });

    testWidgets(
        'cancelling the archive confirmation leaves the category untouched',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('archive-category-Drinks')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('archive-confirm-cancel')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-category-Drinks')),
          matching: find.text('مشروبات'),
        ),
        findsOneWidget,
      );
      expect((await repository.categories()).map((c) => c.key),
          contains('Drinks'));
    });

    testWidgets(
        'an archived category appears in the archived section, and '
        'unarchiving it restores it plus its subcategories and items',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await repository.archiveCategory('Drinks');
      await pumpSettings(tester, repository);

      expect(find.byKey(const Key('settings-archived-category-Drinks')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('unarchive-category-Drinks')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-category-Drinks')),
          matching: find.text('مشروبات'),
        ),
        findsOneWidget,
      );
      expect((await repository.categories()).map((c) => c.key),
          contains('Drinks'));
      expect(await repository.subcategories('Drinks'), isNotEmpty);
      expect((await repository.allItems()).map((i) => i.id), contains('i1'));
    });
  });

  group('subcategory management', () {
    testWidgets(
        'expanding a category shows its subcategories nested underneath',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      expect(find.text('صودا'), findsNothing);

      await tester.tap(find.byKey(const Key('expand-category-Drinks')));
      await tester.pumpAndSettle();

      expect(find.text('صودا'), findsOneWidget);
      expect(find.text('مياه'), findsOneWidget);
    });

    testWidgets(
        'tapping a subcategory opens an edit dialog, and saving renames it '
        'without changing its key', (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('expand-category-Drinks')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('صودا'));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('subcategory-dialog-name')), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('subcategory-dialog-name')), 'مشروبات غازية');
      await tester.tap(find.byKey(const Key('subcategory-dialog-save')));
      await tester.pumpAndSettle();

      expect(find.text('مشروبات غازية'), findsOneWidget);
      final renamed = (await repository.subcategories('Drinks'))
          .firstWhere((s) => s.key == 'Soda');
      expect(renamed.labelAr, 'مشروبات غازية');
    });

    testWidgets(
        'moving a subcategory to another category via the edit dialog '
        'relocates it there', (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('expand-category-Drinks')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('صودا'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('subcategory-dialog-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('سناكس').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('subcategory-dialog-save')));
      await tester.pumpAndSettle();

      final moved = (await repository.subcategories('Snacks'))
          .map((s) => s.key);
      expect(moved, contains('Soda'));
      final stillUnderDrinks = (await repository.subcategories('Drinks'))
          .map((s) => s.key);
      expect(stillUnderDrinks, isNot(contains('Soda')));
    });

    testWidgets('the add-subcategory button adds a new subcategory nested '
        'under its category', (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('expand-category-Drinks')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-subcategory-Drinks')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('subcategory-dialog-name')), 'مياه غازية');
      await tester.pump();
      await tester.tap(find.byKey(const Key('subcategory-dialog-save')));
      await tester.pumpAndSettle();

      expect(find.text('مياه غازية'), findsOneWidget);
      expect((await repository.subcategories('Drinks')).map((s) => s.labelAr),
          contains('مياه غازية'));
    });

    testWidgets(
        'archiving a subcategory with items asks for confirmation with the '
        'real item count, and confirming removes it from the nested list',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('expand-category-Drinks')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('archive-subcategory-Soda')));
      await tester.pumpAndSettle();

      // Soda has exactly one item (شويبس) in the fixture catalogue.
      final confirmMessage = tester
          .widget<Text>(find.byKey(const Key('archive-confirm-message')))
          .data!;
      expect(confirmMessage, contains('1 منتج'));

      await tester.tap(find.byKey(const Key('archive-confirm-confirm')));
      await tester.pumpAndSettle();

      // Gone from the active nested list under Drinks...
      expect(find.byKey(const Key('settings-subcategory-Soda')), findsNothing);
      expect((await repository.subcategories('Drinks')).map((s) => s.key),
          isNot(contains('Soda')));
      // ...but not deleted: it now shows up in the archived section.
      expect(find.byKey(const Key('settings-archived-subcategory-Soda')),
          findsOneWidget);
    });

    testWidgets(
        'archiving a subcategory with no items needs no confirmation',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('expand-category-Drinks')));
      await tester.pumpAndSettle();

      // HotDrinks has no items in the fixture catalogue.
      await tester.tap(find.byKey(const Key('archive-subcategory-HotDrinks')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('archive-confirm-message')), findsNothing);
      expect(find.byKey(const Key('settings-subcategory-HotDrinks')),
          findsNothing);
      expect((await repository.subcategories('Drinks')).map((s) => s.key),
          isNot(contains('HotDrinks')));
    });

    testWidgets(
        'an archived subcategory appears in the archived section, and '
        'unarchiving it restores its items but not its parent category',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await repository.archiveCategory('Drinks');
      await pumpSettings(tester, repository);

      expect(find.byKey(const Key('settings-archived-subcategory-Soda')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('unarchive-subcategory-Soda')));
      await tester.pumpAndSettle();

      expect((await repository.allItems()).map((i) => i.id), contains('i1'));
      expect((await repository.categories()).map((c) => c.key),
          isNot(contains('Drinks')));
    });
  });

  group('item management', () {
    testWidgets('the add-item button creates a new item shown in the list',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('add-item')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('new-item-name')), 'سجائر');
      await tester.enterText(
          find.byKey(const Key('new-item-amount')), '80');
      await tester.pump();
      await tester.tap(find.byKey(const Key('new-item-save')));
      await tester.pumpAndSettle();

      expect(find.text('سجائر'), findsOneWidget);
      final items = await repository.allItems();
      expect(items.map((i) => i.nameAr), contains('سجائر'));
    });

    testWidgets(
        'archiving an item and switching to the archived view shows it '
        'there with an unarchive control that restores it', (tester) async {
      final repository = FixtureSpendingRepository();
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('archive-item-i1')));
      await tester.pumpAndSettle();
      expect(find.text('شويبس'), findsNothing);

      await tester.tap(find.byKey(const Key('items-view-archived')));
      await tester.pumpAndSettle();

      expect(find.text('شويبس'), findsOneWidget);
      expect(find.byKey(const Key('unarchive-item-i1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('unarchive-item-i1')));
      await tester.pumpAndSettle();

      expect(find.text('شويبس'), findsNothing);

      await tester.tap(find.byKey(const Key('items-view-active')));
      await tester.pumpAndSettle();

      expect(find.text('شويبس'), findsOneWidget);
      final items = await repository.allItems();
      expect(items.map((i) => i.id), contains('i1'));
    });

    testWidgets(
        'unarchiving an item whose barcode another item now holds keeps it '
        'archived and says why', (tester) async {
      final repository = FixtureSpendingRepository();
      final old = await repository.createItem(
          nameAr: 'بيبسي كانز', categoryKey: 'Drinks', barcode: '6221');
      await repository.archiveItem(old.id);
      await repository.createItem(
          nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6221');
      await pumpSettings(tester, repository);

      await tester.tap(find.byKey(const Key('items-view-archived')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('unarchive-item-${old.id}')));
      await tester.pumpAndSettle();

      expect(find.text('الباركود مسجل لصنف آخر، فلا يمكن استرجاع هذا الصنف'),
          findsOneWidget);
      expect(find.text('بيبسي كانز'), findsOneWidget);
      expect((await repository.archivedItems()).map((i) => i.id),
          contains(old.id));
    });
  });
}
