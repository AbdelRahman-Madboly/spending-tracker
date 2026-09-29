import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/gemini_key_store.dart';
import 'package:spending_tracker/data/gemini_usage_log.dart';
import 'package:spending_tracker/data/net/gemini_client.dart';
import 'package:spending_tracker/data/net/network_gate.dart';
import 'package:spending_tracker/domain/gemini_usage.dart';
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
    expect(find.text('تجربة'), findsOneWidget);
    await tester.enterText(field, 'AI-secret-1');
    await tap(tester, const Key('settings-gemini-key-save'));

    expect(keys.key, 'AI-secret-1');
    expect(find.text('AI-secret-1'), findsNothing);
    expect(find.text('المفتاح محفوظ ••••et-1'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);

    await tap(tester, const Key('settings-gemini-key-clear'));
    expect(keys.key, isNull);
    expect(find.textContaining('المفتاح محفوظ'), findsNothing);
  });

  testWidgets('a key saved earlier shows its last 4 characters only',
      (tester) async {
    keys.key = 'saved-example-9xYz';
    await pump(tester);
    expect(find.text('المفتاح محفوظ ••••9xYz'), findsOneWidget);
    expect(find.textContaining('saved-example'), findsNothing);
  });

  testWidgets('saving a key turns on online features and Gemini',
      (tester) async {
    await pump(tester);
    expect(isOn(tester, master), isFalse);
    await tester.enterText(
        find.byKey(const Key('settings-gemini-key')), 'AI-secret-1');
    await tap(tester, const Key('settings-gemini-key-save'));

    expect(isOn(tester, master), isTrue);
    expect(isOn(tester, feature(OnlineFeature.gemini)), isTrue);
    expect(await isOnlineFeatureOn(repo, OnlineFeature.gemini), isTrue);
    expect(await isOnlineFeatureOn(repo, OnlineFeature.geminiAudio), isFalse);

    // The user can still turn it off again.
    await tap(tester, feature(OnlineFeature.gemini));
    expect(await isOnlineFeatureOn(repo, OnlineFeature.gemini), isFalse);
    expect(keys.key, 'AI-secret-1');
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
    // Saved once typing stops, not on every keystroke.
    await tester.pump(const Duration(seconds: 1));
    expect(await repo.setting(geminiModelSettingKey), 'gemini-3.8-flash');
  });

  testWidgets('a model id that cannot be saved does not throw',
      (tester) async {
    final failing = _FailingModelRepo();
    repo = failing;
    await pump(tester);
    final field = find.byKey(const Key('settings-gemini-model'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'gemini-3.8-flash');
    await tester.pump(const Duration(seconds: 1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(failing.attempts, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  group('the usage card', () {
    Future<void> seed() async {
      final now = DateTime.now();
      final log = GeminiUsageLog(repo);
      await log.record(GeminiUsageEvent(
          at: now,
          model: defaultGeminiModel,
          feature: GeminiUsageFeature.rewrite,
          ok: true,
          promptTokens: 1000000,
          outputTokens: 200000,
          totalTokens: 1200000));
      await log.record(GeminiUsageEvent(
          at: now,
          model: defaultGeminiModel,
          feature: GeminiUsageFeature.photo,
          ok: false,
          error: 'HTTP 429'));
    }

    String textOf(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('shows requests and tokens today and this month, by '
        'feature, the failures and the estimated cost', (tester) async {
      await seed();
      await pump(tester);
      expect(find.text('استخدام Gemini'), findsOneWidget);
      expect(textOf(tester, 'gemini-usage-today'),
          '2 طلب · 1,200,000 توكن');
      expect(textOf(tester, 'gemini-usage-month'),
          '2 طلب · 1,200,000 توكن');
      expect(textOf(tester, 'gemini-usage-feature-rewrite'),
          contains('1 طلب'));
      expect(textOf(tester, 'gemini-usage-feature-photo'), contains('1 طلب'));
      expect(find.byKey(const Key('gemini-usage-feature-audio')), findsNothing);
      expect(textOf(tester, 'gemini-usage-failures'), contains('1'));
      expect(textOf(tester, 'gemini-usage-last-error'), contains('HTTP 429'));
      // $0.30 for 1M in and $2.50 for 1M out, at the default prices.
      expect(textOf(tester, 'gemini-usage-cost'), contains(r'$0.8000'));
      expect(find.textContaining('الخطة المجانية'), findsWidgets);
    });

    testWidgets('the daily limit is a setting with a progress bar',
        (tester) async {
      await seed();
      await pump(tester);
      LinearProgressIndicator bar() => tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('gemini-usage-limit-bar')));
      expect(bar().value, closeTo(2 / defaultGeminiDailyLimit, 1e-9));

      final limit = find.byKey(const Key('gemini-daily-limit'));
      await tester.ensureVisible(limit);
      await tester.enterText(limit, '4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(await repo.setting(geminiDailyLimitSettingKey), '4');
      expect(bar().value, closeTo(0.5, 1e-9));
      expect(textOf(tester, 'gemini-usage-limit'), '2 من 4 طلب النهارده');
    });

    testWidgets('the prices are settings the cost follows', (tester) async {
      await seed();
      await pump(tester);
      final input = find.byKey(const Key('gemini-price-input'));
      await tester.ensureVisible(input);
      await tester.enterText(input, '1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(await repo.setting(geminiInputPriceSettingKey), '1');
      expect(textOf(tester, 'gemini-usage-cost'), contains(r'$1.5000'));

      // A price that is not a number is not saved.
      await tester.enterText(input, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(await repo.setting(geminiInputPriceSettingKey), '1');
    });

    testWidgets('مسح العداد starts the month from nothing', (tester) async {
      await seed();
      await pump(tester);
      await tap(tester, const Key('gemini-usage-reset'));
      await tap(tester, const Key('gemini-usage-reset-confirm'));
      expect(textOf(tester, 'gemini-usage-month'), '0 طلب · 0 توكن');
      final month = await GeminiUsageLog(repo).month(DateTime.now());
      expect(month.total.requests, 0);
    });
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

class _FailingModelRepo extends FixtureSpendingRepository {
  int attempts = 0;

  @override
  Future<void> setSetting(String key, String value) async {
    if (key == geminiModelSettingKey) {
      attempts++;
      throw StateError('disk full');
    }
    return super.setSetting(key, value);
  }
}
