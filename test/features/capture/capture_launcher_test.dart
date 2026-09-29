import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/gemini_key_store.dart';
import 'package:spending_tracker/data/net/network_gate.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/data/text_recognition_service.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';
import 'package:spending_tracker/features/capture/capture_launcher.dart';
import 'package:spending_tracker/features/home/widgets/capture_bar.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/online_features.dart';

import '../transactions/attachment_strip_test.dart' show FakeVoicePlayback;
import 'voice_fakes.dart';

class _Photos implements PhotoCaptureService {
  int camera = 0;
  PhotoCaptureResult next =
      const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);
  Object? error;
  @override
  Future<PhotoCaptureResult> captureFromCamera() async {
    camera++;
    if (error case final e?) throw e;
    return next;
  }

  @override
  Future<File> resolve(String relativePath) async => File('/docs/$relativePath');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recognizer implements TextRecognitionService {
  String text = '';
  @override
  Future<String> recognize(String absolutePath) async => text;
}

class _Scanner implements BarcodeScanService {
  int calls = 0;

  /// What the next continuous scan returns.
  List<String> many = const [];
  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    return null;
  }

  @override
  Future<List<String>> scanMany(BuildContext context) async {
    calls++;
    return many;
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
    PhotoCaptureResult? photo,
    Object? photoError,
    String photoText = '',
    List<String> scanned = const [],
    NetworkGate? networkGate,
    GeminiKeyStore? geminiKeyStore,
  }) async {
    photos = _Photos()..error = photoError;
    if (photo != null) photos.next = photo;
    final recognizer = _Recognizer()..text = photoText;
    scanner = _Scanner()..many = scanned;
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
                  textRecognition: recognizer,
                  barcodeScanService: scanner,
                  networkGate: networkGate,
                  geminiKeyStore: geminiKeyStore,
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

  group('barcode', () {
    Finder inLine(int i, Finder f) =>
        find.descendant(of: find.byKey(Key('review-line-l$i')), matching: f);

    testWidgets('scanned products go to review and save as a barcode capture',
        (tester) async {
      final repository = FixtureSpendingRepository();
      final known = await repository.createItem(
          nameAr: 'بيبسي كانز',
          categoryKey: 'Drinks',
          defaultAmountPiastres: 1500,
          barcode: '6221');
      await run(tester, CaptureAction.barcode,
          repository: repository, scanned: ['6221', '9999', '6221']);
      expect(find.byType(AddSheet), findsNothing);
      expect(scanner.calls, 1);
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);

      // The known can, twice, at its price.
      expect(
          tester
              .widget<TextField>(inLine(0, find.byKey(const Key('line-name'))))
              .controller!
              .text,
          'بيبسي كانز');
      expect(
          tester
              .widget<TextField>(
                  inLine(0, find.byKey(const Key('line-amount'))))
              .controller!
              .text,
          '30');
      expect(inLine(1, find.byKey(const Key('line-barcode'))), findsOneWidget);
      expect(inLine(1, find.text('9999')), findsOneWidget);

      // The unknown product is named once, priced and filed.
      expect(inLine(1, find.byKey(const Key('line-name-warning'))),
          findsOneWidget);
      await tester.enterText(
          inLine(1, find.byKey(const Key('line-amount'))), '25');
      await tap(tester, inLine(1, find.byKey(const Key('category-Food'))));
      await tester.pumpAndSettle();
      expect(find.text('اكتب اسم المنتج'), findsOneWidget);
      expect(find.text('كمّل الاسم والمبلغ والفئة في السطور المعلّمة أو امسحها'),
          findsOneWidget);
      expect(
          tester.widget<FilledButton>(find.byKey(const Key('review-save')))
              .enabled,
          isFalse);
      await tester.enterText(
          inLine(1, find.byKey(const Key('line-name'))), 'عصير جهينة');
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('review-save')));

      final entries = await saved();
      expect(entries, hasLength(2));
      expect(entries.every((t) => t.source == EntrySource.barcode), isTrue);
      final group = (await repo.captureGroup(entries.first.captureGroupId!))!;
      expect(group.kind, CaptureKind.barcode);
      expect(group.entries.first.itemId, known.id);
      // The next scan of the new code knows it.
      final learned = (await repo.itemByBarcode('9999'))!;
      expect(learned.nameAr, 'عصير جهينة');
      expect(learned.suggestedAmountPiastres, 2500);
    });

    testWidgets('an unknown code scanned offline and closed unnamed waits in '
        'Needs review with its code', (tester) async {
      await run(tester, CaptureAction.barcode, scanned: ['9999']);
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);

      await tap(tester, find.byKey(const Key('review-later')));

      final draft = (await repo.watchDraftCaptures().first).single;
      expect(draft.kind, CaptureKind.barcode);
      expect(draft.rawText, '#9999');
    });

    testWidgets('a name typed for an unknown code is kept with it',
        (tester) async {
      await run(tester, CaptureAction.barcode, scanned: ['9999', '9999']);
      await tester.enterText(
          inLine(0, find.byKey(const Key('line-name'))), 'عصير جهينة');
      await tester.pumpAndSettle();

      await tap(tester, find.byKey(const Key('review-later')));

      final draft = (await repo.watchDraftCaptures().first).single;
      expect(draft.rawText, '#9999 عصير جهينة\n#9999');
    });

    testWidgets('backing out of the scanner with nothing scanned opens nothing',
        (tester) async {
      await run(tester, CaptureAction.barcode);
      expect(scanner.calls, 1);
      expect(find.byKey(const Key('review-sheet')), findsNothing);
      expect(find.byType(AddSheet), findsNothing);
    });

    testWidgets('with product lookup on, an unknown code takes its name '
        'from Open Food Facts', (tester) async {
      final repository = FixtureSpendingRepository();
      await repository.setSetting(onlineFeaturesSettingKey, 'true');
      await repository.setSetting(
          OnlineFeature.productLookup.settingKey, 'true');
      final gate = NetworkGate(repository,
          clientFactory: () => MockClient((request) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'status': 'success',
                'product': {'product_name_ar': 'عصير جهينة مانجو'},
              })),
              200)));
      await tester.runAsync(() async {
        await run(tester, CaptureAction.barcode,
            repository: repository, scanned: ['6223001360612'],
            networkGate: gate);
        // The lookup runs on real async I/O; let it land.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(inLine(0, find.byKey(const Key('line-name'))))
              .controller!
              .text,
          'عصير جهينة مانجو');
    });
  });

  group('the network rule (spec §9.2)', () {
    for (final action in CaptureAction.values) {
      testWidgets('with every switch off, ${action.name} never builds an '
          'HTTP client', (tester) async {
        final repository = FixtureSpendingRepository();
        var built = 0;
        final gate = NetworkGate(repository, clientFactory: () {
          built++;
          throw StateError('no client may be built');
        });
        await run(tester, action,
            repository: repository,
            networkGate: gate,
            scanned: ['6223001360612'],
            photo: const PhotoCaptureResult(
                PhotoCaptureOutcome.attached, 'attachments/2026-09/p.jpg'),
            photoText: 'InstaPay 150 EGP');
        await tester.pumpAndSettle();
        expect(built, 0);
      });
    }

    testWidgets('with Gemini on, review offers تحسين but sends nothing until '
        'it is tapped, and then only through the gate', (tester) async {
      final repository = FixtureSpendingRepository();
      await repository.setSetting(onlineFeaturesSettingKey, 'true');
      await repository.setSetting(OnlineFeature.gemini.settingKey, 'true');
      var built = 0;
      final gate = NetworkGate(repository, clientFactory: () {
        built++;
        return MockClient((_) async => http.Response('down', 503));
      });
      await run(tester, CaptureAction.text,
          repository: repository,
          networkGate: gate,
          geminiKeyStore: _MemoryKeys('k'));
      await tester.enterText(
          find.byKey(const Key('text-note-field')), 'طماطم ب 30');
      await tap(tester, find.byKey(const Key('text-note-review')));
      expect(find.byKey(const Key('review-smart')), findsOneWidget);
      expect(built, 0);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('review-smart')));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(built, 1);
      expect(find.byKey(const Key('review-smart-failed')), findsOneWidget);
    });

    testWidgets('the master switch alone does not let the barcode lookup out',
        (tester) async {
      final repository = FixtureSpendingRepository();
      await repository.setSetting(onlineFeaturesSettingKey, 'true');
      await repository.setSetting(OnlineFeature.gemini.settingKey, 'true');
      var built = 0;
      final gate = NetworkGate(repository, clientFactory: () {
        built++;
        throw StateError('no client may be built');
      });
      await run(tester, CaptureAction.barcode,
          repository: repository, networkGate: gate, scanned: ['6223001360612']);
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
      expect(built, 0);
    });
  });

  group('camera', () {
    testWidgets('takes a photo and reviews what it reads as a photo capture',
        (tester) async {
      await run(tester, CaptureAction.camera,
          photo: const PhotoCaptureResult(
              PhotoCaptureOutcome.attached, 'attachments/2026-09/p1.jpg'),
          photoText: 'Carrefour\nTotal 228.00 EGP');

      expect(photos.camera, 1);
      expect(find.byType(AddSheet), findsNothing);
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data,
          '228');
      expect(find.byKey(const Key('photo-gallery')), findsOneWidget);

      await tap(tester, find.byKey(const Key('review-later')));
      final draft = (await repo.watchDraftCaptures().first).single;
      expect(draft.kind, CaptureKind.photo);
      expect(draft.attachments.single.path, 'attachments/2026-09/p1.jpg');
    });

    testWidgets('backing out of the camera opens nothing', (tester) async {
      await run(tester, CaptureAction.camera);
      expect(photos.camera, 1);
      expect(find.byKey(const Key('review-sheet')), findsNothing);
    });

    testWidgets('a refused camera says so', (tester) async {
      await run(tester, CaptureAction.camera,
          photo:
              const PhotoCaptureResult(PhotoCaptureOutcome.permissionDenied));
      expect(find.byKey(const Key('photo-permission-denied')), findsOneWidget);
      expect(find.byKey(const Key('review-sheet')), findsNothing);
    });

    testWidgets('a camera that fails says so instead of throwing',
        (tester) async {
      await run(tester, CaptureAction.camera,
          photoError: PlatformException(code: 'camera_access_denied'));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('photo-failed')), findsOneWidget);
      expect(find.byKey(const Key('review-sheet')), findsNothing);
    });
  });

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

class _MemoryKeys implements GeminiKeyStore {
  _MemoryKeys(this.key);

  String? key;

  @override
  Future<String?> read() async => key;

  @override
  Future<void> write(String? value) async => key = value;
}
