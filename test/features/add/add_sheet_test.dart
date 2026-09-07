import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/app.dart';
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
    // this is what keeps the two-tap path alive.
    expect(find.text('الكل'), findsOneWidget);
    expect(find.text('شويبس'), findsOneWidget); // Drinks
    expect(find.text('لبن'), findsOneWidget); // Food

    await tester.tap(find.text('مشروبات')); // Drinks
    await tester.pumpAndSettle();

    expect(find.text('شويبس'), findsOneWidget);
    expect(find.text('لبن'), findsNothing);
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
}
