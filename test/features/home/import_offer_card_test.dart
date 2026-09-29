import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/import_sources.dart';
import 'package:spending_tracker/features/home/home_screen.dart';

void main() {
  late FixtureSpendingRepository repo;
  late int opened;
  late bool importResult;

  Future<void> pump(WidgetTester tester, {bool withImport = true}) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(
          repository: repo,
          clock: () => DateTime(2026, 9, 6, 12),
          onImportBundled: withImport
              ? () async {
                  opened++;
                  return importResult;
                }
              : null,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = FixtureSpendingRepository();
    opened = 0;
    importResult = true;
  });

  testWidgets('offers the bundled packs once, until imported', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('import-offer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-offer-import')));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.byKey(const Key('import-offer')), findsNothing);
    expect(await repo.setting(importOfferSettingKey), isNotNull);
  });

  testWidgets('backing out of the import keeps the offer', (tester) async {
    importResult = false;
    await pump(tester);
    await tester.tap(find.byKey(const Key('import-offer-import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-offer')), findsOneWidget);
    expect(await repo.setting(importOfferSettingKey), isNull);
  });

  testWidgets('dismissing hides it for good', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('import-offer-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import-offer')), findsNothing);

    await pump(tester);
    expect(find.byKey(const Key('import-offer')), findsNothing);
  });

  testWidgets('no offer without an import to open', (tester) async {
    await pump(tester, withImport: false);
    expect(find.byKey(const Key('import-offer')), findsNothing);
  });
}
