import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/import_sources.dart';
import 'package:spending_tracker/features/settings/import_screen.dart';
import 'package:spending_tracker/features/shell/app_shell.dart';

class _Inbox implements ShareInbox {
  final controller = StreamController<SharedImport>();
  @override
  Stream<SharedImport> get shares => controller.stream;
}

void main() {
  Future<_Inbox> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final inbox = _Inbox();
    addTearDown(inbox.controller.close);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AppShell(
          repository: FixtureSpendingRepository(),
          clock: () => DateTime(2026, 9, 6, 12),
          shareInbox: inbox,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return inbox;
  }

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
}
