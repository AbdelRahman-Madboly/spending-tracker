import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/document_picker_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/widgets/amount_keypad.dart';
import 'package:spending_tracker/features/transactions/entry_detail_sheet.dart';

import 'attachment_strip_test.dart' show FakeVoicePlayback;

/// The fixture's frozen today; entry '1' is لبن, 35, أكل, on it.
DateTime _now() => DateTime(2026, 9, 6, 12);

class _Photos implements PhotoCaptureService {
  @override
  Future<List<String>> pickManyFromGallery() async => const [];

  @override
  Future<PhotoCaptureResult> captureFromCamera() async =>
      const PhotoCaptureResult(PhotoCaptureOutcome.attached, 'photos/new.jpg');

  @override
  Future<PhotoCaptureResult> pickFromGallery() async =>
      const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);

  @override
  Future<File> resolve(String relativePath) async =>
      File('/nowhere/$relativePath');

  @override
  Future<void> delete(String relativePath) async {}
}

class _Documents implements DocumentPickerService {
  @override
  Future<PickedDocument?> pickPdf() async => const PickedDocument(
      relativePath: 'attachments/2026-09/d1.pdf', name: 'Packing slip.pdf');
}

/// Every write the sheet's actions make fails, as a full disk would.
class _FailingRepo extends FixtureSpendingRepository {
  @override
  Future<String> duplicateEntry(String id, DateTime date) async =>
      throw StateError('disk full');

  @override
  Future<RecurringBillView> createRecurringBill({
    required String nameAr,
    required int amountPiastres,
    required String categoryKey,
    String? subcategoryKey,
    int everyMonths = 1,
    required DateTime nextDue,
    int remindDaysBefore = 2,
  }) async => throw StateError('disk full');

  @override
  Future<void> deleteEntries(Iterable<String> ids) async =>
      throw StateError('disk full');
}

/// Holds every duplicate until [gate] completes, counting the calls.
class _SlowDuplicate extends FixtureSpendingRepository {
  final gate = Completer<void>();
  int calls = 0;

  @override
  Future<String> duplicateEntry(String id, DateTime date) async {
    calls++;
    await gate.future;
    return super.duplicateEntry(id, date);
  }
}

class _Harness {
  final FixtureSpendingRepository repo;
  final results = <EntryDetailResult?>[];

  _Harness([FixtureSpendingRepository? repo])
    : repo = repo ?? FixtureSpendingRepository();
}

Future<_Harness> _open(
  WidgetTester tester, {
  String entryId = '1',
  _Harness? harness,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final h = harness ?? _Harness();
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () async => h.results.add(
                await showEntryDetail(
                  context,
                  repository: h.repo,
                  entryId: entryId,
                  clock: _now,
                  photoCaptureService: _Photos(),
                  documentPicker: _Documents(),
                  playbackFactory: FakeVoicePlayback.new,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) =>
    _tapVisible(tester, find.byKey(const Key('detail-save')));

void main() {
  testWidgets('shows the entry: amount, name, date, category and payment', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byKey(const Key('entry-detail')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('detail-amount-text'))).data,
      '35',
    );
    expect(find.widgetWithText(TextField, 'لبن'), findsOneWidget);
    expect(find.text('الأحد 6 سبتمبر 2026'), findsOneWidget);
    final food = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(const Key('category-Food')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(food.properties.selected, isTrue);
  });

  testWidgets('the keypad edits the amount and حفظ writes it', (tester) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('detail-amount')));
    expect(find.byType(AmountKeypad), findsOneWidget);
    for (final key in [keypadBackspace, keypadBackspace, '4', '2', '×', '2']) {
      await tester.tap(find.byKey(Key('key-$key')));
      await tester.pump();
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('detail-amount-text'))).data,
      '84',
    );
    await _save(tester);

    expect((await h.repo.entry('1'))!.amountPiastres, 8400);
    expect(find.byKey(const Key('entry-detail')), findsNothing);
    expect(h.results.single?.outcome, EntryDetailOutcome.saved);
  });

  testWidgets('category, subcategory, quantity, unit, payment and note save', (
    tester,
  ) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('category-Drinks')));
    await _tapVisible(tester, find.byKey(const Key('subcategory-Soda')));
    await tester.enterText(find.byKey(const Key('detail-quantity')), '1.5');
    await _tapVisible(tester, find.byKey(const Key('unit-liter')));
    await _tapVisible(tester, find.byKey(const Key('payment-InstaPay')));
    await tester.enterText(find.byKey(const Key('detail-note')), 'من الكشك');
    await tester.enterText(find.byKey(const Key('detail-name')), 'سبرايت');
    await _save(tester);

    final e = (await h.repo.entry('1'))!;
    expect(e.categoryKey, 'Drinks');
    expect(e.subcategoryKey, 'Soda');
    expect(e.quantityMilli, 1500);
    expect(e.unit, 'liter');
    expect(e.paymentMethod, 'InstaPay');
    expect(e.note, 'من الكشك');
    expect(e.description, 'سبرايت');
  });

  testWidgets('a unit with no quantity typed is kept (the quantity is one)', (
    tester,
  ) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('unit-kg')));
    await _save(tester);
    final e = (await h.repo.entry('1'))!;
    expect(e.quantityMilli, isNull);
    expect(e.unit, 'kg');
  });

  testWidgets('the date picker moves the entry to another day', (tester) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('detail-date')));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect((await h.repo.entry('1'))!.date, DateTime(2026, 9, 3));
  });

  testWidgets('تكرار اليوم copies the entry to today', (tester) async {
    final h = await _open(tester, entryId: '2'); // إندومي, yesterday
    await _tapVisible(tester, find.byKey(const Key('detail-duplicate')));
    final today = await h.repo.watchEntriesForDay(DateTime(2026, 9, 6)).first;
    expect(today.map((e) => e.displayName), contains('إندومي'));
    expect(find.text('اتكرر النهارده'), findsOneWidget);
  });

  testWidgets('كرر شهرياً makes a recurring bill due a month on', (
    tester,
  ) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('detail-repeat-monthly')));
    final bill = (await h.repo.recurringBills()).single;
    expect(bill.nameAr, 'لبن');
    expect(bill.amountPiastres, 3500);
    expect(bill.categoryKey, 'Food');
    expect(bill.everyMonths, 1);
    expect(bill.nextDue, DateTime(2026, 10, 6));
  });

  testWidgets('كرر شهرياً on an old entry is due next on or after today', (
    tester,
  ) async {
    final h = _Harness();
    final groupId = await h.repo.saveCapture(
      CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 7, 20),
        lines: const [
          CaptureLine(
            amountPiastres: 50000,
            categoryKey: 'Food',
            description: 'نت البيت',
          ),
        ],
      ),
    );
    final old = (await h.repo.captureGroup(groupId))!.entries.single;
    await _open(tester, entryId: old.id, harness: h);
    await _tapVisible(tester, find.byKey(const Key('detail-repeat-monthly')));
    // 20 Jul seen on 6 Sep: 20 Aug is past, so 20 Sep.
    expect(
      (await h.repo.recurringBills()).single.nextDue,
      DateTime(2026, 9, 20),
    );
  });

  testWidgets('إضافة مرفق adds a text note and shows it', (tester) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('detail-add-attachment')));
    await tester.tap(find.byKey(const Key('attach-text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('attach-text-field')),
      'مع أحمد',
    );
    await tester.tap(find.byKey(const Key('attach-text-save')));
    await tester.pumpAndSettle();

    expect((await h.repo.attachmentsForEntry('1')).map((a) => a.text), [
      'مع أحمد',
    ]);
    expect(find.text('مع أحمد'), findsOneWidget);
  });

  testWidgets('إضافة مرفق adds a camera photo', (tester) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('detail-add-attachment')));
    await tester.tap(find.byKey(const Key('attach-camera')));
    await tester.pumpAndSettle();
    final photos = await h.repo.attachmentsForEntry('1');
    expect(photos.single.kind, AttachmentKind.photo);
    expect(photos.single.path, 'photos/new.jpg');
    expect(find.byKey(const Key('photo-gallery')), findsOneWidget);
  });

  testWidgets('إضافة مرفق adds a PDF as a file', (tester) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('detail-add-attachment')));
    await tester.tap(find.byKey(const Key('attach-pdf')));
    await tester.pumpAndSettle();
    final files = await h.repo.attachmentsForEntry('1');
    expect(files.single.kind, AttachmentKind.file);
    expect(files.single.path, 'attachments/2026-09/d1.pdf');
    expect(files.single.text, 'Packing slip.pdf');
    expect(find.text('Packing slip.pdf'), findsOneWidget);
  });

  testWidgets('حذف soft-deletes and hands the id back for the undo', (
    tester,
  ) async {
    final h = await _open(tester);
    await _tapVisible(tester, find.byKey(const Key('detail-delete')));
    expect(await h.repo.entry('1'), isNull);
    expect(find.byKey(const Key('entry-detail')), findsNothing);
    expect(h.results.single?.outcome, EntryDetailOutcome.deleted);
    expect(h.results.single?.entryId, '1');
  });

  testWidgets('a grouped entry lists its siblings, and each one opens', (
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
    final lines = (await repo.captureGroup(groupId))!.entries;

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const Key('open'),
                onPressed: () => showEntryDetail(
                  context,
                  repository: repo,
                  entryId: lines.first.id,
                  clock: _now,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    final sibling = find.byKey(Key('sibling-${lines.last.id}'));
    await _tapVisible(tester, sibling);
    expect(find.widgetWithText(TextField, 'عيش'), findsOneWidget);
    expect(find.byKey(Key('sibling-${lines.first.id}')), findsOneWidget);
  });

  testWidgets('failed actions say so and leave حفظ usable', (tester) async {
    await _open(tester, harness: _Harness(_FailingRepo()));
    await _tapVisible(tester, find.byKey(const Key('detail-duplicate')));
    expect(find.byKey(const Key('detail-action-failed')), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('detail-repeat-monthly')));
    expect(find.byKey(const Key('detail-action-failed')), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('detail-delete')));
    expect(find.byKey(const Key('detail-action-failed')), findsOneWidget);
    expect(find.byKey(const Key('entry-detail')), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('detail-save')),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('a second tap while an action runs does nothing', (tester) async {
    final repo = _SlowDuplicate();
    await _open(tester, harness: _Harness(repo));
    final duplicate = find.byKey(const Key('detail-duplicate'));
    await tester.ensureVisible(duplicate);
    await tester.pumpAndSettle();
    await tester.tap(duplicate);
    await tester.pump();
    await tester.tap(duplicate);
    await tester.pump();
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
  });

  group('moving to a sibling line', () {
    Future<(FixtureSpendingRepository, List<EntryRecord>)> grouped() async {
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
      return (repo, (await repo.captureGroup(groupId))!.entries);
    }

    testWidgets('with no edits goes straight there', (tester) async {
      final (repo, lines) = await grouped();
      await _open(tester, entryId: lines.first.id, harness: _Harness(repo));
      await _tapVisible(tester, find.byKey(Key('sibling-${lines.last.id}')));
      expect(find.byKey(const Key('unsaved-dialog')), findsNothing);
      expect(find.widgetWithText(TextField, 'عيش'), findsOneWidget);
    });

    testWidgets('with edits asks, and تجاهل drops them', (tester) async {
      final (repo, lines) = await grouped();
      await _open(tester, entryId: lines.first.id, harness: _Harness(repo));
      await tester.enterText(find.byKey(const Key('detail-name')), 'قوطة');
      await _tapVisible(tester, find.byKey(Key('sibling-${lines.last.id}')));
      expect(find.byKey(const Key('unsaved-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('unsaved-discard')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'عيش'), findsOneWidget);
      expect((await repo.entry(lines.first.id))!.description, 'طماطم');
    });

    testWidgets('with edits asks, and حفظ keeps them', (tester) async {
      final (repo, lines) = await grouped();
      await _open(tester, entryId: lines.first.id, harness: _Harness(repo));
      await tester.enterText(find.byKey(const Key('detail-name')), 'قوطة');
      await _tapVisible(tester, find.byKey(Key('sibling-${lines.last.id}')));
      await tester.tap(find.byKey(const Key('unsaved-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('entry-detail')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'عيش'), findsOneWidget);
      expect((await repo.entry(lines.first.id))!.description, 'قوطة');
    });

    testWidgets('with edits asks, and إلغاء stays put', (tester) async {
      final (repo, lines) = await grouped();
      await _open(tester, entryId: lines.first.id, harness: _Harness(repo));
      await tester.enterText(find.byKey(const Key('detail-name')), 'قوطة');
      await _tapVisible(tester, find.byKey(Key('sibling-${lines.last.id}')));
      await tester.tap(find.byKey(const Key('unsaved-cancel')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'قوطة'), findsOneWidget);
    });
  });
}
