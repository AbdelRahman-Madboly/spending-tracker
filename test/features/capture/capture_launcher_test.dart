import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';
import 'package:spending_tracker/features/capture/capture_launcher.dart';
import 'package:spending_tracker/features/home/widgets/capture_bar.dart';

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

void main() {
  late _Photos photos;
  late _Scanner scanner;

  Future<void> run(WidgetTester tester, CaptureAction action) async {
    photos = _Photos();
    scanner = _Scanner();
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
                  FixtureSpendingRepository(),
                  action,
                  photoCaptureService: photos,
                  barcodeScanService: scanner,
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

  testWidgets('voice and text say their flow is coming', (tester) async {
    await run(tester, CaptureAction.text);
    expect(find.byType(AddSheet), findsNothing);
    expect(find.byKey(const Key('capture-soon-text')), findsOneWidget);
  });
}
