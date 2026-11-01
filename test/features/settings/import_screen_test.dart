import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/import/import_pack.dart';
import 'package:spending_tracker/domain/import/importer.dart';
import 'package:spending_tracker/features/settings/import_screen.dart';

ImportRow _row(String ref, int amount, String description,
        {List<String> flags = const []}) =>
    ImportRow(
      externalId: 'pack:p.json:$ref',
      ref: ref,
      date: DateTime(2026, 9, 8),
      amountPiastres: amount,
      categoryKey: 'Transport',
      description: description,
      flags: flags,
      groupKey: 'row:$ref',
    );

final _pack = ImportPack(fileName: 'p.json', rows: [
  _row('a', 3500, 'تاكسي'),
  _row('b', 1200, 'ميكروباص', flags: const ['date_after_midnight: 00:10']),
]);

void main() {
  late FixtureSpendingRepository repo;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Directionality(textDirection: TextDirection.rtl, child: screen),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() => repo = FixtureSpendingRepository());

  testWidgets('lists every row with its flags and writes nothing before '
      'confirming', (tester) async {
    await pump(
        tester,
        ImportScreen(
            repository: repo, importer: Importer(repo), packs: [_pack]));

    expect(find.text('تاكسي'), findsOneWidget);
    expect(find.text('ميكروباص'), findsOneWidget);
    expect(find.textContaining('date_after_midnight'), findsOneWidget);
    expect(find.text('استورد (2)'), findsOneWidget);
    expect(await repo.knownExternalIds(), isEmpty);
  });

  testWidgets('confirming writes the ticked rows only', (tester) async {
    await pump(
        tester,
        ImportScreen(
            repository: repo, importer: Importer(repo), packs: [_pack]));

    await tester.tap(find.byKey(const ValueKey('import-item-pack:p.json:b')));
    await tester.pumpAndSettle();
    expect(find.text('استورد (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();

    expect(await repo.knownExternalIds(), {'pack:p.json:a'});
    expect(find.textContaining('اتضاف 1'), findsOneWidget);
  });

  testWidgets('a row already imported shows as a duplicate and is not ticked',
      (tester) async {
    final importer = Importer(repo);
    await importer.apply(_pack, (await importer.review(_pack)).items);
    await pump(tester,
        ImportScreen(repository: repo, importer: importer, packs: [_pack]));

    expect(find.text('اتستورد قبل كده'), findsNWidgets(2));
    expect(find.text('استورد (0)'), findsOneWidget);
  });

  testWidgets('the bundled packs load into the review', (tester) async {
    await pump(
        tester,
        ImportScreen(
          repository: repo,
          importer: Importer(repo),
          loadBundled: () async => [_pack],
        ));

    await tester.tap(find.byKey(const Key('import-bundled')));
    await tester.pumpAndSettle();
    expect(find.text('تاكسي'), findsOneWidget);
  });

  testWidgets('pasted text is read by the local parser', (tester) async {
    await pump(
        tester,
        ImportScreen(
          repository: repo,
          importer: Importer(repo),
          clock: () => DateTime(2026, 9, 20, 12),
        ));

    await tester.tap(find.byKey(const Key('import-paste')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('import-paste-field')), 'تاكسي ٤٥');
    await tester.tap(find.byKey(const Key('import-paste-ok')));
    await tester.pumpAndSettle();

    expect(find.text('استورد (1)'), findsOneWidget);
  });

  testWidgets('a shared file opens straight on its review', (tester) async {
    await pump(
        tester,
        ImportScreen(
          repository: repo,
          importer: Importer(repo),
          clock: () => DateTime(2026, 9, 20, 12),
          initialFile: (
            name: 'shared.txt',
            bytes: Uint8List.fromList(utf8.encode('تاكسي ٤٥')),
          ),
        ));
    expect(find.text('استورد (1)'), findsOneWidget);
  });

  testWidgets('importing a bundled pack settles the dashboard offer',
      (tester) async {
    final bundled = ImportPack(
        fileName: bundledPackFiles.first, rows: [_row('a', 3500, 'تاكسي')]);
    await pump(
        tester,
        ImportScreen(
            repository: repo, importer: Importer(repo), packs: [bundled]));
    expect(await repo.setting(importOfferSettingKey), isNull);
    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();
    expect(await repo.setting(importOfferSettingKey), isNotNull);
  });

  testWidgets('back after an import reports it as imported', (tester) async {
    bool? popped;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            popped = await Navigator.of(context).push(MaterialPageRoute<bool>(
              builder: (_) => ImportScreen(
                  repository: repo, importer: Importer(repo), packs: [_pack]),
            ));
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
  });
}
