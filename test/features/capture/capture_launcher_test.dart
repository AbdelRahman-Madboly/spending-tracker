import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';
import 'package:spending_tracker/features/capture/capture_launcher.dart';
import 'package:spending_tracker/features/home/widgets/capture_bar.dart';
import 'package:spending_tracker/domain/models.dart';

import '../transactions/attachment_strip_test.dart' show FakeVoicePlayback;
import 'voice_fakes.dart';

class _Photos implements PhotoCaptureService {
  int camera = 0;
  @override
  Future<PhotoCaptureResult> captureFromCamera() async {
    camera++;
    return const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Scanner implements BarcodeScanService {
  int calls = 0;
  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    return null;
  }
}

DateTime _now() => DateTime(2026, 9, 22, 12);

void main() {
  late _Photos photos;
  late _Scanner scanner;
  late FakeVoiceRecorder recorder;
  late FakeSpeechRecognition speech;
  late FixtureSpendingRepository repo;

  Future<void> run(
    WidgetTester tester,
    CaptureAction action, {
    FakeVoiceRecorder? voiceRecorder,
    FakeSpeechRecognition? speechRecognition,
    FixtureSpendingRepository? repository,
  }) async {
    photos = _Photos();
    scanner = _Scanner();
    recorder = voiceRecorder ?? FakeVoiceRecorder();
    speech = speechRecognition ?? FakeSpeechRecognition();
    repo = repository ?? FixtureSpendingRepository();
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
                onPressed: () => launchCapture(
                  context,
                  repo,
                  action,
                  photoCaptureService: photos,
                  barcodeScanService: scanner,
                  voiceRecorderFactory: () => recorder,
                  speechRecognition: speech,
                  playbackFactory: FakeVoicePlayback.new,
                  clock: _now,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('camera opens the add sheet straight into the camera', (
    tester,
  ) async {
    await run(tester, CaptureAction.camera);
    expect(find.byType(AddSheet), findsOneWidget);
    expect(photos.camera, 1);
    expect(scanner.calls, 0);
  });

  testWidgets('barcode opens the add sheet straight into the scanner', (
    tester,
  ) async {
    await run(tester, CaptureAction.barcode);
    expect(find.byType(AddSheet), findsOneWidget);
    expect(scanner.calls, 1);
  });

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

  group('voice', () {
    testWidgets('records with a live timer and transcript, then reviews the '
        'transcript with the audio attached', (tester) async {
      await run(tester, CaptureAction.voice);

      expect(find.byKey(const Key('voice-sheet')), findsOneWidget);
      expect(find.byKey(const Key('voice-waveform')), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(recorder.path, 'attachments/2026-09/${recorder.path!.split('/').last}');

      speech.hear('طماطم ب 30', isFinal: true);
      speech.hear('عيش ب 10');
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('0:03'), findsOneWidget);
      expect(find.text(' / 2:00'), findsOneWidget);
      expect(find.byKey(const Key('voice-transcript')), findsOneWidget);
      expect(find.textContaining('عيش ب 10'), findsOneWidget);

      // Tapped at once: a settle first would run the timer on.
      await tester.tap(find.byKey(const Key('voice-stop')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voice-sheet')), findsNothing);
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
      expect(find.byKey(const Key('review-line-l0')), findsOneWidget);
      expect(find.byKey(const Key('review-line-l1')), findsOneWidget);
      expect(find.byKey(const Key('attachment-strip')), findsOneWidget);

      await tap(tester, find.byKey(const Key('review-save')));

      final entries = await saved();
      expect(entries, hasLength(2));
      expect(entries.every((t) => t.source == EntrySource.voice), isTrue);
      final group = (await repo.captureGroup(entries.first.captureGroupId!))!;
      expect(group.kind, CaptureKind.voice);
      expect(group.rawText, 'طماطم ب 30\nعيش ب 10');
      final audio = group.attachments.single;
      expect(audio.kind, AttachmentKind.voice);
      expect(audio.path, recorder.path);
      expect(audio.transcript, 'طماطم ب 30\nعيش ب 10');
      // Three seconds, plus the time the sheet took to open.
      expect(audio.durationMs, inInclusiveRange(3000, 4000));
    });

    testWidgets('with no offline Arabic and online speech off, records audio '
        'only and asks for the text in review', (tester) async {
      await run(tester, CaptureAction.voice,
          speechRecognition:
              FakeSpeechRecognition(onDeviceError: 'error_language_unavailable'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('voice-offline-hint')), findsOneWidget);
      expect(find.byKey(const Key('voice-audio-only')), findsOneWidget);
      expect(speech.listens.where((l) => !l.onDevice), isEmpty);

      await tap(tester, find.byKey(const Key('voice-stop')));

      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
      expect(find.byKey(const Key('review-type-text')), findsOneWidget);

      // Closed without typing: the audio waits in Needs review.
      await tap(tester, find.byKey(const Key('review-later')));
      final draft = (await repo.watchDraftCaptures().first).single;
      expect(draft.kind, CaptureKind.voice);
      expect(draft.attachments.single.kind, AttachmentKind.voice);
      expect(draft.attachments.single.path, recorder.path);
    });

    testWidgets('a refused microphone says so and opens nothing',
        (tester) async {
      await run(tester, CaptureAction.voice,
          voiceRecorder: FakeVoiceRecorder(permission: false));

      expect(find.byKey(const Key('voice-sheet')), findsNothing);
      expect(find.byKey(const Key('voice-permission-denied')), findsOneWidget);
    });

    testWidgets('إلغاء throws the recording away', (tester) async {
      await run(tester, CaptureAction.voice);
      speech.hear('عيش ب 10', isFinal: true);

      await tap(tester, find.byKey(const Key('voice-cancel')));

      expect(find.byKey(const Key('voice-sheet')), findsNothing);
      expect(find.byKey(const Key('review-sheet')), findsNothing);
      expect(recorder.calls, contains('cancel'));
      expect(await repo.watchDraftCaptures().first, isEmpty);
    });

    testWidgets('back stops the recording and keeps it', (tester) async {
      await run(tester, CaptureAction.voice);
      speech.hear('عيش ب 10', isFinal: true);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(recorder.calls, isNot(contains('cancel')));
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
    });

    testWidgets('stops by itself after two minutes and goes to review',
        (tester) async {
      await run(tester, CaptureAction.voice);
      speech.hear('عيش ب 10', isFinal: true);

      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voice-sheet')), findsNothing);
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
    });
  });

  group('text', () {
    testWidgets('a typed note goes through the parser to review',
        (tester) async {
      await run(tester, CaptureAction.text);
      expect(find.byType(AddSheet), findsNothing);
      expect(find.byKey(const Key('text-note-sheet')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('text-note-field')),
          'طماطم ب 30\nعيش ب 10');
      await tap(tester, find.byKey(const Key('text-note-review')));

      expect(find.byKey(const Key('text-note-sheet')), findsNothing);
      expect(find.byKey(const Key('review-line-l1')), findsOneWidget);
      await tap(tester, find.byKey(const Key('review-save')));

      final entries = await saved();
      expect(entries, hasLength(2));
      expect(entries.every((t) => t.source == EntrySource.text), isTrue);
      final group = (await repo.captureGroup(entries.first.captureGroupId!))!;
      expect(group.kind, CaptureKind.text);
      expect(group.rawText, 'طماطم ب 30\nعيش ب 10');
    });

    testWidgets('review stays off until something is typed', (tester) async {
      await run(tester, CaptureAction.text);
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('text-note-review')))
              .enabled,
          isFalse);
    });

    testWidgets('a note closed before review is kept as a draft',
        (tester) async {
      await run(tester, CaptureAction.text);
      await tester.enterText(
          find.byKey(const Key('text-note-field')), 'عيش ب 10');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review-sheet')), findsNothing);
      final draft = (await repo.watchDraftCaptures().first).single;
      expect(draft.kind, CaptureKind.text);
      expect(draft.rawText, 'عيش ب 10');
    });

    testWidgets('an empty note closed keeps nothing', (tester) async {
      await run(tester, CaptureAction.text);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(await repo.watchDraftCaptures().first, isEmpty);
    });
  });
}
