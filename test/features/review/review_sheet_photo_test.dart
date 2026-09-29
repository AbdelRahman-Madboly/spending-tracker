import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/document_picker_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/data/text_recognition_service.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/widgets/category_strip.dart';
import 'package:spending_tracker/features/review/review_sheet.dart';

import '../transactions/attachment_strip_test.dart' show FakeVoicePlayback;

DateTime _now() => DateTime(2026, 9, 29, 12);

const _instaPay = '''
InstaPay
Transaction Successful
EGP 1,250.00
Reference Number
512345678901
28 Sep 2026 10:15 PM
''';

class FakePhotos implements PhotoCaptureService {
  final camera = <String>[];
  final gallery = <List<String>>[];
  final deleted = <String>[];

  @override
  Future<PhotoCaptureResult> captureFromCamera() async => camera.isEmpty
      ? const PhotoCaptureResult(PhotoCaptureOutcome.cancelled)
      : PhotoCaptureResult(PhotoCaptureOutcome.attached, camera.removeAt(0));

  @override
  Future<PhotoCaptureResult> pickFromGallery() async =>
      const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);

  @override
  Future<List<String>> pickManyFromGallery() async =>
      gallery.isEmpty ? const [] : gallery.removeAt(0);

  @override
  Future<File> resolve(String relativePath) async => File('/docs/$relativePath');

  @override
  Future<void> delete(String relativePath) async => deleted.add(relativePath);
}

/// Hands back the text given for a photo's file name, or throws when none
/// was given, as an unreadable image would.
class FakeRecognizer implements TextRecognitionService {
  FakeRecognizer(this.texts);

  final Map<String, String> texts;
  final read = <String>[];

  @override
  Future<String> recognize(String absolutePath) async {
    read.add(absolutePath);
    final name = absolutePath.split('/').last;
    final text = texts[name];
    if (text == null) throw StateError('unreadable');
    return text;
  }
}

class FakeDocuments implements DocumentPickerService {
  PickedDocument? next;

  @override
  Future<PickedDocument?> pickPdf() async => next;
}

class _Harness {
  final repo = FixtureSpendingRepository();
  final photos = FakePhotos();
  final documents = FakeDocuments();
  late FakeRecognizer recognizer;
  final outcomes = <ReviewOutcome>[];
}

Future<_Harness> _open(
  WidgetTester tester, {
  Map<String, String> texts = const {},
  List<DraftAttachment>? attachments,
  ReviewRequest? request,
  Future<void> Function(_Harness h)? before,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final h = _Harness()..recognizer = FakeRecognizer(texts);
  await before?.call(h);
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
                  request: request ??
                      ReviewRequest(
                        kind: CaptureKind.photo,
                        capturedAt: _now(),
                        attachments: attachments ??
                            const [
                              DraftAttachment(
                                  kind: AttachmentKind.photo,
                                  path: 'attachments/2026-09/p1.jpg'),
                            ],
                      ),
                  clock: _now,
                  photoCaptureService: h.photos,
                  textRecognition: h.recognizer,
                  documentPicker: h.documents,
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _saveLabel(WidgetTester tester) => tester
    .widget<Text>(find.descendant(
        of: find.byKey(const Key('review-save')), matching: find.byType(Text)))
    .data!;

Future<CaptureGroupView> _onlyDraft(FixtureSpendingRepository repo) async =>
    (await repo.watchDraftCaptures().first).single;

Future<void> _recordTransfer(FixtureSpendingRepository repo) =>
    repo.saveCapture(CaptureDraft(
      kind: CaptureKind.photo,
      date: DateTime(2026, 9, 28),
      paymentMethod: 'InstaPay',
      lines: const [
        CaptureLine(
          amountPiastres: 125000,
          categoryKey: 'Family/Social',
          reference: '512345678901',
        ),
      ],
    ));

void main() {
  testWidgets('an InstaPay screenshot fills the amount, date, reference and '
      'payment method', (tester) async {
    final h = await _open(tester, texts: {'p1.jpg': _instaPay});

    expect(h.recognizer.read, ['/docs/attachments/2026-09/p1.jpg']);
    expect(find.byKey(const Key('review-type-text')), findsNothing);
    expect(find.byKey(const Key('line-reference')), findsOneWidget);
    expect(find.textContaining('512345678901'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data,
        '1,250');
    final instaPay = tester.widget<SelectableChip>(
        find.byKey(const Key('payment-InstaPay')));
    expect(instaPay.selected, isTrue);

    await _tap(tester, find.text('عائلة وزيارات').first);
    await _tap(tester, find.byKey(const Key('review-save')));

    expect(h.outcomes, [ReviewOutcome.saved]);
    final entries =
        await h.repo.watchEntriesForDay(DateTime(2026, 9, 28)).first;
    final record = (await h.repo.entry(entries.single.id))!;
    expect(record.amountPiastres, 125000);
    expect(record.reference, '512345678901');
    expect(record.paymentMethod, 'InstaPay');
    expect(record.source, EntrySource.photo);
    final attachments = await h.repo.attachmentsForEntry(record.id);
    expect(attachments.single.kind, AttachmentKind.photo);
    expect(attachments.single.path, 'attachments/2026-09/p1.jpg');
  });

  testWidgets('a transfer already recorded is refused and its photo dropped',
      (tester) async {
    final h = await _open(tester,
        texts: {'p1.jpg': _instaPay}, before: (h) => _recordTransfer(h.repo));

    expect(find.byKey(const Key('review-duplicate-reference')), findsOneWidget);
    expect(find.text('العملية دي متسجلة قبل كده'), findsOneWidget);
    expect(find.byKey(const Key('line-reference')), findsNothing);
    expect(find.byKey(const Key('attachment-strip')), findsNothing);
    expect(h.photos.deleted, ['attachments/2026-09/p1.jpg']);

    // Nothing is left to keep: closing leaves no draft behind.
    await _tap(tester, find.byKey(const Key('review-later')));
    expect(await h.repo.watchDraftCaptures().first, isEmpty);
  });

  testWidgets('the same screenshot twice in one capture is refused the second '
      'time', (tester) async {
    final h = await _open(tester, texts: {
      'p1.jpg': _instaPay,
      'p2.jpg': _instaPay,
    });
    h.photos.camera.add('attachments/2026-09/p2.jpg');

    await _tap(tester, find.byKey(const Key('review-add-camera')));

    expect(find.text('العملية دي متسجلة قبل كده'), findsOneWidget);
    expect(find.byKey(const Key('line-reference')), findsOneWidget);
    expect(h.photos.deleted, ['attachments/2026-09/p2.jpg']);
  });

  testWidgets('a reference recorded while the sheet was open is refused at '
      'save', (tester) async {
    final h = await _open(tester, texts: {'p1.jpg': _instaPay});
    await _tap(tester, find.text('عائلة وزيارات').first);
    await _recordTransfer(h.repo);

    await _tap(tester, find.byKey(const Key('review-save')));

    expect(h.outcomes, isEmpty);
    expect(find.text('العملية دي متسجلة قبل كده'), findsOneWidget);
  });

  testWidgets('a photo nothing can be read from is still kept as evidence',
      (tester) async {
    final h = await _open(tester);

    expect(find.byKey(const Key('attachment-strip')), findsOneWidget);
    expect(find.text('مفيش سطور'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('review-later')));

    final draft = await _onlyDraft(h.repo);
    expect(draft.kind, CaptureKind.photo);
    expect(draft.attachments.single.path, 'attachments/2026-09/p1.jpg');
  });

  testWidgets('a product photo is matched against the catalogue by its Latin '
      'name', (tester) async {
    await _open(tester,
        texts: {'p1.jpg': 'PEPSI\n330 ml'},
        before: (h) async {
          final item = await h.repo.createItem(
              nameAr: 'بيبسي كانز',
              categoryKey: 'Drinks',
              defaultAmountPiastres: 2000);
          await h.repo.learnAlias('pepsi', item.id);
        });

    expect(find.byKey(const Key('review-line-l0')), findsOneWidget);
    expect(find.widgetWithText(TextField, 'بيبسي كانز'), findsOneWidget);
    expect(_saveLabel(tester), 'حفظ 1 مصروف');
    expect(find.byKey(const Key('review-blocked')), findsNothing);
  });

  testWidgets('more photos come from the camera and the gallery, each read '
      'into lines', (tester) async {
    final h = await _open(tester, texts: {
      'p1.jpg': 'Carrefour\nTotal 228.00 EGP',
      'p2.jpg': 'Total 40 EGP',
      'p3.jpg': 'Total 15 EGP',
      'p4.jpg': 'nothing here',
    });
    h.photos.camera.add('attachments/2026-09/p2.jpg');
    h.photos.gallery.add([
      'attachments/2026-09/p3.jpg',
      'attachments/2026-09/p4.jpg',
    ]);

    await _tap(tester, find.byKey(const Key('review-add-camera')));
    await _tap(tester, find.byKey(const Key('review-add-gallery')));

    expect(find.byKey(const Key('review-total')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data,
        '283');
    expect(find.byKey(const Key('photo-gallery')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('review-later')));
    final draft = await _onlyDraft(h.repo);
    expect([for (final a in draft.attachments) a.path], [
      'attachments/2026-09/p1.jpg',
      'attachments/2026-09/p2.jpg',
      'attachments/2026-09/p3.jpg',
      'attachments/2026-09/p4.jpg',
    ]);
  });

  testWidgets('a PDF is attached as a file and shows its name', (tester) async {
    final h = await _open(tester, texts: {'p1.jpg': 'Total 40 EGP'});
    h.documents.next = const PickedDocument(
        relativePath: 'attachments/2026-09/d1.pdf', name: 'Invoice 12.pdf');

    await _tap(tester, find.byKey(const Key('review-add-pdf')));

    expect(find.text('Invoice 12.pdf'), findsOneWidget);
    await _tap(tester, find.text('أكل').first);
    await _tap(tester, find.byKey(const Key('review-save')));

    final group = (await h.repo.watchEntriesForDay(DateTime(2026, 9, 29))
            .first)
        .single;
    final attachments = await h.repo.attachmentsForEntry(group.id);
    final file = attachments.singleWhere((a) => a.kind == AttachmentKind.file);
    expect(file.path, 'attachments/2026-09/d1.pdf');
    expect(file.text, 'Invoice 12.pdf');
  });

  testWidgets('a photo draft with no text is read again when reviewed later',
      (tester) async {
    final draft = CaptureGroupView(
      id: 'g1',
      kind: CaptureKind.photo,
      status: CaptureStatus.draft,
      date: DateTime(2026, 9, 29),
      entries: const [],
      attachments: [
        AttachmentView(
          id: 'a1',
          captureGroupId: 'g1',
          kind: AttachmentKind.photo,
          path: 'attachments/2026-09/p1.jpg',
          createdAt: _now(),
        ),
      ],
    );
    final h = await _open(tester,
        texts: {'p1.jpg': _instaPay}, request: ReviewRequest.fromDraft(draft));

    expect(h.recognizer.read, ['/docs/attachments/2026-09/p1.jpg']);
    expect(find.byKey(const Key('line-reference')), findsOneWidget);
    expect(find.byKey(const Key('review-type-text')), findsNothing);
  });
}
