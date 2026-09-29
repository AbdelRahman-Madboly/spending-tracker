import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/features/capture/permission_prompt.dart';

import 'permission_fakes.dart';

void main() {
  late bool? result;

  Future<void> run(WidgetTester tester, FakePermissionService service,
      AppPermission permission) async {
    result = null;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result =
                  await ensurePermission(context, permission, service: service),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('a granted permission goes straight through, no card',
      (tester) async {
    final service = FakePermissionService(AppPermissionStatus.granted);
    await run(tester, service, AppPermission.camera);
    expect(result, isTrue);
    expect(find.byKey(const Key('permission-card')), findsNothing);
    expect(service.requested, isEmpty);
  });

  testWidgets(
      'before the system dialog an Arabic card explains the camera; '
      'متابعة asks the system and a grant goes through', (tester) async {
    final service = FakePermissionService(AppPermissionStatus.denied,
        afterRequest: AppPermissionStatus.granted);
    await run(tester, service, AppPermission.camera);
    expect(find.byKey(const Key('permission-card')), findsOneWidget);
    expect(find.textContaining('الكاميرا'), findsWidgets);
    expect(service.requested, isEmpty, reason: 'card first, dialog second');
    await tester.tap(find.byKey(const Key('permission-continue')));
    await tester.pumpAndSettle();
    expect(service.requested, [AppPermission.camera]);
    expect(result, isTrue);
    expect(find.byKey(const Key('permission-card')), findsNothing);
  });

  testWidgets('the microphone card names the microphone', (tester) async {
    final service = FakePermissionService(AppPermissionStatus.denied,
        afterRequest: AppPermissionStatus.granted);
    await run(tester, service, AppPermission.microphone);
    expect(find.textContaining('الميكروفون'), findsWidgets);
  });

  testWidgets('مش دلوقتي closes the card without asking the system',
      (tester) async {
    final service = FakePermissionService(AppPermissionStatus.denied);
    await run(tester, service, AppPermission.camera);
    await tester.tap(find.byKey(const Key('permission-later')));
    await tester.pumpAndSettle();
    expect(service.requested, isEmpty);
    expect(result, isFalse);
  });

  testWidgets(
      'a denial after the dialog shows the card again with a link to the '
      "app's settings", (tester) async {
    final service = FakePermissionService(AppPermissionStatus.denied,
        afterRequest: AppPermissionStatus.permanentlyDenied);
    await run(tester, service, AppPermission.microphone);
    await tester.tap(find.byKey(const Key('permission-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('permission-card')), findsOneWidget);
    expect(find.byKey(const Key('permission-open-settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('permission-open-settings')));
    await tester.pumpAndSettle();
    expect(service.settingsOpened, 1);
    expect(result, isFalse);
  });

  testWidgets('permanently denied skips the dialog and offers the settings',
      (tester) async {
    final service =
        FakePermissionService(AppPermissionStatus.permanentlyDenied);
    await run(tester, service, AppPermission.camera);
    expect(find.byKey(const Key('permission-open-settings')), findsOneWidget);
    expect(find.byKey(const Key('permission-continue')), findsNothing);
    await tester.tap(find.byKey(const Key('permission-later')));
    await tester.pumpAndSettle();
    expect(service.requested, isEmpty);
    expect(result, isFalse);
  });

  testWidgets(
      'when the status cannot be read the flow goes on and lets the '
      'feature ask for itself', (tester) async {
    final service =
        FakePermissionService(AppPermissionStatus.denied, throws: true);
    await run(tester, service, AppPermission.camera);
    expect(result, isTrue);
    expect(find.byKey(const Key('permission-card')), findsNothing);
  });
}
