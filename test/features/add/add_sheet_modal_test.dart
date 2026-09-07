import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';

/// The sheet is opened in production through `showModalBottomSheet`, which
/// constrains its height. Hosting `AddSheet` directly in a `Scaffold` body — as
/// the other add-sheet tests do — hands it the whole screen, so those tests
/// cannot catch content being clipped by the sheet itself.
///
/// These tests close that gap at a real phone geometry (384x832dp). A device
/// screenshot once appeared to show the save button missing; checking the same
/// geometry on an emulator showed the sheet rendering in full, so that reading
/// was mistaken. The coverage is kept because the constraint is real even
/// though the defect was not.
void main() {
  Future<void> openSheet(WidgetTester tester) async {
    // A Samsung A54: 1080x2340 at density 450, i.e. 384x832 logical pixels.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1080 / 384;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AddSheet(
                    repository: FixtureSpendingRepository(),
                    onSubmit: (_) {},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('save button is on screen and tappable inside a real modal sheet',
      (tester) async {
    await openSheet(tester);

    final save = find.byKey(const Key('save-button'));
    expect(save, findsOneWidget);

    // findsOneWidget only proves the widget exists in the tree; it can exist
    // while laid out past the bottom of the sheet. Assert it is actually within
    // the visible screen.
    final rect = tester.getRect(save);
    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(rect.bottom, lessThanOrEqualTo(screenHeight),
        reason: 'save button bottom ${rect.bottom} is below the screen '
            '($screenHeight) — the user cannot reach it');

    // And prove it can actually be driven, not merely that it is on screen.
    await tester.tap(find.text('شويبس'));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
  });

  testWidgets('capture icons are on screen inside a real modal sheet',
      (tester) async {
    await openSheet(tester);

    final icons = find.byKey(const Key('capture-icons'));
    expect(icons, findsOneWidget);

    final rect = tester.getRect(icons);
    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(rect.bottom, lessThanOrEqualTo(screenHeight),
        reason: 'capture icons are below the fold of the sheet');
  });

  testWidgets('no overflow when the sheet is opened at phone size',
      (tester) async {
    await openSheet(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'no overflow with both chip rows visible, and the save button stays '
      'reachable (by scrolling if needed) at phone size', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('مشروبات')); // Drinks — reveals the second row.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('subcategory-all')), findsOneWidget);

    // The sheet is capped and scrolls internally rather than shrinking tap
    // targets — ensureVisible proves the save button is still reachable
    // even if the extra row pushed it below the fold.
    await tester.ensureVisible(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final saveButtonSize =
        tester.getSize(find.byKey(const Key('save-button')));
    expect(saveButtonSize.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('شويبس'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
