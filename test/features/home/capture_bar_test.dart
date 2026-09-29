import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/features/home/widgets/capture_bar.dart';

void main() {
  testWidgets('four labelled 56dp buttons, each reporting its own action',
      (tester) async {
    final tapped = <CaptureAction>[];
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: CaptureBar(onAction: tapped.add)),
      ),
    ));

    for (final label in ['صوت', 'كاميرا', 'باركود', 'نص']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final action in CaptureAction.values) {
      final button = find.byKey(Key('capture-${action.name}'));
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(56));
      expect(size.width, greaterThanOrEqualTo(56));
      await tester.tap(button);
    }
    expect(tapped, CaptureAction.values);
  });

  testWidgets('runs voice, camera, barcode, text from the start side',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: CaptureBar(onAction: (_) {})),
      ),
    ));
    final xs = [
      for (final a in CaptureAction.values)
        tester.getCenter(find.byKey(Key('capture-${a.name}'))).dx,
    ];
    // Right to left.
    expect(xs, [...xs]..sort((a, b) => b.compareTo(a)));
  });

  testWidgets('a long press on باركود reports it, the others do nothing',
      (tester) async {
    final held = <CaptureAction>[];
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            body: CaptureBar(onAction: (_) {}, onLongPress: held.add)),
      ),
    ));
    for (final action in CaptureAction.values) {
      await tester.longPress(find.byKey(Key('capture-${action.name}')));
    }
    expect(held, [CaptureAction.barcode]);
  });
}
