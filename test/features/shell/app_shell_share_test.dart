import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/import_sources.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/widgets/category_strip.dart';
import 'package:spending_tracker/features/settings/import_screen.dart';
import 'package:spending_tracker/features/shell/app_shell.dart';

import '../review/review_sheet_photo_test.dart' show FakePhotos, FakeRecognizer;

const _instaPaySent = '''
InstaPay
Transaction Successful
EGP 1,250.00
Sent to
Ahmed M***
ahmed.m@instapay
Reference Number
512345678901
28 Sep 2026 10:15 PM
''';

const _instaPayReceived = '''
InstaPay
Transaction Successful
EGP 9,000.00
From
Ahmed M***
ahmed.m@instapay
To
Mostafa Sample
sampleuser@instapay
Reference Number
512345678999
28 Sep 2026 10:15 PM
''';

class _Inbox implements ShareInbox {
  final controller = StreamController<SharedImport>();
  @override
  Stream<SharedImport> get shares => controller.stream;
}

void main() {
  late FixtureSpendingRepository repo;
  late FakePhotos photos;
  late FakeRecognizer recognizer;
  late List<String> imported;
  Object? importError;

  Future<_Inbox> pump(WidgetTester tester,
      {Map<String, String> texts = const {},
      void Function(_Inbox inbox)? beforeStart}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    repo = FixtureSpendingRepository();
    photos = FakePhotos();
    recognizer = FakeRecognizer(texts);
    imported = [];
    final inbox = _Inbox();
    addTearDown(inbox.controller.close);
    beforeStart?.call(inbox);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AppShell(
          repository: repo,
          clock: () => DateTime(2026, 9, 29, 12),
          shareInbox: inbox,
          photoCaptureService: photos,
          textRecognition: recognizer,
          importSharedImage: (path) async {
            if (importError case final e?) throw e;
            imported.add(path);
            return 'attachments/2026-09/s${imported.length}.jpg';
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return inbox;
  }

  setUp(() => importError = null);

  testWidgets('shared text opens the import review', (tester) async {
    final inbox = await pump(tester);
    inbox.controller.add(const SharedText('تاكسي ٤٥'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsOneWidget);
    expect(find.text('استورد (1)'), findsOneWidget);
  });

  testWidgets('a shared .sdocx that is not a note says so', (tester) async {
    final inbox = await pump(tester);
    inbox.controller
        .add(SharedFile('Notes_260913_224548.sdocx', Uint8List(3)));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsOneWidget);
    expect(find.textContaining('مش ملف استيراد'), findsOneWidget);
  });

  testWidgets('a shared zip pack opens its review, rows and salary',
      (tester) async {
    final inbox = await pump(tester);
    final archive = Archive()
      ..addFile(ArchiveFile.bytes(
          'manual_2026-10.json',
          utf8.encode(jsonEncode({
            'format': 'manual-import/1',
            'salaryPeriods': [
              {
                'ref': 's1',
                'datePaid': '2026-09-23',
                'amountPiastres': 900000,
                'evidencePhotoPath': 'evidence/s.jpeg',
              },
            ],
            'entries': [
              {
                'ref': 'z1',
                'date': '2026-09-20',
                'amountPiastres': 4500,
                'description': 'تاكسي',
                'categoryKey': 'Transport',
                'evidencePhotoPath': 'evidence/z1.jpeg',
              },
            ],
          }))))
      ..addFile(ArchiveFile.bytes('evidence/s.jpeg', [1]))
      ..addFile(ArchiveFile.bytes('evidence/z1.jpeg', [2]));
    inbox.controller.add(SharedFile(
        'pack.zip', Uint8List.fromList(ZipEncoder().encode(archive))));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsOneWidget);
    expect(find.text('استورد (2)'), findsOneWidget);
  });

  group('shared images', () {
    testWidgets(
        'an InstaPay screenshot opens the photo review, read and attached, '
        'and nothing is saved before it', (tester) async {
      final inbox = await pump(tester, texts: {'s1.jpg': _instaPaySent});
      inbox.controller
          .add(const SharedImages(['/cache/Screenshot_InstaPay.png']));
      await tester.pumpAndSettle();

      expect(imported, ['/cache/Screenshot_InstaPay.png']);
      expect(find.byType(ImportScreen), findsNothing);
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
      expect(recognizer.read, ['/docs/attachments/2026-09/s1.jpg']);
      expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data,
          '1,250');
      expect(
          tester
              .widget<SelectableChip>(find.byKey(const Key('payment-InstaPay')))
              .selected,
          isTrue);
      expect(find.text('512345678901'), findsOneWidget);
      expect(await repo.referenceExists('512345678901'), isFalse);
      expect(await repo.watchDraftCaptures().first, isEmpty);
    });

    testWidgets('several images shared together are one capture',
        (tester) async {
      final inbox = await pump(tester, texts: {
        's1.jpg': 'Carrefour\nTotal 228.00 EGP',
        's2.jpg': 'Kiosk\nTotal 20.00 EGP',
      });
      inbox.controller.add(const SharedImages(['/cache/a.jpg', '/cache/b.jpg']));
      await tester.pumpAndSettle();
      expect(imported, ['/cache/a.jpg', '/cache/b.jpg']);
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data,
          '248');

      await tester.tap(find.byKey(const Key('review-later')));
      await tester.pumpAndSettle();
      final draft = (await repo.watchDraftCaptures().first).single;
      expect(draft.kind, CaptureKind.photo);
      expect([for (final a in draft.attachments) a.path],
          ['attachments/2026-09/s1.jpg', 'attachments/2026-09/s2.jpg']);
    });

    testWidgets('an image shared on a cold start opens once the app is up',
        (tester) async {
      await pump(tester,
          texts: {'s1.jpg': _instaPaySent},
          beforeStart: (inbox) => inbox.controller
              .add(const SharedImages(['/cache/Screenshot.png'])));
      expect(find.byKey(const Key('review-sheet')), findsOneWidget);
      expect(imported, ['/cache/Screenshot.png']);
    });

    testWidgets('a received transfer offers salary or expense in review',
        (tester) async {
      final inbox = await pump(tester, texts: {'s1.jpg': _instaPayReceived});
      inbox.controller.add(const SharedImages(['/cache/Screenshot.png']));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review-incoming-choice')), findsOneWidget);
    });

    testWidgets('an image that cannot be copied says so', (tester) async {
      final inbox = await pump(tester);
      importError = const FileSystemException('gone');
      inbox.controller.add(const SharedImages(['/cache/x.png']));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('shared-image-failed')), findsOneWidget);
      expect(find.byKey(const Key('review-sheet')), findsNothing);
    });
  });
}
