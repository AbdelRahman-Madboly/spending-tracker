import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/net/network_gate.dart';
import 'package:spending_tracker/domain/online_features.dart';

void main() {
  late FixtureSpendingRepository repo;
  late int built;

  setUp(() {
    repo = FixtureSpendingRepository();
    built = 0;
  });

  NetworkGate gateWith(http.Client Function() client,
          {Duration timeout = const Duration(seconds: 5)}) =>
      NetworkGate(repo, clientFactory: () {
        built++;
        return client();
      }, timeout: timeout);

  Future<void> turnOn(OnlineFeature feature) async {
    await repo.setSetting(onlineFeaturesSettingKey, 'true');
    await repo.setSetting(feature.settingKey, 'true');
  }

  final uri = Uri.parse('https://example.org/x');

  test('with every switch off, send is refused before any client is built',
      () async {
    final gate = gateWith(() => throw StateError('no client may be built'));
    for (final feature in OnlineFeature.values) {
      await expectLater(gate.send(feature, http.Request('GET', uri)),
          throwsA(isA<NetworkDisabled>()));
    }
    expect(built, 0);
  });

  test('the master switch without the feature switch is refused', () async {
    await repo.setSetting(onlineFeaturesSettingKey, 'true');
    await repo.setSetting(OnlineFeature.gemini.settingKey, 'true');
    final gate = gateWith(() => throw StateError('no client may be built'));
    await expectLater(
        gate.get(OnlineFeature.productLookup, uri),
        throwsA(isA<NetworkDisabled>()
            .having((e) => e.feature, 'feature', OnlineFeature.productLookup)));
    expect(built, 0);
  });

  test('a feature switched on goes through, with the headers given',
      () async {
    await turnOn(OnlineFeature.productLookup);
    http.BaseRequest? seen;
    final gate = gateWith(() => MockClient((request) async {
          seen = request;
          return http.Response.bytes(utf8.encode('{"name":"بيبسي"}'), 200,
              headers: {'content-type': 'application/json'});
        }));
    final response = await gate.get(OnlineFeature.productLookup, uri,
        headers: {'User-Agent': 'Masarifi/3.0 (personal Android app)'});
    expect(response.statusCode, 200);
    // The body is read as UTF-8 whatever the content type says.
    expect(response.body, '{"name":"بيبسي"}');
    expect(seen!.url, uri);
    expect(seen!.headers['User-Agent'], 'Masarifi/3.0 (personal Android app)');
    expect(built, 1);
  });

  test('a POST carries its body as UTF-8 and is refused when switched off',
      () async {
    final refused = gateWith(() => throw StateError('no client may be built'));
    await expectLater(refused.post(OnlineFeature.gemini, uri, body: '{}'),
        throwsA(isA<NetworkDisabled>()));
    expect(built, 0);

    await turnOn(OnlineFeature.gemini);
    http.Request? seen;
    final gate = gateWith(() => MockClient((request) async {
          seen = request;
          return http.Response.bytes(utf8.encode('{"ok":"تمام"}'), 200);
        }));
    final response = await gate.post(OnlineFeature.gemini, uri,
        headers: {'content-type': 'application/json'},
        body: '{"text":"عيش"}');
    expect(response.statusCode, 200);
    expect(response.body, '{"ok":"تمام"}');
    expect(seen!.method, 'POST');
    expect(utf8.decode(seen!.bodyBytes), '{"text":"عيش"}');
    expect(seen!.headers['content-type'], startsWith('application/json'));
  });

  test('a request that takes too long times out', () async {
    await turnOn(OnlineFeature.productLookup);
    final gate = gateWith(
        () => MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 50));
    await expectLater(gate.get(OnlineFeature.productLookup, uri),
        throwsA(isA<TimeoutException>()));
  });
}
