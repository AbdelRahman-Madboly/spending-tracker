import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';

import 'barcode_scanner_screen_test.dart' show FakeScannerCamera;

/// Spec §8: a scan that succeeds gives a medium haptic.
void main() {
  late List<String?> haptics;
  late FakeScannerCamera camera;
  var now = DateTime(2026, 9, 29, 12);

  Future<void> open(WidgetTester tester, {required bool continuous}) async {
    haptics = [];
    camera = FakeScannerCamera();
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String?);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<Object>(
            MaterialPageRoute(
              builder: (_) => BarcodeScannerScreen(
                continuous: continuous,
                camera: camera,
                clock: () => now,
              ),
            ),
          ),
          child: const Text('scan'),
        ),
      ),
    ));
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
  }

  testWidgets('a single scan gives one medium haptic', (tester) async {
    await open(tester, continuous: false);
    camera.onCode!('6221');
    camera.onCode!('6221');
    await tester.pumpAndSettle();
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('each product counted in continuous mode gives a medium haptic',
      (tester) async {
    await open(tester, continuous: true);
    camera.onCode!('6221');
    camera.onCode!('6221'); // the same can, still in front of the camera
    camera.onCode!('6222');
    await tester.pump();
    expect(haptics, [
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
  });
}
