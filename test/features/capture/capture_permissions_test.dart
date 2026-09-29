import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/features/capture/capture_launcher.dart';
import 'package:spending_tracker/features/capture/permission_prompt.dart';
import 'package:spending_tracker/features/home/widgets/capture_bar.dart';

import 'permission_fakes.dart';
import 'voice_fakes.dart';

class _Photos implements PhotoCaptureService {
  int camera = 0;
  @override
  Future<PhotoCaptureResult> captureFromCamera() async {
    camera++;
    return const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);
  }

  @override
  Future<File> resolve(String relativePath) async => File(relativePath);

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

  @override
  Future<List<String>> scanMany(BuildContext context) async {
    calls++;
    return const [];
  }
}

void main() {
  late _Photos photos;
  late _Scanner scanner;
  late FakeVoiceRecorder recorder;

  Future<void> run(WidgetTester tester, CaptureAction action,
      FakePermissionService permissions) async {
    photos = _Photos();
    scanner = _Scanner();
    recorder = FakeVoiceRecorder();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => launchCapture(
                context,
                FixtureSpendingRepository(),
                action,
                photoCaptureService: photos,
                barcodeScanService: scanner,
                voiceRecorderFactory: () => recorder,
                speechRecognition: FakeSpeechRecognition(),
                permissionService: permissions,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  final cases = {
    CaptureAction.camera: AppPermission.camera,
    CaptureAction.barcode: AppPermission.camera,
    CaptureAction.voice: AppPermission.microphone,
  };

  for (final MapEntry(key: action, value: permission) in cases.entries) {
    testWidgets(
        '${action.name}: the explanation card comes before anything opens, '
        'and مش دلوقتي opens nothing', (tester) async {
      final permissions = FakePermissionService(AppPermissionStatus.denied);
      await run(tester, action, permissions);
      expect(find.byKey(const Key('permission-card')), findsOneWidget);
      expect(photos.camera + scanner.calls, 0);
      expect(recorder.calls, isEmpty);
      await tester.tap(find.byKey(const Key('permission-later')));
      await tester.pumpAndSettle();
      expect(permissions.requested, isEmpty);
      expect(photos.camera + scanner.calls, 0);
      expect(recorder.calls, isEmpty);
    });

    testWidgets('${action.name}: a grant after متابعة opens the capture',
        (tester) async {
      final permissions = FakePermissionService(AppPermissionStatus.denied,
          afterRequest: AppPermissionStatus.granted);
      await run(tester, action, permissions);
      await tester.tap(find.byKey(const Key('permission-continue')));
      await tester.pumpAndSettle();
      expect(permissions.requested, [permission]);
      if (action == CaptureAction.voice) {
        expect(recorder.calls, contains('start'));
      } else {
        expect(photos.camera + scanner.calls, 1);
      }
    });
  }
}
