import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';

/// Stands in for the camera: the test feeds codes through [onCode].
class FakeScannerCamera implements ScannerCamera {
  ValueChanged<String>? onCode;
  int toggles = 0;
  bool disposed = false;
  @override
  final ValueNotifier<bool?> torch = ValueNotifier<bool?>(false);

  @override
  Widget preview({required ValueChanged<String> onCode}) {
    this.onCode = onCode;
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> toggleTorch() async {
    toggles++;
    torch.value = !(torch.value ?? false);
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  late FakeScannerCamera camera;
  Object? popped;

  Future<void> open(WidgetTester tester, {required bool continuous}) async {
    camera = FakeScannerCamera();
    popped = null;
    now = DateTime(2026, 9, 29, 12);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Object>(
                  MaterialPageRoute(
                      builder: (_) => BarcodeScannerScreen(
                          continuous: continuous,
                          camera: camera,
                          clock: () => now)));
            },
            child: const Text('scan'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
  }

  testWidgets('single mode returns the first code seen', (tester) async {
    await open(tester, continuous: false);
    camera.onCode!('6221');
    camera.onCode!('6222');
    await tester.pumpAndSettle();
    expect(popped, '6221');
    expect(camera.disposed, isTrue);
  });

  testWidgets('continuous mode counts products until تم', (tester) async {
    await open(tester, continuous: true);
    expect(find.byKey(const Key('scan-done')), findsNothing);
    camera.onCode!('6221');
    camera.onCode!('6221'); // the same can, still in front of the camera
    await tester.pump();
    now = now.add(const Duration(seconds: 3));
    camera.onCode!('6221');
    camera.onCode!('6222');
    await tester.pump();
    expect(find.text('3 منتج'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-done')));
    await tester.pumpAndSettle();
    expect(popped, ['6221', '6221', '6222']);
  });

  testWidgets('back in continuous mode keeps what was scanned',
      (tester) async {
    await open(tester, continuous: true);
    camera.onCode!('6221');
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.maybePop();
    await tester.pumpAndSettle();
    expect(popped, ['6221']);
  });

  testWidgets('the torch button toggles the torch and says its state',
      (tester) async {
    await open(tester, continuous: true);
    final torch = find.byKey(const Key('scan-torch'));
    expect(tester.getSize(torch).height, greaterThanOrEqualTo(48));
    expect(find.byTooltip('شغّل الفلاش'), findsOneWidget);
    await tester.tap(torch);
    await tester.pump();
    expect(camera.toggles, 1);
    expect(find.byTooltip('اطفي الفلاش'), findsOneWidget);
  });

  testWidgets('no torch button when the camera has none', (tester) async {
    await open(tester, continuous: true);
    camera.torch.value = null;
    await tester.pump();
    expect(find.byKey(const Key('scan-torch')), findsNothing);
  });
}

DateTime now = DateTime(2026, 9, 29, 12);
