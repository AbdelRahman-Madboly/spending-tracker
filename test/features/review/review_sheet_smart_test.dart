import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/data/text_recognition_service.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';
import 'package:spending_tracker/domain/smart_parse.dart';
import 'package:spending_tracker/features/review/review_sheet.dart';

import '../transactions/attachment_strip_test.dart' show FakeVoicePlayback;

DateTime _now() => DateTime(2026, 9, 22, 12);

class _Photos implements PhotoCaptureService {
  @override
  Future<List<String>> pickManyFromGallery() async => const [];

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

class _Recognizer implements TextRecognitionService {
  String text = '';

  @override
  Future<String> recognize(String path) async => text;
}

class _Smart implements SmartImprover {
  Set<SmartInputKind> kinds = SmartInputKind.values.toSet();
  SmartResult? answer;
  final inputs = <SmartInput>[];

  /// When set, improve waits on it: a request still in flight.
  Completer<void>? hold;

  @override
  Future<Set<SmartInputKind>> available() async => kinds;

  @override
  Future<SmartResult?> improve(SmartInput input,
      {required DateTime day}) async {
    inputs.add(input);
    await hold?.future;
    return answer;
  }
}

ParsedLine _line(String name, int amount,
        {String category = 'Food', int quantityMilli = 1000, String? unit}) =>
    ParsedLine(
      rawText: name,
      date: DateTime(2026, 9, 22),
      name: name,
      categoryKey: category,
      quantityMilli: quantityMilli,
      unit: unit,
      amountPiastres: amount,
      confidence: ParseConfidence.medium,
    );

final _better = SmartResult(
  cleanText: 'طماطم 2 كيلو ب 30\nعيش ب 10',
  lines: [
    _line('طماطم', 3000, quantityMilli: 2000, unit: 'kg'),
    _line('عيش', 1000),
  ],
);

void main() {
  late FixtureSpendingRepository repo;
  late _Smart smart;
  late List<ReviewOutcome> outcomes;
  late List<String> read;

  setUp(() {
    repo = FixtureSpendingRepository();
    smart = _Smart()..answer = _better;
    outcomes = [];
    read = [];
  });

  Future<void> open(WidgetTester tester, ReviewRequest request,
      {String photoText = ''}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () async => outcomes.add(await showReviewSheet(
                context,
                repository: repo,
                request: request,
                clock: _now,
                photoCaptureService: _Photos(),
                textRecognition: _Recognizer()..text = photoText,
                playbackFactory: FakeVoicePlayback.new,
                smartImprover: smart,
                readAttachment: (path) async {
                  read.add(path);
                  return Uint8List.fromList(path.codeUnits);
                },
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<List<TransactionView>> saved() async =>
      (await repo.watchTransactions().first)
          .where((t) => t.captureGroupId != null)
          .toList();

  String total(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('review-total'))).data!;

  ReviewRequest text(String raw) =>
      ReviewRequest(kind: CaptureKind.text, capturedAt: _now(), rawText: raw);

  const smartButton = Key('review-smart');

  testWidgets('with nothing available there is no smart button',
      (tester) async {
    smart.kinds = {};
    await open(tester, text('طماطم ب 30'));
    expect(find.byKey(smartButton), findsNothing);
  });

  testWidgets('the local result shows first; the smart one only after '
      'اعتمد on the before/after comparison', (tester) async {
    await open(tester, text('طماطم اتنين كيلو ب ٣٠ وعيش'));
    final local = total(tester);
    expect(smart.inputs, isEmpty, reason: 'nothing is sent until asked');
    expect(find.text('تحسين'), findsOneWidget);

    await tap(tester, find.byKey(smartButton));
    final compare = find.byKey(const Key('smart-compare'));
    expect(compare, findsOneWidget);
    expect(smart.inputs.single.kind, SmartInputKind.text);
    expect(smart.inputs.single.text, 'طماطم اتنين كيلو ب ٣٠ وعيش');
    expect(find.descendant(of: compare, matching: find.text('قبل')),
        findsOneWidget);
    expect(find.descendant(of: compare, matching: find.text('بعد')),
        findsOneWidget);
    expect(find.descendant(of: compare, matching: find.textContaining('عيش')),
        findsWidgets);
    // Still the local lines behind the comparison.
    expect(total(tester), local);

    await tap(tester, find.byKey(const Key('smart-accept')));
    expect(compare, findsNothing);
    expect(total(tester), '40');

    await tap(tester, find.byKey(const Key('review-save')));
    expect(outcomes, [ReviewOutcome.saved]);
    final entries = await saved();
    final group = (await repo.captureGroup(entries.first.captureGroupId!))!;
    expect(group.rawText, 'طماطم اتنين كيلو ب ٣٠ وعيش');
    expect(group.cleanText, 'طماطم 2 كيلو ب 30\nعيش ب 10');
    expect(group.parsedBy, 'gemini');
    expect(group.entries.map((e) => e.amountPiastres).toSet(), {3000, 1000});
  });

  testWidgets('keeping the local result leaves the lines as they were',
      (tester) async {
    await open(tester, text('طماطم ب 30'));
    await tap(tester, find.byKey(smartButton));
    await tap(tester, find.byKey(const Key('smart-keep')));
    expect(find.byKey(const Key('smart-compare')), findsNothing);
    expect(total(tester), '30');

    await tap(tester, find.byKey(const Key('review-save')));
    final entries = await saved();
    final group = (await repo.captureGroup(entries.first.captureGroupId!))!;
    expect(group.cleanText, isNull);
    expect(group.parsedBy, 'local');
  });

  testWidgets('a failure keeps the local result and says so', (tester) async {
    smart.answer = null;
    await open(tester, text('طماطم ب 30'));
    await tap(tester, find.byKey(smartButton));
    expect(find.byKey(const Key('smart-compare')), findsNothing);
    expect(find.text('التحسين الذكي مش متاح دلوقتي'), findsOneWidget);
    expect(total(tester), '30');
  });

  testWidgets('the button waits while the request runs', (tester) async {
    smart.hold = Completer<void>();
    await open(tester, text('طماطم ب 30'));
    await tester.ensureVisible(find.byKey(smartButton));
    await tester.tap(find.byKey(smartButton));
    await tester.pump();
    expect(find.byKey(const Key('review-smart-busy')), findsOneWidget);
    await tester.tap(find.byKey(smartButton), warnIfMissed: false);
    await tester.pump();
    expect(smart.inputs, hasLength(1));
    smart.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('smart-compare')), findsOneWidget);
  });

  testWidgets('a photo capture offers detailed extraction of its photos',
      (tester) async {
    await open(
        tester,
        ReviewRequest(
          kind: CaptureKind.photo,
          capturedAt: _now(),
          attachments: const [
            DraftAttachment(
                kind: AttachmentKind.photo, path: 'attachments/2026-09/a.jpg'),
            DraftAttachment(
                kind: AttachmentKind.photo, path: 'attachments/2026-09/b.jpg'),
          ],
        ),
        photoText: 'Total 40.00 EGP');
    expect(find.text('استخرج بالتفصيل'), findsOneWidget);
    await tap(tester, find.byKey(smartButton));
    final input = smart.inputs.single;
    expect(input.kind, SmartInputKind.photo);
    expect(input.images, hasLength(2));
    expect(read, ['attachments/2026-09/a.jpg', 'attachments/2026-09/b.jpg']);
    await tap(tester, find.byKey(const Key('smart-accept')));
    expect(total(tester), '40');
  });

  testWidgets('a photo capture without the smart switch has no button',
      (tester) async {
    smart.kinds = {SmartInputKind.audio};
    await open(
        tester,
        ReviewRequest(
          kind: CaptureKind.photo,
          capturedAt: _now(),
          attachments: const [
            DraftAttachment(
                kind: AttachmentKind.photo, path: 'attachments/2026-09/a.jpg'),
          ],
        ));
    expect(find.byKey(smartButton), findsNothing);
  });

  testWidgets('a voice note goes as audio when Gemini audio is on',
      (tester) async {
    await open(
        tester,
        ReviewRequest(
          kind: CaptureKind.voice,
          capturedAt: _now(),
          rawText: 'طماطم ب 30',
          attachments: const [
            DraftAttachment(
                kind: AttachmentKind.voice,
                path: 'attachments/2026-09/v.m4a',
                transcript: 'طماطم ب 30',
                durationMs: 4000),
          ],
        ));
    await tap(tester, find.byKey(smartButton));
    expect(smart.inputs.single.kind, SmartInputKind.audio);
    expect(read, ['attachments/2026-09/v.m4a']);
  });

  testWidgets('without Gemini audio, a voice note sends its transcript',
      (tester) async {
    smart.kinds = {SmartInputKind.text, SmartInputKind.photo};
    await open(
        tester,
        ReviewRequest(
          kind: CaptureKind.voice,
          capturedAt: _now(),
          rawText: 'طماطم ب 30',
          attachments: const [
            DraftAttachment(
                kind: AttachmentKind.voice, path: 'attachments/2026-09/v.m4a'),
          ],
        ));
    await tap(tester, find.byKey(smartButton));
    expect(smart.inputs.single.kind, SmartInputKind.text);
    expect(read, isEmpty);
  });

  testWidgets('a date the smart result found dates the capture',
      (tester) async {
    smart.answer = SmartResult(
      cleanText: 'عيش ب 10',
      date: DateTime(2026, 9, 20),
      lines: [_line('عيش', 1000)],
    );
    await open(tester, text('20/9 عيش ب 10'));
    await tap(tester, find.byKey(smartButton));
    await tap(tester, find.byKey(const Key('smart-accept')));
    await tap(tester, find.byKey(const Key('review-save')));
    final entries = await saved();
    expect(entries.single.date, DateTime(2026, 9, 20));
  });

  testWidgets('closed after اعتمد, the draft keeps the rewrite beside the '
      'raw text', (tester) async {
    await open(tester, text('طماطم اتنين كيلو ب ٣٠ وعيش'));
    await tap(tester, find.byKey(smartButton));
    await tap(tester, find.byKey(const Key('smart-accept')));
    await tap(tester, find.byKey(const Key('review-later')));
    final draft = (await repo.watchDraftCaptures().first).single;
    expect(draft.rawText, 'طماطم اتنين كيلو ب ٣٠ وعيش');
    expect(draft.cleanText, 'طماطم 2 كيلو ب 30\nعيش ب 10');
    expect(draft.parsedBy, 'gemini');
  });

  testWidgets('a photo capture edited after اعتمد keeps the edit in its '
      'draft, not the stale rewrite', (tester) async {
    final photo = ReviewRequest(
      kind: CaptureKind.photo,
      capturedAt: _now(),
      attachments: const [
        DraftAttachment(
            kind: AttachmentKind.photo, path: 'attachments/2026-09/a.jpg'),
      ],
    );
    await open(tester, photo);
    await tap(tester, find.byKey(smartButton));
    await tap(tester, find.byKey(const Key('smart-accept')));
    expect(total(tester), '40');
    await tester.enterText(find.byKey(const Key('line-amount')).first, '55');
    await tester.pumpAndSettle();
    expect(total(tester), '65');
    await tap(tester, find.byKey(const Key('review-later')));

    final draft = (await repo.watchDraftCaptures().first).single;
    await open(tester, ReviewRequest.fromDraft(draft));
    expect(total(tester), '65');
  });

  testWidgets('a photo capture closed right after اعتمد keeps the rewrite',
      (tester) async {
    await open(
        tester,
        ReviewRequest(
          kind: CaptureKind.photo,
          capturedAt: _now(),
          attachments: const [
            DraftAttachment(
                kind: AttachmentKind.photo, path: 'attachments/2026-09/a.jpg'),
          ],
        ));
    await tap(tester, find.byKey(smartButton));
    await tap(tester, find.byKey(const Key('smart-accept')));
    await tap(tester, find.byKey(const Key('review-later')));
    final draft = (await repo.watchDraftCaptures().first).single;
    expect(draft.cleanText, 'طماطم 2 كيلو ب 30\nعيش ب 10');
    expect(draft.parsedBy, 'gemini');
  });

  testWidgets('a barcode capture has no smart button', (tester) async {
    await open(
        tester,
        ReviewRequest(
          kind: CaptureKind.barcode,
          capturedAt: _now(),
          lines: [_line('عصير', 2000)],
        ));
    expect(find.byKey(smartButton), findsNothing);
  });
}
