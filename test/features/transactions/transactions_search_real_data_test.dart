import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/domain/import/import_pack.dart';
import 'package:spending_tracker/domain/import/importer.dart';
import 'package:spending_tracker/features/transactions/transactions_screen.dart';
import 'package:spending_tracker/features/transactions/widgets/transaction_tile.dart';

/// Search in السجل over the bundled sample history: the seed (single rows
/// from 1 September, "Taxi" under the item تاكسي, "Schweppes can") plus
/// the bundled packs imported the way Settings imports them (captures with
/// their evidence, such as the sample order of 25 September).
///
/// Found on the phone: with the list scrolled back through the history
/// and an Arabic keyboard up, typing a name showed nothing for entries
/// that were there. The query came with the direction mark the keyboard
/// puts before an English word in a right-to-left field, and the list
/// kept its scroll offset, so what did match opened at the far end.
DateTime _now() => DateTime(2026, 11, 1, 12);

Future<AppDatabase> _realHistory() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final repo = DriftSpendingRepository(db);
  await db.seedFromJsonString(File('assets/seed/seed.json').readAsStringSync());
  var saved = 0;
  final importer = Importer(
    repo,
    readEvidence: (path) async {
      final file = File('assets/import/$path');
      return file.existsSync() ? file.readAsBytes() : null;
    },
    saveEvidence: (bytes, name) async =>
        'attachments/2026-09/${saved++}${name.substring(name.lastIndexOf('.'))}',
  );
  for (final file in [
    'samsung_notes_2026-09.json',
    'manual_2026-09.json',
  ]) {
    final pack = parseImportPack(
      file,
      File('assets/import/$file').readAsStringSync(),
    );
    final review = await importer.review(pack);
    await importer.apply(
      pack,
      review.items.where((i) => i.selectedByDefault).toList(),
    );
  }
  return db;
}

Finder get _list => find.byType(CustomScrollView);

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: _list, matching: find.byType(Scrollable)).first,
    )
    .position;

/// The names of the rows a finger can reach, top to bottom.
List<String> _onScreen(WidgetTester tester) => [
  for (final tile in tester.widgetList<TransactionTile>(
    find.byType(TransactionTile).hitTestable(),
  ))
    tile.entry.name,
];

void main() {
  late AppDatabase db;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    db = (await tester.runAsync(_realHistory))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: TransactionsScreen(
            repository: DriftSpendingRepository(db),
            clock: _now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(db.close);
  }

  /// Scrolls back to the oldest entries, opens search with the keyboard
  /// up and types [query] one character at a time, as a keyboard does.
  Future<void> searchFromTheBottom(WidgetTester tester, String query) async {
    final position = _position(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(2000));
    await tester.tap(find.byKey(const Key('transactions-search')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    for (var i = 1; i <= query.length; i++) {
      await tester.enterText(
        find.byKey(const Key('transactions-search-field')),
        query.substring(0, i),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('an English name typed after a direction mark finds its '
      'entries back at the start', (tester) async {
    await pump(tester);
    await searchFromTheBottom(tester, '‎Taxi');

    expect(_onScreen(tester).first, 'Taxi');
    expect(find.text('مفيش نتائج'), findsNothing);
    // Every seeded Taxi is in the results, down to the oldest.
    await tester.scrollUntilVisible(
      find.text('Taxi to the station (45) + metro back (15)'),
      300,
      scrollable: find
          .descendant(of: _list, matching: find.byType(Scrollable))
          .first,
    );
    await unmount(tester);
  });

  testWidgets('the results open at the newest match, not where the list '
      'was scrolled to', (tester) async {
    await pump(tester);
    await searchFromTheBottom(tester, 'Schweppes');

    expect(_position(tester).pixels, 0);
    // The newest Schweppes, 11 October, is the first row on screen.
    expect(_onScreen(tester).first, 'Schweppes can');
    await unmount(tester);
  });

  testWidgets('a word in a capture\'s lines finds the capture', (tester) async {
    await pump(tester);
    await searchFromTheBottom(tester, 'Power');

    expect(find.byType(CaptureGroupTile).hitTestable(), findsOneWidget);
    expect(find.text('مفيش نتائج'), findsNothing);
    await unmount(tester);
  });
}
