import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';

/// A single transparent 1x1 PNG, valid enough for `Image.file` to decode
/// without erroring in a widget test.
final _onePixelPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x64, 0x60, 0x60, 0x60,
  0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0x5F, 0xBB, 0xB6, 0xB1, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Test double for [PhotoCaptureService] — image_picker and
/// permission_handler both use platform channels that don't run under
/// `flutter test`, so `AddSheet` is exercised through this fake instead.
class FakePhotoCaptureService implements PhotoCaptureService {
  @override
  Future<List<String>> pickManyFromGallery() async => const [];

  FakePhotoCaptureService({this.cameraResult, this.galleryResult});

  PhotoCaptureResult? cameraResult;
  PhotoCaptureResult? galleryResult;
  int cameraCalls = 0;
  int galleryCalls = 0;
  final Map<String, File> _files = {};

  /// Every relative path [delete] was called with — lets a test assert
  /// cleanup happened (or didn't) without relying solely on the fake file
  /// actually disappearing from disk.
  final List<String> deletedPaths = [];

  void registerFile(String relativePath, Directory tempDir) {
    final file = File(p.join(tempDir.path, p.basename(relativePath)))
      ..writeAsBytesSync(_onePixelPng);
    _files[relativePath] = file;
  }

  @override
  Future<PhotoCaptureResult> captureFromCamera() async {
    cameraCalls++;
    return cameraResult ??
        const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);
  }

  @override
  Future<PhotoCaptureResult> pickFromGallery() async {
    galleryCalls++;
    return galleryResult ??
        const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);
  }

  @override
  Future<File> resolve(String relativePath) async => _files[relativePath]!;

  @override
  Future<void> delete(String relativePath) async {
    // Deliberately synthetic (no real dart:io call): a plain `testWidgets`
    // body never lets real asynchronous I/O complete (it needs
    // `tester.runAsync()` for that), and this fake's whole purpose is to
    // keep AddSheet's tests off real I/O anyway — the real deletion
    // behaviour is covered directly by photo_storage_test.dart's `test()`
    // cases (which have no such restriction) and by
    // `ImagePickerPhotoCaptureService.delete` delegating to it.
    deletedPaths.add(relativePath);
    _files.remove(relativePath);
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('add_sheet_photo_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required FakePhotoCaptureService service,
    ValueChanged<DraftEntry>? onSubmit,
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: onSubmit ?? (_) {},
            photoCaptureService: service,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('camera button has at least a 48dp tap target', (tester) async {
    final service = FakePhotoCaptureService();
    await pumpSheet(tester, service: service);

    final size = tester.getSize(find.byKey(const Key('camera-button')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('gallery button has at least a 48dp tap target', (tester) async {
    final service = FakePhotoCaptureService();
    await pumpSheet(tester, service: service);

    final size = tester.getSize(find.byKey(const Key('gallery-button')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets(
      'tapping the camera button attaches a photo and shows a thumbnail',
      (tester) async {
    final service = FakePhotoCaptureService(
      cameraResult:
          const PhotoCaptureResult(PhotoCaptureOutcome.attached, 'photos/a.jpg'),
    );
    service.registerFile('photos/a.jpg', tempDir);
    await pumpSheet(tester, service: service);

    expect(find.byKey(const Key('photo-thumbnail')), findsNothing);
    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();

    expect(service.cameraCalls, 1);
    expect(find.byKey(const Key('photo-thumbnail')), findsOneWidget);
    expect(find.byKey(const Key('remove-photo-button')), findsOneWidget);
  });

  testWidgets('tapping the gallery button attaches a photo and shows a thumbnail',
      (tester) async {
    final service = FakePhotoCaptureService(
      galleryResult: const PhotoCaptureResult(
          PhotoCaptureOutcome.attached, 'photos/b.jpg'),
    );
    service.registerFile('photos/b.jpg', tempDir);
    await pumpSheet(tester, service: service);

    await tester.tap(find.byKey(const Key('gallery-button')));
    await tester.pumpAndSettle();

    expect(service.galleryCalls, 1);
    expect(find.byKey(const Key('photo-thumbnail')), findsOneWidget);
  });

  testWidgets('the remove button clears an attached photo', (tester) async {
    final service = FakePhotoCaptureService(
      cameraResult:
          const PhotoCaptureResult(PhotoCaptureOutcome.attached, 'photos/a.jpg'),
    );
    service.registerFile('photos/a.jpg', tempDir);
    await pumpSheet(tester, service: service);

    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-thumbnail')), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-photo-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo-thumbnail')), findsNothing);
    expect(find.byKey(const Key('remove-photo-button')), findsNothing);
  });

  testWidgets('the remove button is at least a 48dp tap target', (tester) async {
    final service = FakePhotoCaptureService(
      cameraResult:
          const PhotoCaptureResult(PhotoCaptureOutcome.attached, 'photos/a.jpg'),
    );
    service.registerFile('photos/a.jpg', tempDir);
    await pumpSheet(tester, service: service);

    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byKey(const Key('remove-photo-button')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets(
      'saving after attaching a photo submits a draft with that photoPath',
      (tester) async {
    final service = FakePhotoCaptureService(
      cameraResult:
          const PhotoCaptureResult(PhotoCaptureOutcome.attached, 'photos/a.jpg'),
    );
    service.registerFile('photos/a.jpg', tempDir);
    DraftEntry? captured;
    await pumpSheet(tester, service: service, onSubmit: (d) => captured = d);

    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(GridView), matching: find.text('شويبس')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.photoPath, 'photos/a.jpg');
  });

  testWidgets(
      'attaching a photo before selecting an item still carries the photo '
      'into the submitted draft', (tester) async {
    final service = FakePhotoCaptureService(
      cameraResult:
          const PhotoCaptureResult(PhotoCaptureOutcome.attached, 'photos/a.jpg'),
    );
    service.registerFile('photos/a.jpg', tempDir);
    DraftEntry? captured;
    await pumpSheet(tester, service: service, onSubmit: (d) => captured = d);

    // Photo first, item second — order must not matter.
    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(GridView), matching: find.text('شويبس')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured!.photoPath, 'photos/a.jpg');
  });

  testWidgets('cancelling the camera leaves no photo and does not crash',
      (tester) async {
    final service = FakePhotoCaptureService(
      cameraResult: const PhotoCaptureResult(PhotoCaptureOutcome.cancelled),
    );
    await pumpSheet(tester, service: service);

    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('photo-thumbnail')), findsNothing);
  });

  testWidgets(
      'a denied camera permission shows a plain Arabic message instead of '
      'crashing or silently doing nothing', (tester) async {
    final service = FakePhotoCaptureService(
      cameraResult:
          const PhotoCaptureResult(PhotoCaptureOutcome.permissionDenied),
    );
    await pumpSheet(tester, service: service);

    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('photo-thumbnail')), findsNothing);
    // A SnackBar (or equivalent) carrying real Arabic text must be shown —
    // not a crash, not a silent no-op.
    expect(find.byType(SnackBar), findsOneWidget);
    final snackBarText = tester.widget<Text>(find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Text),
    ));
    expect(snackBarText.data, isNotNull);
    expect(snackBarText.data!.isNotEmpty, isTrue);
  });

  group('orphaned photo cleanup', () {
    // These need a real dismissable route (unlike pumpSheet's bare
    // Scaffold body) so the sheet can actually be closed — and its
    // dispose() actually run — from within the test.
    Future<void> openModalSheet(
      WidgetTester tester, {
      required FakePhotoCaptureService service,
      ValueChanged<DraftEntry>? onSubmit,
    }) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddSheet(
                      repository: FixtureSpendingRepository(),
                      onSubmit: onSubmit ?? (_) {},
                      photoCaptureService: service,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'an abandoned photo is deleted when the sheet is dismissed without saving',
        (tester) async {
      final service = FakePhotoCaptureService(
        cameraResult: const PhotoCaptureResult(
            PhotoCaptureOutcome.attached, 'photos/a.jpg'),
      );
      service.registerFile('photos/a.jpg', tempDir);
      await openModalSheet(tester, service: service);

      await tester.tap(find.byKey(const Key('camera-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('photo-thumbnail')), findsOneWidget);
      expect(service.deletedPaths, isEmpty);

      // Dismiss without saving — e.g. the user swipes the sheet away.
      Navigator.of(tester.element(find.byType(AddSheet))).pop();
      await tester.pumpAndSettle();

      expect(service.deletedPaths, contains('photos/a.jpg'));
    });

    testWidgets(
        'a saved photo is kept when the sheet closes after saving',
        (tester) async {
      final service = FakePhotoCaptureService(
        cameraResult: const PhotoCaptureResult(
            PhotoCaptureOutcome.attached, 'photos/a.jpg'),
      );
      service.registerFile('photos/a.jpg', tempDir);
      DraftEntry? captured;
      await openModalSheet(
        tester,
        service: service,
        onSubmit: (d) {
          captured = d;
          Navigator.of(tester.element(find.byType(AddSheet))).pop();
        },
      );

      await tester.tap(find.byKey(const Key('camera-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(GridView), matching: find.text('شويبس')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.photoPath, 'photos/a.jpg');
      expect(service.deletedPaths, isNot(contains('photos/a.jpg')));
    });

    testWidgets(
        'replacing a photo with a second capture deletes only the '
        'abandoned first one, keeping the second when it is saved',
        (tester) async {
      final service = FakePhotoCaptureService(
        cameraResult: const PhotoCaptureResult(
            PhotoCaptureOutcome.attached, 'photos/a.jpg'),
      );
      service.registerFile('photos/a.jpg', tempDir);
      service.registerFile('photos/b.jpg', tempDir);
      DraftEntry? captured;
      await openModalSheet(
        tester,
        service: service,
        onSubmit: (d) {
          captured = d;
          Navigator.of(tester.element(find.byType(AddSheet))).pop();
        },
      );

      await tester.tap(find.byKey(const Key('camera-button')));
      await tester.pumpAndSettle();

      service.cameraResult = const PhotoCaptureResult(
          PhotoCaptureOutcome.attached, 'photos/b.jpg');
      await tester.tap(find.byKey(const Key('camera-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: find.byType(GridView), matching: find.text('شويبس')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.photoPath, 'photos/b.jpg');
      expect(service.deletedPaths, contains('photos/a.jpg'));
      expect(service.deletedPaths, isNot(contains('photos/b.jpg')));
    });
  });
}
