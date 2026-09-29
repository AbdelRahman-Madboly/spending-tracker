import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/gemini_key_store.dart';
import 'package:spending_tracker/data/net/gemini_client.dart';
import 'package:spending_tracker/data/net/network_gate.dart';
import 'package:spending_tracker/domain/online_features.dart';
import 'package:spending_tracker/features/settings/settings_screen.dart';

class _Keys implements GeminiKeyStore {
  String? key;

  @override
  Future<String?> read() async => key;

  @override
  Future<void> write(String? value) async =>
      key = (value?.trim().isEmpty ?? true) ? null : value!.trim();
}

void main() {
  late FixtureSpendingRepository repo;
  late _Keys keys;
  late List<http.Request> requests;
  late int built;
  late int status;

  setUp(() {
    repo = FixtureSpendingRepository();
    keys = _Keys();
    requests = [];
    built = 0;
    status = 200;
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final gate = NetworkGate(repo, clientFactory: () {
      built++;
      return MockClient((request) async {
        requests.add(request);
        return http.Response('{}', status);
      });
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SettingsScreen(
          repository: repo,
          geminiKeyStore: keys,
          gemini: GeminiClient(gate, repo, keys),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  bool isOn(WidgetTester tester, Key key) =>
      tester.widget<SwitchListTile>(find.byKey(key)).value;

  bool isEnabled(WidgetTester tester, Key key) =>
      tester.widget<SwitchListTile>(find.byKey(key)).onChanged != null;

  const master = Key('settings-online-master');
  Key feature(OnlineFeature f) => Key('settings-online-${f.name}');

  testWidgets('everything is off by default and the features wait for the '
      'master switch', (tester) async {
    await pump(tester);
    expect(find.text('المزايا الأونلاين'), findsOneWidget);
    expect(isOn(tester, master), isFalse);
    for (final f in OnlineFeature.values) {
      expect(isOn(tester, feature(f)), isFalse, reason: f.name);
      expect(isEnabled(tester, feature(f)), isFalse, reason: f.name);
    }
    expect(
        find.text('البيانات بتتبعت لجوجل. في الخطة المجانية ممكن تُستخدم '
            'لتحسين خدماتهم.'),
        findsOneWidget);
  });

  testWidgets('the switches are remembered in app settings', (tester) async {
    await pump(tester);
    await tap(tester, master);
    expect(await repo.setting(onlineFeaturesSettingKey), 'true');
    expect(isEnabled(tester, feature(OnlineFeature.gemini)), isTrue);

    await tap(tester, feature(OnlineFeature.gemini));
    await tap(tester, feature(OnlineFeature.productLookup));
    expect(await isOnlineFeatureOn(repo, OnlineFeature.gemini), isTrue);
    expect(await isOnlineFeatureOn(repo, OnlineFeature.productLookup), isTrue);
    expect(await isOnlineFeatureOn(repo, OnlineFeature.geminiAudio), isFalse);

    await tap(tester, master);
    expect(await isOnlineFeatureOn(repo, OnlineFeature.gemini), isFalse);
    // The feature's own choice is kept for when the master comes back on.
    expect(await repo.setting(OnlineFeature.gemini.settingKey), 'true');
  });

  testWidgets('a saved switch shows on when the screen opens', (tester) async {
    await repo.setSetting(onlineFeaturesSettingKey, 'true');
    await repo.setSetting(OnlineFeature.geminiAudio.settingKey, 'true');
    await pump(tester);
    expect(isOn(tester, master), isTrue);
    expect(isOn(tester, feature(OnlineFeature.geminiAudio)), isTrue);
    expect(isOn(tester, feature(OnlineFeature.gemini)), isFalse);
  });

  testWidgets('the key is obscured, saved to secure storage only and never '
      'shown again', (tester) async {
    await pump(tester);
    final field = find.byKey(const Key('settings-gemini-key'));
    await tester.ensureVisible(field);
    expect(
        tester
            .widget<EditableText>(
                find.descendant(of: field, matching: find.byType(EditableText)))
            .obscureText,
        isTrue);
    await tester.enterText(field, 'AI-secret-1');
    await tap(tester, const Key('settings-gemini-key-save'));

    expect(keys.key, 'AI-secret-1');
    expect(find.text('AI-secret-1'), findsNothing);
    expect(find.text('المفتاح محفوظ'), findsOneWidget);

    await tap(tester, const Key('settings-gemini-key-clear'));
    expect(keys.key, isNull);
    expect(find.text('المفتاح محفوظ'), findsNothing);
  });

  testWidgets('the model id is a setting with the default filled in',
      (tester) async {
    await pump(tester);
    final field = find.byKey(const Key('settings-gemini-model'));
    await tester.ensureVisible(field);
    expect(tester.widget<TextField>(field).controller!.text,
        defaultGeminiModel);
    await tester.enterText(field, 'gemini-3.8-flash');
    await tester.pumpAndSettle();
    expect(await repo.setting(geminiModelSettingKey), 'gemini-3.8-flash');
  });

  group('the test button', () {
    testWidgets('says the key works', (tester) async {
      await repo.setSetting(onlineFeaturesSettingKey, 'true');
      await repo.setSetting(OnlineFeature.gemini.settingKey, 'true');
      keys.key = 'saved-key';
      await pump(tester);
      await tap(tester, const Key('settings-gemini-test'));
      expect(find.text('المفتاح شغال'), findsOneWidget);
      expect(requests.single.headers['x-goog-api-key'], 'saved-key');
    });

    testWidgets('tries a typed key before it is saved, and says when it fails',
        (tester) async {
      await repo.setSetting(onlineFeaturesSettingKey, 'true');
      await repo.setSetting(OnlineFeature.gemini.settingKey, 'true');
      status = 403;
      await pump(tester);
      await tester.enterText(
          find.byKey(const Key('settings-gemini-key')), 'typed');
      await tap(tester, const Key('settings-gemini-test'));
      expect(find.text('المفتاح مش شغال أو مفيش نت'), findsOneWidget);
      expect(requests.single.headers['x-goog-api-key'], 'typed');
      expect(keys.key, isNull);
    });

    testWidgets('with the switches off, says so and sends nothing',
        (tester) async {
      keys.key = 'saved-key';
      await pump(tester);
      await tap(tester, const Key('settings-gemini-test'));
      expect(find.text('شغّل المزايا الأونلاين وتحسين Gemini الأول'),
          findsOneWidget);
      expect(built, 0);
    });

    testWidgets('with no key, asks for one', (tester) async {
      await pump(tester);
      await tap(tester, const Key('settings-gemini-test'));
      expect(find.text('اكتب المفتاح الأول'), findsOneWidget);
      expect(built, 0);
    });
  });
}
