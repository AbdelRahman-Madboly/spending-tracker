import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_icons.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/transactions.dart';
import 'package:spending_tracker/features/transactions/widgets/transaction_tile.dart';

TransactionView _t(
  String id, {
  String description = 'طماطم',
  int amount = 3000,
  String? group,
  Set<AttachmentKind> kinds = const {},
  EntrySource source = EntrySource.manual,
}) => TransactionView(
  id: id,
  date: DateTime(2026, 9, 20),
  createdAt: DateTime(2026, 9, 20, 21, 30),
  amountPiastres: amount,
  categoryKey: 'Food',
  categoryLabelAr: 'أكل',
  subcategoryKey: 'Groceries',
  subcategoryLabelAr: 'بقالة',
  description: description,
  paymentMethod: 'Cash',
  source: source,
  captureGroupId: group,
  attachmentKinds: kinds,
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: ListView(children: [child])),
    ),
  ),
);

void main() {
  testWidgets('a row shows name, subcategory · time, glyphs and amount', (
    tester,
  ) async {
    await _pump(
      tester,
      TransactionTile(
        entry: _t(
          'a',
          kinds: {AttachmentKind.photo, AttachmentKind.voice},
          source: EntrySource.barcode,
        ),
      ),
    );
    expect(find.text('طماطم'), findsOneWidget);
    expect(find.text('بقالة · 9:30 م'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.byIcon(AppIcons.gallery), findsOneWidget);
    expect(find.byIcon(AppIcons.voiceNote), findsOneWidget);
    expect(find.byIcon(AppIcons.barcode), findsOneWidget);
    expect(find.byIcon(AppIcons.textNote), findsNothing);
    expect(
      tester.getSize(find.byType(TransactionTile)).height,
      greaterThanOrEqualTo(64),
    );
  });

  testWidgets('a selected row swaps its category circle for a check', (
    tester,
  ) async {
    await _pump(tester, TransactionTile(entry: _t('a'), selected: true));
    expect(find.byIcon(AppIcons.checkCircle), findsOneWidget);
  });

  testWidgets('tap and long press reach their callbacks', (tester) async {
    var taps = 0;
    var holds = 0;
    await _pump(
      tester,
      TransactionTile(
        entry: _t('a'),
        onTap: () => taps++,
        onLongPress: () => holds++,
      ),
    );
    await tester.tap(find.byType(TransactionTile));
    await tester.longPress(find.byType(TransactionTile));
    expect((taps, holds), (1, 1));
  });

  testWidgets('a capture group is one parent row that expands to its lines', (
    tester,
  ) async {
    final row = CaptureGroupRow('G', [
      _t('g1', group: 'G', amount: 3000),
      _t('g2', group: 'G', description: 'عيش', amount: 1000),
    ]);
    await _pump(
      tester,
      CaptureGroupTile(
        row: row,
        lineBuilder: (context, line) =>
            TransactionTile(key: ValueKey(line.id), entry: line),
      ),
    );
    expect(find.text('طماطم و 1 أخرى'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('عيش'), findsNothing);

    await tester.tap(find.byKey(const Key('group-expand-G')));
    await tester.pumpAndSettle();
    expect(find.text('عيش'), findsOneWidget);
    // Lines sit indented from the start side, which is the right in RTL.
    final parentRight = tester
        .getTopRight(find.byKey(const Key('group-row-G')))
        .dx;
    final lineRight = tester.getTopRight(find.byKey(const ValueKey('g2'))).dx;
    expect(lineRight, lessThan(parentRight));
  });
}
