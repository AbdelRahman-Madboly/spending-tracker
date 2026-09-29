import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';
import 'package:spending_tracker/features/review/review_sheet.dart';

import '../transactions/attachment_strip_test.dart' show FakeVoicePlayback;

DateTime _now() => DateTime(2026, 9, 22, 12);

class _Photos implements PhotoCaptureService {
  @override
  Future<PhotoCaptureResult> captureFromCamera() async =>
      const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);

  @override
  Future<PhotoCaptureResult> pickFromGallery() async =>
      const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);

  @override
  Future<File> resolve(String relativePath) async =>
      File('/nowhere/$relativePath');

  @override
  Future<void> delete(String relativePath) async {}
}

/// Every capture save fails, as a full disk would.
class _FailingRepo extends FixtureSpendingRepository {
  @override
  Future<String> saveCapture(CaptureDraft draft) async {
    if (!draft.isDraft) throw StateError('disk full');
    return super.saveCapture(draft);
  }
}

/// Holds every capture save until [gate] completes, counting the calls.
class _SlowRepo extends FixtureSpendingRepository {
  final gate = Completer<void>();
  int saves = 0;

  @override
  Future<String> saveCapture(CaptureDraft draft) async {
    saves++;
    await gate.future;
    return super.saveCapture(draft);
  }
}

class _Harness {
  final FixtureSpendingRepository repo;
  final outcomes = <ReviewOutcome>[];

  _Harness([FixtureSpendingRepository? repo])
      : repo = repo ?? FixtureSpendingRepository();
}

Future<_Harness> _open(
  WidgetTester tester,
  ReviewRequest request, {
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
              onPressed: () async => h.outcomes.add(
                await showReviewSheet(
                  context,
                  repository: h.repo,
                  request: request,
                  clock: _now,
                  photoCaptureService: _Photos(),
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

ReviewRequest _text(String text, {List<DraftAttachment> attachments = const []}) =>
    ReviewRequest(
      kind: CaptureKind.text,
      capturedAt: _now(),
      rawText: text,
      attachments: attachments,
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _inLine(int index, Finder finder) =>
    find.descendant(of: find.byKey(Key('review-line-l$index')), matching: finder);

String _saveLabel(WidgetTester tester) => tester
    .widget<Text>(find.descendant(
        of: find.byKey(const Key('review-save')), matching: find.byType(Text)))
    .data!;

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('review-save'))).enabled;

Future<List<TransactionView>> _saved(FixtureSpendingRepository repo) async =>
    (await repo.watchTransactions().first)
        .where((t) => t.captureGroupId != null)
        .toList();

void main() {
  testWidgets('parsed lines show as cards with the total and a save count',
      (tester) async {
    await _open(tester, _text('طماطم ب 30\nانودي ب 10'));

    expect(find.byKey(const Key('review-sheet')), findsOneWidget);
    expect(find.byKey(const Key('review-line-l0')), findsOneWidget);
    expect(find.byKey(const Key('review-line-l1')), findsOneWidget);
    expect(
        tester
            .widget<TextField>(_inLine(1, find.byKey(const Key('line-name'))))
            .controller!
            .text,
        'إندومي');
    expect(
        tester
            .widget<TextField>(_inLine(0, find.byKey(const Key('line-amount'))))
            .controller!
            .text,
        '30');
    expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data, '40');
    expect(_saveLabel(tester), 'حفظ 2 مصروف');
    expect(_saveEnabled(tester), isTrue);
    // The captured text is shown as it was written.
    expect(find.byKey(const Key('review-raw-text')), findsOneWidget);
  });

  testWidgets('a doubtful field is outlined, and a missing amount blocks saving',
      (tester) async {
    await _open(tester, _text('عيش\nانودي ب 10'));

    expect(_inLine(0, find.byKey(const Key('line-amount-warning'))),
        findsOneWidget);
    expect(_inLine(0, find.text('اكتب المبلغ')), findsOneWidget);
    // The corrected name is a guess worth a look.
    expect(_inLine(1, find.byKey(const Key('line-name-warning'))),
        findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
    expect(find.byKey(const Key('review-blocked')), findsOneWidget);

    await tester.enterText(_inLine(0, find.byKey(const Key('line-amount'))), '15');
    await tester.pumpAndSettle();

    expect(_inLine(0, find.byKey(const Key('line-amount-warning'))), findsNothing);
    expect(_saveEnabled(tester), isTrue);
    expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data, '25');
  });

  testWidgets('a line with no category blocks saving until one is picked',
      (tester) async {
    await _open(tester, _text('حاجة غريبة ب 20'));

    expect(_inLine(0, find.text('اختار الفئة')), findsOneWidget);
    expect(_inLine(0, find.byKey(const Key('line-category-warning'))),
        findsOneWidget);
    expect(_saveEnabled(tester), isFalse);

    await _tap(tester, _inLine(0, find.byKey(const Key('category-Shopping'))));

    expect(_inLine(0, find.text('اختار الفئة')), findsNothing);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('a line can be removed by a swipe or its button, and + سطر adds one',
      (tester) async {
    await _open(tester, _text('طماطم ب 30\nعيش ب 10\nلبن ب 35'));

    // Swiped on the card's edge: the chip strips scroll sideways themselves.
    final card = find.byKey(const Key('review-line-l0'));
    await tester.dragFrom(
        tester.getTopLeft(card) + const Offset(150, 4), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-line-l0')), findsNothing);
    expect(_saveLabel(tester), 'حفظ 2 مصروف');

    await _tap(tester, _inLine(1, find.byKey(const Key('line-remove'))));
    expect(find.byKey(const Key('review-line-l1')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data, '35');

    await _tap(tester, find.byKey(const Key('review-add-line')));
    expect(find.byKey(const Key('review-line-l3')), findsOneWidget);
    // A blank line blocks saving until it is filled or removed.
    expect(_saveEnabled(tester), isFalse);
    expect(_saveLabel(tester), 'حفظ 2 مصروف');
  });

  testWidgets('with a unit price, a new quantity recomputes the amount',
      (tester) async {
    await _open(tester, _text('طماطم 2 كيلو الكيلو ب 15'));
    final amount = _inLine(0, find.byKey(const Key('line-amount')));
    expect(tester.widget<TextField>(amount).controller!.text, '30');

    await tester.enterText(_inLine(0, find.byKey(const Key('line-quantity'))), '3');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(amount).controller!.text, '45');
  });

  testWidgets(
      'saving writes one entry per line under one group, with the attachments, '
      'date and payment method', (tester) async {
    final h = await _open(
      tester,
      _text('طماطم ب 30\nانودي ب 10', attachments: const [
        DraftAttachment(kind: AttachmentKind.photo, path: 'attachments/2026-09/p.jpg'),
      ]),
    );
    expect(find.byKey(const Key('attachment-strip')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('payment-InstaPay')));
    await _tap(tester, find.byKey(const Key('review-save')));

    expect(h.outcomes, [ReviewOutcome.saved]);
    expect(find.byKey(const Key('review-sheet')), findsNothing);
    final saved = await _saved(h.repo);
    expect(saved.map((t) => t.name).toSet(), {'طماطم', 'إندومي'});
    expect(saved.map((t) => t.captureGroupId).toSet(), hasLength(1));
    expect(saved.every((t) => t.paymentMethod == 'InstaPay'), isTrue);
    expect(saved.every((t) => t.date == DateTime(2026, 9, 22)), isTrue);
    expect(saved.every((t) => t.source == EntrySource.text), isTrue);
    final group = (await h.repo.captureGroup(saved.first.captureGroupId!))!;
    expect(group.status, CaptureStatus.saved);
    expect(group.rawText, 'طماطم ب 30\nانودي ب 10');
    expect(group.attachments.single.kind, AttachmentKind.photo);
    expect(await h.repo.watchDraftCaptures().first, isEmpty);
  });

  testWidgets('linking a line to an item learns its words as an alias',
      (tester) async {
    final h = await _open(tester, _text('الفرن ب 25'));

    await _tap(tester, _inLine(0, find.byKey(const Key('category-Food'))));
    await _tap(tester, _inLine(0, find.byKey(const Key('item-i5'))));
    expect(
        tester
            .widget<TextField>(_inLine(0, find.byKey(const Key('line-name'))))
            .controller!
            .text,
        'مخبز');
    await _tap(tester, find.byKey(const Key('review-save')));

    expect((await h.repo.itemAliases())['الفرن'], 'i5');
    expect((await _saved(h.repo)).single.itemNameAr, 'مخبز');
  });

  testWidgets('closing without saving keeps the capture as a draft',
      (tester) async {
    final h = await _open(tester, _text('طماطم ب 30'));

    Navigator.of(tester.element(find.byKey(const Key('review-sheet')))).pop();
    await tester.pumpAndSettle();

    expect(h.outcomes, [ReviewOutcome.kept]);
    final drafts = await h.repo.watchDraftCaptures().first;
    expect(drafts.single.rawText, 'طماطم ب 30');
    expect(await _saved(h.repo), isEmpty);
  });

  testWidgets('بعدين keeps a draft with its attachments', (tester) async {
    final h = await _open(
      tester,
      _text('طماطم ب 30', attachments: const [
        DraftAttachment(kind: AttachmentKind.voice, path: 'attachments/2026-09/v.m4a'),
      ]),
    );

    await _tap(tester, find.byKey(const Key('review-later')));

    expect(h.outcomes, [ReviewOutcome.kept]);
    final draft = (await h.repo.watchDraftCaptures().first).single;
    expect(draft.attachments.single.kind, AttachmentKind.voice);
  });

  testWidgets('حفظ كملاحظة keeps the capture as a note with no entries',
      (tester) async {
    final h = await _open(tester, _text('افتكر اجيب هدية ب 200'));

    await _tap(tester, find.byKey(const Key('review-note')));

    expect(h.outcomes, [ReviewOutcome.note]);
    expect(await _saved(h.repo), isEmpty);
    expect(await h.repo.watchDraftCaptures().first, isEmpty);
  });

  testWidgets('lines with no text of their own are kept as text a draft re-reads',
      (tester) async {
    final h = await _open(
      tester,
      ReviewRequest(
        kind: CaptureKind.barcode,
        capturedAt: _now(),
        lines: [
          ParsedLine(
            rawText: '',
            date: DateTime(2026, 9, 22),
            name: 'شويبس',
            itemId: 'i1',
            categoryKey: 'Drinks',
            amountPiastres: 4500,
            confidence: ParseConfidence.high,
          ),
        ],
      ),
    );

    await _tap(tester, find.byKey(const Key('review-later')));

    final draft = (await h.repo.watchDraftCaptures().first).single;
    expect(draft.kind, CaptureKind.barcode);
    expect(draft.rawText, 'شويبس ب 45');
  });

  testWidgets('a draft opens in review and saving it finishes that draft',
      (tester) async {
    final repo = FixtureSpendingRepository();
    final draftId = await repo.saveCapture(CaptureDraft(
      kind: CaptureKind.voice,
      date: DateTime(2026, 9, 20),
      rawText: 'طماطم ب 30',
      lines: const [],
      isDraft: true,
      attachments: const [
        DraftAttachment(kind: AttachmentKind.voice, path: 'attachments/2026-09/v.m4a'),
      ],
    ));
    final draft = (await repo.watchDraftCaptures().first).single;
    final h = await _open(tester, ReviewRequest.fromDraft(draft),
        harness: _Harness(repo));

    expect(find.byKey(const Key('review-line-l0')), findsOneWidget);
    expect(find.byKey(Key('voice-${draft.attachments.single.id}')),
        findsOneWidget);
    await _tap(tester, find.byKey(const Key('review-save')));

    expect(await repo.watchDraftCaptures().first, isEmpty);
    final group = (await repo.captureGroup(draftId))!;
    expect(group.status, CaptureStatus.saved);
    expect(group.entries.single.description, 'طماطم');
    expect(group.entries.single.date, DateTime(2026, 9, 20));
    expect(group.attachments, hasLength(1));
    expect(h.outcomes, [ReviewOutcome.saved]);
  });

  testWidgets('closing a draft opened from Needs review leaves it as it was',
      (tester) async {
    final repo = FixtureSpendingRepository();
    await repo.saveCapture(CaptureDraft(
      kind: CaptureKind.text,
      date: DateTime(2026, 9, 20),
      rawText: 'طماطم ب 30',
      lines: const [],
      isDraft: true,
    ));
    final draft = (await repo.watchDraftCaptures().first).single;
    await _open(tester, ReviewRequest.fromDraft(draft), harness: _Harness(repo));

    await _tap(tester, find.byKey(const Key('review-later')));

    expect((await repo.watchDraftCaptures().first).map((d) => d.id), [draft.id]);
  });

  testWidgets('a failed save says so and keeps the sheet open', (tester) async {
    final h = await _open(tester, _text('طماطم ب 30'),
        harness: _Harness(_FailingRepo()));

    await _tap(tester, find.byKey(const Key('review-save')));

    expect(find.byKey(const Key('review-save-failed')), findsOneWidget);
    expect(find.byKey(const Key('review-sheet')), findsOneWidget);
    expect(h.outcomes, isEmpty);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('the payment method starts on the last one used', (tester) async {
    final repo = FixtureSpendingRepository();
    await repo.setSetting(lastPaymentMethodSettingKey, 'Card');
    await _open(tester, _text('طماطم ب 30'), harness: _Harness(repo));

    final card = tester.widget<Semantics>(find
        .descendant(
            of: find.byKey(const Key('payment-Card')),
            matching: find.byType(Semantics))
        .first);
    expect(card.properties.selected, isTrue);
  });

  testWidgets('a double tap on حفظ saves once', (tester) async {
    final repo = _SlowRepo();
    await _open(tester, _text('طماطم ب 30'), harness: _Harness(repo));
    final save = find.byKey(const Key('review-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();

    await tester.tap(save);
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    repo.gate.complete();
    await tester.pumpAndSettle();

    expect(repo.saves, 1);
    expect((await _saved(repo)), hasLength(1));
  });

  group('a voice note nobody transcribed', () {
    const voice = DraftAttachment(
      kind: AttachmentKind.voice,
      path: 'attachments/2026-09/v.m4a',
      durationMs: 4000,
    );
    ReviewRequest unheard() => ReviewRequest(
          kind: CaptureKind.voice,
          capturedAt: _now(),
          attachments: const [voice],
        );

    testWidgets('can be typed in and parsed into lines', (tester) async {
      final h = await _open(tester, unheard());
      expect(find.byKey(const Key('review-line-l0')), findsNothing);

      await tester.enterText(
          find.byKey(const Key('review-type-text')), 'طماطم ب 30\nعيش ب 10');
      await _tap(tester, find.byKey(const Key('review-parse-text')));

      expect(find.byKey(const Key('review-line-l0')), findsOneWidget);
      expect(find.byKey(const Key('review-line-l1')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('review-save')));

      final saved = await _saved(h.repo);
      expect(saved, hasLength(2));
      expect(saved.every((t) => t.source == EntrySource.voice), isTrue);
      final group = (await h.repo.captureGroup(saved.first.captureGroupId!))!;
      expect(group.rawText, 'طماطم ب 30\nعيش ب 10');
      expect(group.attachments.single.kind, AttachmentKind.voice);
      expect(group.attachments.single.transcript, 'طماطم ب 30\nعيش ب 10');
    });

    testWidgets('parsing again replaces the lines the last parse made',
        (tester) async {
      final h = await _open(tester, unheard());
      final field = find.byKey(const Key('review-type-text'));
      await tester.enterText(field, 'طماطم ب 30\nعيش ب 10');
      await _tap(tester, find.byKey(const Key('review-parse-text')));
      await tester.enterText(field, 'طماطم ب 30\nعيش ب 10\nلبن ب 25');
      await _tap(tester, find.byKey(const Key('review-parse-text')));
      await _tap(tester, find.byKey(const Key('review-save')));

      final saved = await _saved(h.repo);
      expect(saved, hasLength(3));
    });

    testWidgets('closed untyped, it waits in Needs review with its audio',
        (tester) async {
      final h = await _open(tester, unheard());
      await _tap(tester, find.byKey(const Key('review-later')));

      final draft = (await h.repo.watchDraftCaptures().first).single;
      expect(draft.kind, CaptureKind.voice);
      expect(draft.rawText, isNull);
      expect(draft.attachments.single.kind, AttachmentKind.voice);
    });

    testWidgets('closed after typing, the draft keeps the typed text',
        (tester) async {
      final h = await _open(tester, unheard());
      await tester.enterText(
          find.byKey(const Key('review-type-text')), 'عيش ب 10');
      await _tap(tester, find.byKey(const Key('review-later')));

      final draft = (await h.repo.watchDraftCaptures().first).single;
      expect(draft.rawText, 'عيش ب 10');
      expect(draft.attachments.single.transcript, 'عيش ب 10');
    });

    testWidgets('a draft of it can be typed in later from Needs review',
        (tester) async {
      final repo = FixtureSpendingRepository();
      final draftId = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.voice,
        date: DateTime(2026, 9, 20),
        lines: const [],
        isDraft: true,
        attachments: const [voice],
      ));
      final draft = (await repo.watchDraftCaptures().first).single;
      await _open(tester, ReviewRequest.fromDraft(draft),
          harness: _Harness(repo));

      await tester.enterText(
          find.byKey(const Key('review-type-text')), 'عيش ب 10');
      await _tap(tester, find.byKey(const Key('review-parse-text')));
      await _tap(tester, find.byKey(const Key('review-save')));

      final group = (await repo.captureGroup(draftId))!;
      expect(group.status, CaptureStatus.saved);
      expect(group.rawText, 'عيش ب 10');
      expect(group.entries.single.amountPiastres, 1000);
    });

    testWidgets('a capture with words shows no typing field', (tester) async {
      await _open(tester, _text('طماطم ب 30'));
      expect(find.byKey(const Key('review-type-text')), findsNothing);
    });
  });
}
