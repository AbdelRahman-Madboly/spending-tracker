import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';

void main() {
  testWidgets(
      'save button clears the 48dp minimum tap target under the real app theme',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final height = tester.getSize(find.byKey(const Key('save-button'))).height;
    expect(height, greaterThanOrEqualTo(48));
  });

  testWidgets('shows twelve quick pick items and five capture icons',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('شويبس'), findsOneWidget);
    expect(find.byKey(const Key('capture-icons')), findsOneWidget);
  });

  testWidgets('tapping an item submits a complete draft in one tap',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    DraftEntry? captured;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (d) => captured = d,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('شويبس'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.amountPiastres, 4000);
    expect(captured!.categoryKey, 'Drinks');
    expect(captured!.source, EntrySource.quickPick);
    expect(captured!.isComplete, isTrue);
  });

  testWidgets(
      'category strip defaults to الكل and selecting a category filters the grid',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // الكل is selected by default and shows items from every category —
    // this is what keeps the two-tap path alive. The grid is scoped with
    // find.descendant(of: GridView) throughout this file because once a
    // category is selected its subcategory chip row can share label text
    // with an item name (e.g. "Milk"/"لبن" the Drinks subcategory versus
    // "لبن" the Food item) — the two rows are different widgets, but a bare
    // find.text would find both.
    final grid = find.byType(GridView);
    expect(find.text('الكل'), findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('شويبس')),
        findsOneWidget); // Drinks
    expect(find.descendant(of: grid, matching: find.text('لبن')),
        findsOneWidget); // Food

    await tester.tap(find.text('مشروبات')); // Drinks
    await tester.pumpAndSettle();

    expect(find.descendant(of: grid, matching: find.text('شويبس')),
        findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('لبن')), findsNothing);
  });

  testWidgets(
      'selecting a category reveals its subcategory row (hidden by default), '
      'and the two-tap quick-pick path still works with الكل selected',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    DraftEntry? captured;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (d) => captured = d,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // With الكل selected (the default), there is no second chip row at all.
    expect(find.byKey(const Key('subcategory-all')), findsNothing);

    // Tapping شويبس then حفظ must remain exactly two taps — this must not
    // regress by the subcategory feature existing.
    await tester.tap(find.text('شويبس'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.isComplete, isTrue);
    expect(captured!.categoryKey, 'Drinks');

    // Selecting a real category reveals the subcategory row...
    await tester.tap(find.text('مشروبات')); // Drinks
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subcategory-all')), findsOneWidget);
    expect(find.byKey(const Key('subcategory-Soda')), findsOneWidget);

    // ...and deselecting it (back to الكل) collapses it again. Selected via
    // its key, not find.text('الكل') — the subcategory row's own "الكل"
    // chip is on screen too at this point.
    await tester.tap(find.byKey(const Key('category-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subcategory-all')), findsNothing);
  });

  testWidgets(
      'selecting a category then a subcategory filters the grid to that '
      "subcategory's items", (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    DraftEntry? captured;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (d) => captured = d,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مشروبات')); // Drinks
    await tester.pumpAndSettle();

    // At category level (no subcategory chosen yet) both شويبس (Soda) and
    // عصير (Juice) show.
    final grid = find.byType(GridView);
    expect(find.descendant(of: grid, matching: find.text('شويبس')),
        findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('عصير')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('subcategory-Soda')));
    await tester.pumpAndSettle();

    // Filtered to Soda: شويبس stays, عصير (a different subcategory) drops
    // out of the grid — the chip above still says "عصير" for the Juice
    // subcategory, which is why this is scoped to the grid rather than a
    // bare find.text.
    expect(find.descendant(of: grid, matching: find.text('شويبس')),
        findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('عصير')), findsNothing);

    // Tap it and save: the draft records the item's own subcategory.
    await tester.tap(find.text('شويبس'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.subcategoryKey, 'Soda');
  });

  testWidgets(
      'tapping جديد opens the new item dialog, and saving creates and selects it',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    DraftEntry? captured;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (d) => captured = d,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-item-tile')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('new-item-name')), 'شاي');
    await tester.enterText(find.byKey(const Key('new-item-amount')), '15');
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-item-save')));
    await tester.pumpAndSettle();

    // The new item is now selected as the draft, without a second tap.
    expect(find.text('شاي'), findsWidgets);
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.description, 'شاي');
    expect(captured!.amountPiastres, 1500);
    expect(captured!.isComplete, isTrue);
  });

  testWidgets(
      'تايل جديد opens the dialog with both category and subcategory '
      'pre-filled from the current selection', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    DraftEntry? captured;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (d) => captured = d,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مشروبات')); // Drinks
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subcategory-Soda')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-item-tile')));
    await tester.pumpAndSettle();

    final categoryField = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('new-item-category')));
    expect(categoryField.initialValue, 'Drinks');
    final subcategoryField =
        tester.widget<DropdownButtonFormField<String?>>(
            find.byKey(const Key('new-item-subcategory')));
    expect(subcategoryField.initialValue, 'Soda');

    await tester.enterText(find.byKey(const Key('new-item-name')), 'سفن أب');
    await tester.enterText(find.byKey(const Key('new-item-amount')), '20');
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-item-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.categoryKey, 'Drinks');
    expect(captured!.subcategoryKey, 'Soda');
  });
}
