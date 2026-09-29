import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/transactions.dart';
import 'package:spending_tracker/features/transactions/transactions_screen.dart';
import 'package:spending_tracker/features/transactions/widgets/transaction_tile.dart';

/// The fixture's entries: لبن 35 (أكل) today, 6 September 2026; إندومي 10
/// (أكل) and شويبس 40 (مشروبات) yesterday.
DateTime _today() => DateTime(2026, 9, 6, 12);

/// Deleting fails, as with a full disk.
class _FailingDelete extends FixtureSpendingRepository {
  @override
  Future<void> deleteEntries(Iterable<String> ids) async =>
      throw StateError('disk full');
}

Future<FixtureSpendingRepository> _pump(
  WidgetTester tester, {
  DateTime? initialDay,
  TransactionFilter? initialFilter,
  FixtureSpendingRepository? repository,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final repo = repository ?? FixtureSpendingRepository();
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: TransactionsScreen(
          repository: repo,
          clock: _today,
          initialDay: initialDay,
          initialFilter: initialFilter,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder _row(String id) => find.byKey(Key('row-$id'));

List<String> _names(WidgetTester tester) => [
  for (final tile in tester.widgetList<TransactionTile>(
    find.byType(TransactionTile),
  ))
    tile.entry.name,
];

Future<void> _filter(WidgetTester tester, String chip, String option) async {
  // The chip row scrolls sideways; the later chips start off screen.
  await tester.ensureVisible(find.byKey(Key('filter-$chip')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('filter-$chip')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('filter-option-$option')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('filter-apply')));
  await tester.pumpAndSettle();
}

void main() {
  group('the list', () {
    testWidgets('groups every entry by day, newest first, with day totals', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('أمس'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('اليوم')).dy,
        lessThan(tester.getTopLeft(find.text('أمس')).dy),
      );
      expect(find.byKey(const Key('day-total-2026-09-06')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('day-total-2026-09-05'))).data,
        '50 ج.م',
      );
      expect(_names(tester), unorderedEquals(['لبن', 'إندومي', 'شويبس']));
    });

    testWidgets('a capture group is one parent row with its summed amount', (
      tester,
    ) async {
      final repo = FixtureSpendingRepository();
      final groupId = await repo.saveCapture(
        CaptureDraft(
          kind: CaptureKind.text,
          date: DateTime(2026, 9, 6),
          lines: const [
            CaptureLine(
              amountPiastres: 3000,
              categoryKey: 'Food',
              description: 'طماطم',
            ),
            CaptureLine(
              amountPiastres: 1000,
              categoryKey: 'Food',
              description: 'عيش',
            ),
          ],
        ),
      );
      await _pump(tester, repository: repo);
      expect(find.byKey(Key('group-row-$groupId')), findsOneWidget);
      expect(find.text('طماطم و 1 أخرى'), findsOneWidget);
      expect(find.text('عيش'), findsNothing);
    });

    testWidgets('an empty filter result says so and offers to clear it', (
      tester,
    ) async {
      await _pump(tester);
      await _filter(tester, 'payment', 'InstaPay');
      expect(find.byType(TransactionTile), findsNothing);
      expect(find.text('مفيش نتائج'), findsOneWidget);
      await tester.tap(find.byKey(const Key('filters-clear')));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionTile), findsNWidgets(3));
    });
  });

  group('one month, from statistics', () {
    testWidgets('initialFilter opens on the month, its chip named after it', (
      tester,
    ) async {
      final repo = FixtureSpendingRepository();
      await repo.saveCapture(
        CaptureDraft(
          kind: CaptureKind.text,
          date: DateTime(2026, 8, 20),
          lines: const [
            CaptureLine(
              amountPiastres: 2500,
              categoryKey: 'Food',
              description: 'كشري',
            ),
          ],
        ),
      );
      await _pump(
        tester,
        repository: repo,
        initialFilter: TransactionFilter(
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 8, 31),
        ),
      );
      expect(_names(tester), ['كشري']);
      final chip = tester.widget<FilterChip>(
        find.byKey(const Key('filter-period')),
      );
      expect((chip.label as Text).data, 'أغسطس 2026');
      expect(chip.selected, isTrue);
      // A month is not one day: the list keeps its day headers.
      expect(find.byKey(const Key('day-label')), findsNothing);
    });

    testWidgets('a new request replaces the filter, even for the same month', (
      tester,
    ) async {
      final repo = FixtureSpendingRepository();
      final september = TransactionFilter(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      Widget screen(int request) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: TransactionsScreen(
            repository: repo,
            clock: _today,
            initialFilter: september,
            filterRequest: request,
          ),
        ),
      );
      await tester.pumpWidget(screen(0));
      await tester.pumpAndSettle();
      await _filter(tester, 'payment', 'InstaPay');
      expect(find.byType(TransactionTile), findsNothing);

      await tester.pumpWidget(screen(1));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionTile), findsNWidgets(3));
    });
  });

  group('one day, from the dashboard', () {
    testWidgets('initialDay opens on that day with its total', (tester) async {
      await _pump(tester, initialDay: DateTime(2026, 9, 5));
      expect(find.byKey(const Key('day-label')), findsOneWidget);
      expect(find.text('أمس'), findsOneWidget);
      expect(_names(tester), unorderedEquals(['إندومي', 'شويبس']));
      expect(
        tester.widget<Text>(find.byKey(const Key('day-total'))).data,
        '50 ج.م',
      );
    });

    testWidgets('the stepper walks the days and the close shows them all', (
      tester,
    ) async {
      await _pump(tester, initialDay: DateTime(2026, 9, 6));
      final next = find.byKey(const Key('day-next'));
      expect(tester.widget<IconButton>(next).onPressed, isNull);

      await tester.tap(find.byKey(const Key('day-previous')));
      await tester.pumpAndSettle();
      expect(find.text('أمس'), findsOneWidget);

      await tester.tap(find.byKey(const Key('day-previous')));
      await tester.pumpAndSettle();
      expect(find.text('الجمعة 4 سبتمبر'), findsOneWidget);
      expect(find.text('مفيش مصاريف في اليوم ده'), findsOneWidget);

      await tester.tap(find.byKey(const Key('day-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('day-label')), findsNothing);
      expect(find.byType(TransactionTile), findsNWidgets(3));
    });
  });

  group('search and filters', () {
    testWidgets('search matches whatever spelling was typed', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('transactions-search')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('transactions-search-field')),
        'اندومى',
      );
      await tester.pumpAndSettle();
      expect(_names(tester), ['إندومي']);

      await tester.tap(find.byKey(const Key('search-close')));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionTile), findsNWidgets(3));
    });

    testWidgets('the category chip filters to the chosen categories', (
      tester,
    ) async {
      await _pump(tester);
      await _filter(tester, 'category', 'Drinks');
      expect(_names(tester), ['شويبس']);
      expect(find.text('الفئة (1)'), findsOneWidget);
    });

    testWidgets('the attachment chip keeps entries with that kind', (
      tester,
    ) async {
      final repo = FixtureSpendingRepository();
      await repo.addAttachment(
        entryId: '1',
        attachment: const DraftAttachment(
          kind: AttachmentKind.text,
          text: 'ملاحظة',
        ),
      );
      await _pump(tester, repository: repo);
      await _filter(tester, 'attachment', 'text');
      expect(_names(tester), ['لبن']);
    });

    testWidgets('the period chip narrows to today', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('filter-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('period-today')));
      await tester.pumpAndSettle();
      expect(_names(tester), ['لبن']);
    });
  });

  group('delete and edit', () {
    testWidgets('swiping from the end side deletes, and تراجع brings it back', (
      tester,
    ) async {
      final repo = await _pump(tester);
      // The end side is the left in RTL: the swipe runs left to right.
      await tester.drag(_row('1'), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(_row('1'), findsNothing);
      expect(await repo.entry('1'), isNull);
      expect(find.byKey(const Key('undo-snackbar')), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(_row('1'), findsOneWidget);
      expect(await repo.entry('1'), isNotNull);
    });

    testWidgets('the undo lasts five seconds', (tester) async {
      await _pump(tester);
      await tester.drag(_row('1'), const Offset(600, 0));
      await tester.pumpAndSettle();
      final bar = tester.widget<SnackBar>(
        find.byKey(const Key('undo-snackbar')),
      );
      expect(bar.duration, const Duration(seconds: 5));
      expect(bar.persist, isFalse);
    });

    testWidgets('swiping from the start side opens the editor', (tester) async {
      await _pump(tester);
      await tester.drag(_row('1'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('entry-detail')), findsOneWidget);
      // The row stays.
      expect(_row('1'), findsOneWidget);
    });

    testWidgets('tapping a row opens its detail; deleting there offers undo', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await tester.tap(_row('2'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('entry-detail')), findsOneWidget);

      final delete = find.byKey(const Key('detail-delete'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(_row('2'), findsNothing);

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(await repo.entry('2'), isNotNull);
      expect(_row('2'), findsOneWidget);
    });
  });

  group('multi-select', () {
    testWidgets('long press selects; bulk delete removes all with one undo', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await tester.longPress(_row('1'));
      await tester.pumpAndSettle();
      expect(find.text('1 محدد'), findsOneWidget);
      await tester.tap(_row('3'));
      await tester.pumpAndSettle();
      expect(find.text('2 محدد'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bulk-delete')));
      await tester.pumpAndSettle();
      expect(_names(tester), ['إندومي']);
      expect(find.text('اتمسح 2'), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(await repo.entry('1'), isNotNull);
      expect(await repo.entry('3'), isNotNull);
      expect(find.byType(TransactionTile), findsNWidgets(3));
    });

    testWidgets('bulk category change moves the selected entries', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await tester.longPress(_row('1'));
      await tester.pumpAndSettle();
      await tester.tap(_row('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recategorize-Snacks')));
      await tester.pumpAndSettle();

      expect((await repo.entry('1'))!.categoryKey, 'Snacks');
      expect((await repo.entry('2'))!.categoryKey, 'Snacks');
      expect(find.text('1 محدد'), findsNothing);
    });

    testWidgets('the close button leaves selection', (tester) async {
      await _pump(tester);
      await tester.longPress(_row('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('selection-close')));
      await tester.pumpAndSettle();
      expect(find.text('1 محدد'), findsNothing);
      expect(find.text('السجل'), findsOneWidget);
    });
  });

  group('selection and filters together', () {
    testWidgets('the filter chips are off while selecting', (tester) async {
      await _pump(tester);
      await tester.longPress(_row('1'));
      await tester.pumpAndSettle();
      for (final chip in ['period', 'category', 'payment', 'attachment']) {
        expect(
          tester.widget<FilterChip>(find.byKey(Key('filter-$chip'))).onSelected,
          isNull,
          reason: chip,
        );
      }
    });

    testWidgets('stepping to another day drops the selection', (tester) async {
      final repo = await _pump(tester, initialDay: DateTime(2026, 9, 6));
      await tester.longPress(_row('1'));
      await tester.pumpAndSettle();
      expect(find.text('1 محدد'), findsOneWidget);
      await tester.tap(find.byKey(const Key('day-previous')));
      await tester.pumpAndSettle();
      expect(find.text('1 محدد'), findsNothing);
      expect(find.byKey(const Key('bulk-delete')), findsNothing);
      expect(await repo.entry('1'), isNotNull);
    });
  });

  testWidgets('a failed delete brings the rows back and says so', (
    tester,
  ) async {
    await _pump(tester, repository: _FailingDelete());
    await tester.drag(_row('1'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(_row('1'), findsOneWidget);
    expect(find.byKey(const Key('delete-failed')), findsOneWidget);
    expect(find.byKey(const Key('undo-snackbar')), findsNothing);
  });
}
