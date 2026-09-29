import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';
import 'package:spending_tracker/features/capture/permission_prompt.dart';

import '../capture/permission_fakes.dart';
import 'add_sheet_photo_test.dart' show FakePhotoCaptureService;

void main() {
  late FakePhotoCaptureService photos;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('add_sheet_touches');
    photos = FakePhotoCaptureService(
      cameraResult: const PhotoCaptureResult(
          PhotoCaptureOutcome.attached, 'photos/a.jpg'),
    )..registerFile('photos/a.jpg', tempDir);
  });
  tearDown(() => tempDir.deleteSync(recursive: true));

  /// Opens the sheet the way the app does: in a modal bottom sheet over a
  /// Scaffold of its own, so a snackbar can land behind the sheet.
  Future<void> open(
    WidgetTester tester, {
    required FutureOr<void> Function(DraftEntry) onSubmit,
    PermissionService? permissions,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1080 / 384;
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
                    onSubmit: onSubmit,
                    photoCaptureService: photos,
                    permissionService: permissions ??
                        FakePermissionService(AppPermissionStatus.granted),
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

  Future<void> attachAndSave(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recent-i1'))); // شويبس
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pump();
  }

  testWidgets('a failed save says so on the sheet itself, not behind it',
      (tester) async {
    await open(tester, onSubmit: (_) => throw StateError('disk full'));
    await tester.tap(find.byKey(const Key('recent-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.descendant(
          of: find.byType(AddSheet),
          matching: find.byKey(const Key('save-failed'))),
      findsOneWidget,
    );
  });

  testWidgets('the sheet cannot be dismissed while a save is pending',
      (tester) async {
    final pending = Completer<void>();
    await open(tester, onSubmit: (_) => pending.future);
    await attachAndSave(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AddSheet), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AddSheet), findsNothing);
    expect(photos.deletedPaths, isEmpty,
        reason: 'the saved entry keeps its photo');
  });

  testWidgets(
      'a sheet torn down mid-save keeps the photo once the save lands',
      (tester) async {
    final pending = Completer<void>();
    await open(tester, onSubmit: (_) => pending.future);
    await attachAndSave(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(photos.deletedPaths, isEmpty,
        reason: 'the save may still land; the photo must wait for it');
    pending.complete();
    await tester.pump();
    expect(photos.deletedPaths, isEmpty);
  });

  testWidgets(
      'a sheet torn down mid-save deletes the photo if the save then fails',
      (tester) async {
    final pending = Completer<void>();
    await open(tester, onSubmit: (_) => pending.future);
    await attachAndSave(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.completeError(StateError('disk full'));
    await tester.pump();
    expect(photos.deletedPaths, ['photos/a.jpg']);
  });

  testWidgets('the camera button shows the explanation card first',
      (tester) async {
    final permissions = FakePermissionService(AppPermissionStatus.denied);
    await open(tester, onSubmit: (_) {}, permissions: permissions);
    await tester.tap(find.byKey(const Key('camera-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('permission-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('permission-later')));
    await tester.pumpAndSettle();
    expect(photos.cameraCalls, 0);
  });

  testWidgets('picking a chip gives a selection click', (tester) async {
    final haptics = <String?>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String?);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester, onSubmit: (_) {});
    await tester.tap(find.byKey(const Key('recent-i1')));
    await tester.pumpAndSettle();
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
  });
}
