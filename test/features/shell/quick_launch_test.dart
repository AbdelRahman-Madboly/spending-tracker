import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';
import 'package:spending_tracker/features/capture/permission_prompt.dart';
import 'package:spending_tracker/features/shell/app_shell.dart';
import 'package:spending_tracker/features/shell/quick_launch.dart';

import '../capture/permission_fakes.dart';

/// Stands in for the launcher: [launchedWith] is the action the app was
/// cold-started from, and [press] is a quick action picked while it runs.
class FakeQuickActions implements QuickActionsSource {
  FakeQuickActions({this.launchedWith});

  final String? launchedWith;
  void Function(String type)? _handler;
  List<QuickLaunchItem> items = const [];

  void press(String type) => _handler!(type);

  @override
  Future<void> start(
    List<QuickLaunchItem> items,
    void Function(String type) onLaunch,
  ) async {
    this.items = items;
    _handler = onLaunch;
    // The plugin reports the launching action right away, before the
    // app's first frame is necessarily up.
    if (launchedWith case final type?) onLaunch(type);
  }
}

void main() {
  Future<void> pump(WidgetTester tester, FakeQuickActions actions,
      {AppPermissionStatus permission = AppPermissionStatus.denied}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AppShell(
          repository: FixtureSpendingRepository(),
          clock: () => DateTime(2026, 9, 6, 12),
          quickActions: actions,
          permissionService: FakePermissionService(permission),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the launcher gets إضافة، صوت، كاميرا، باركود in that order',
      (tester) async {
    final actions = FakeQuickActions();
    await pump(tester, actions);
    expect([for (final i in actions.items) i.title],
        ['إضافة', 'صوت', 'كاميرا', 'باركود']);
    expect([for (final i in actions.items) i.type],
        ['add', 'voice', 'camera', 'barcode']);
    expect([for (final i in actions.items) i.icon],
        everyElement(startsWith('ic_quick_')));
  });

  testWidgets('a cold start from إضافة opens the add sheet', (tester) async {
    await pump(tester, FakeQuickActions(launchedWith: 'add'));
    expect(find.byType(AddSheet), findsOneWidget);
  });

  testWidgets('a cold start from كاميرا goes to the camera flow',
      (tester) async {
    await pump(tester, FakeQuickActions(launchedWith: 'camera'));
    expect(find.byKey(const Key('permission-card')), findsOneWidget);
    expect(find.text('إذن الكاميرا'), findsOneWidget);
  });

  testWidgets('a warm start from صوت goes to the voice flow', (tester) async {
    final actions = FakeQuickActions();
    await pump(tester, actions);
    expect(find.byKey(const Key('permission-card')), findsNothing);
    actions.press('voice');
    await tester.pumpAndSettle();
    expect(find.text('إذن الميكروفون'), findsOneWidget);
  });

  testWidgets('a warm start from باركود goes to the scanner flow',
      (tester) async {
    final actions = FakeQuickActions();
    await pump(tester, actions);
    actions.press('barcode');
    await tester.pumpAndSettle();
    expect(find.text('إذن الكاميرا'), findsOneWidget);
  });

  testWidgets('a warm start from إضافة opens the add sheet', (tester) async {
    final actions = FakeQuickActions();
    await pump(tester, actions);
    actions.press('add');
    await tester.pumpAndSettle();
    expect(find.byType(AddSheet), findsOneWidget);
  });

  testWidgets('an unknown action does nothing', (tester) async {
    final actions = FakeQuickActions();
    await pump(tester, actions);
    actions.press('something-else');
    await tester.pumpAndSettle();
    expect(find.byType(AddSheet), findsNothing);
    expect(find.byKey(const Key('permission-card')), findsNothing);
  });
}
