import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/app_flavor.dart';
import 'package:spending_tracker/data/instapay_identity.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/review/review_sheet.dart';

import '../transactions/attachment_strip_test.dart' show FakeVoicePlayback;
import 'review_sheet_photo_test.dart' show FakePhotos, FakeRecognizer;

DateTime _now() => DateTime(2026, 9, 29, 12);

const _received = '''
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

const _uncertain = '''
InstaPay
EGP 700.00
sampleuser@instapay
Reference Number
512345678777
28 Sep 2026
''';

typedef _Salary = ({
  DateTime datePaid,
  int amountPiastres,
  String? evidencePhotoPath,
  String? externalId,
});

class _Repo extends FixtureSpendingRepository {
  final salaries = <_Salary>[];

  @override
  Future<void> addSalaryPeriod({
    required DateTime datePaid,
    required int amountPiastres,
    String? note,
    String? evidencePhotoPath,
    String? externalId,
  }) async {
    await super.addSalaryPeriod(
        datePaid: datePaid,
        amountPiastres: amountPiastres,
        note: note,
        evidencePhotoPath: evidencePhotoPath,
        externalId: externalId);
    salaries.add((
      datePaid: datePaid,
      amountPiastres: amountPiastres,
      evidencePhotoPath: evidencePhotoPath,
      externalId: externalId,
    ));
  }
}

class _Harness {
  final repo = _Repo();
  final photos = FakePhotos();
  final outcomes = <ReviewOutcome>[];
}

Future<_Harness> _open(WidgetTester tester, Map<String, String> texts,
    {List<String> photos = const ['attachments/2026-09/p1.jpg'],
    Future<void> Function(_Repo repo)? before}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final h = _Harness();
  await before?.call(h.repo);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () async => h.outcomes.add(await showReviewSheet(
              context,
              repository: h.repo,
              request: ReviewRequest(
                kind: CaptureKind.photo,
                capturedAt: _now(),
                attachments: [
                  for (final p in photos)
                    DraftAttachment(kind: AttachmentKind.photo, path: p),
                ],
              ),
              clock: _now,
              photoCaptureService: h.photos,
              textRecognition: FakeRecognizer(texts),
              playbackFactory: FakeVoicePlayback.new,
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
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

bool _salaryChosen(WidgetTester tester) => tester
    .widget<SegmentedButton<bool>>(find.byKey(const Key('incoming-segments')))
    .selected
    .single;

void main() {
  testWidgets(
      'money received offers salary or expense, salary chosen, and saves a '
      'salary period with the screenshot as evidence', (tester) async {
    final h = await _open(tester, {'p1.jpg': _received});

    expect(find.byKey(const Key('review-incoming-choice')), findsOneWidget);
    expect(_salaryChosen(tester), isTrue);
    expect(_saveLabel(tester), 'حفظ كمرتب');
    // The total is what is spent: a salary is not.
    expect(tester.widget<Text>(find.byKey(const Key('review-total'))).data,
        '0');
    expect(find.text('9,000'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('review-save')));

    expect(h.outcomes, [ReviewOutcome.saved]);
    expect(h.repo.salaries, [
      (
        datePaid: DateTime(2026, 9, 28),
        amountPiastres: 900000,
        evidencePhotoPath: 'attachments/2026-09/p1.jpg',
        externalId: 'instapay:512345678999',
      ),
    ]);
    expect(await h.repo.referenceExists('512345678999'), isFalse);
    expect(await h.repo.watchEntriesForDay(DateTime(2026, 9, 28)).first,
        isEmpty);
    expect(await h.repo.watchDraftCaptures().first, isEmpty);
    expect(h.photos.deleted, isEmpty);
  });

  testWidgets('choosing expense records it as an expense, never a salary',
      (tester) async {
    final h = await _open(tester, {'p1.jpg': _received});
    await _tap(tester, find.byKey(const Key('incoming-expense')));
    expect(_salaryChosen(tester), isFalse);
    expect(_saveLabel(tester), 'حفظ 1 مصروف');

    await _tap(tester, find.text('عائلة وزيارات').first);
    await _tap(tester, find.byKey(const Key('review-save')));

    expect(h.outcomes, [ReviewOutcome.saved]);
    expect(h.repo.salaries, isEmpty);
    expect(await h.repo.referenceExists('512345678999'), isTrue);
  });

  testWidgets('an uncertain transfer defaults to expense, and says so',
      (tester) async {
    await _open(tester, {'p1.jpg': _uncertain});
    expect(find.byKey(const Key('review-incoming-choice')), findsOneWidget);
    expect(find.byKey(const Key('review-incoming-uncertain')), findsOneWidget);
    expect(_salaryChosen(tester), isFalse);
    expect(_saveLabel(tester), 'حفظ 1 مصروف');
  });

  testWidgets('a transfer sent offers no salary', (tester) async {
    await _open(tester, {
      'p1.jpg': 'InstaPay\nEGP 50.00\nSent to\nsara@instapay\n'
          'Reference Number\n512345678111',
    });
    expect(find.byKey(const Key('review-incoming-choice')), findsNothing);
  });

  testWidgets('a salary already recorded from this transfer is refused',
      (tester) async {
    final h = await _open(tester, {'p1.jpg': _received},
        before: (repo) => repo.addSalaryPeriod(
            datePaid: DateTime(2026, 9, 28),
            amountPiastres: 900000,
            externalId: 'instapay:512345678999'));
    expect(find.byKey(const Key('review-duplicate-reference')), findsOneWidget);
    expect(find.byKey(const Key('review-incoming-choice')), findsNothing);
    expect(h.photos.deleted, ['attachments/2026-09/p1.jpg']);
  });

  testWidgets('a receipt shared with the transfer is still an expense',
      (tester) async {
    final h = await _open(tester, {
      'p1.jpg': _received,
      'p2.jpg': 'Carrefour\nTotal 228.00 EGP',
    }, photos: [
      'attachments/2026-09/p1.jpg',
      'attachments/2026-09/p2.jpg'
    ]);
    expect(_salaryChosen(tester), isTrue);
    expect(_saveLabel(tester), 'حفظ مرتب و1 مصروف');
    await _tap(tester, find.text('أكل').first);
    await _tap(tester, find.byKey(const Key('review-save')));

    expect(h.outcomes, [ReviewOutcome.saved]);
    expect(h.repo.salaries.single.evidencePhotoPath,
        'attachments/2026-09/p1.jpg');
    final entries =
        await h.repo.watchEntriesForDay(DateTime(2026, 9, 28)).first;
    expect(entries.single.amountPiastres, 22800);
    final attachments = await h.repo.attachmentsForEntry(entries.single.id);
    expect([for (final a in attachments) a.path],
        ['attachments/2026-09/p2.jpg']);
  });

  group('the shared build', () {
    setUp(() => AppFlavor.current = AppFlavor.shared);
    tearDown(() => AppFlavor.current = AppFlavor.personal);

    testWidgets('does not take the owner for the user', (tester) async {
      await _open(tester, {'p1.jpg': _received});
      expect(find.byKey(const Key('review-incoming-choice')), findsNothing);
    });

    testWidgets('finds the user by the InstaPay name set in the settings',
        (tester) async {
      await _open(tester, {
        'p1.jpg': 'InstaPay\nEGP 3,000.00\nFrom\nahmed.m@instapay\nTo\n'
            'Sara A***\nsara.a@instapay\nReference Number\n512345678555',
      }, before: (repo) async {
        await repo.setSetting(instaPayIdentitySettingKey, 'sara.a@instapay');
      });
      expect(find.byKey(const Key('review-incoming-choice')), findsOneWidget);
      expect(_salaryChosen(tester), isTrue);
    });
  });
}
