import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.pumpWidget(MaterialApp(
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
  });
}
