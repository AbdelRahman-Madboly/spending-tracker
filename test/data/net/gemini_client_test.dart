import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/gemini_key_store.dart';
import 'package:spending_tracker/data/net/gemini_client.dart';
import 'package:spending_tracker/data/net/network_gate.dart';
import 'package:spending_tracker/domain/gemini_usage.dart';
import 'package:spending_tracker/domain/online_features.dart';
import 'package:spending_tracker/domain/smart_parse.dart';

class MemoryKeyStore implements GeminiKeyStore {
  MemoryKeyStore([this.key]);

  String? key;
  int reads = 0;

  @override
  Future<String?> read() async {
    reads++;
    return key;
  }

  @override
  Future<void> write(String? value) async => key = value;
}

void main() {
  late FixtureSpendingRepository repo;
  late List<http.Request> requests;
  late int built;
  final day = DateTime(2026, 9, 22);

  setUp(() async {
    repo = FixtureSpendingRepository();
    requests = [];
    built = 0;
  });

  Future<void> turnOn(OnlineFeature feature) async {
    await repo.setSetting(onlineFeaturesSettingKey, 'true');
    await repo.setSetting(feature.settingKey, 'true');
  }

  GeminiClient clientAnswering(
      FutureOr<http.Response> Function(http.Request) answer,
      {GeminiKeyStore? keys,
      Duration timeout = GeminiClient.defaultTimeout}) {
    final gate = NetworkGate(repo, clientFactory: () {
      built++;
      return MockClient((request) async {
        requests.add(request);
        return answer(request);
      });
    });
    return GeminiClient(gate, repo, keys ?? MemoryKeyStore('k-123'),
        timeout: timeout, clock: () => DateTime(2026, 9, 22, 10, 30));
  }

  http.Response answerWith(Object lines,
          {String cleanText = 'عيش ب 10', Map<String, int>? usage}) =>
      http.Response.bytes(
          utf8.encode(jsonEncode({
            'usageMetadata': ?usage,
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({'cleanText': cleanText, 'lines': lines}),
                    },
                  ],
                },
              },
            ],
          })),
          200);

  final bread = {
    'name': 'عيش',
    'quantity': '1',
    'unit': 'bag',
    'amount': '10',
    'categoryKey': 'Food',
  };

  group('available', () {
    test('nothing while switched off, and the key is not even read',
        () async {
      final keys = MemoryKeyStore('k');
      final client = clientAnswering((_) => answerWith([]), keys: keys);
      expect(await client.available(), isEmpty);
      expect(keys.reads, 0);
      expect(built, 0);
    });

    test('text and photos with the smart switch, audio with its own',
        () async {
      await turnOn(OnlineFeature.gemini);
      final client = clientAnswering((_) => answerWith([]));
      expect(await client.available(),
          {SmartInputKind.text, SmartInputKind.photo});
      await repo.setSetting(OnlineFeature.geminiAudio.settingKey, 'true');
      expect(await client.available(), SmartInputKind.values.toSet());
      expect(built, 0);
    });

    test('nothing without a saved key', () async {
      await turnOn(OnlineFeature.gemini);
      final client = clientAnswering((_) => answerWith([]),
          keys: MemoryKeyStore(' '));
      expect(await client.available(), isEmpty);
    });

    test('a key store that fails means nothing is available', () async {
      await turnOn(OnlineFeature.gemini);
      final client = clientAnswering((_) => answerWith([]),
          keys: _ThrowingKeyStore());
      expect(await client.available(), isEmpty);
    });
  });

  group('improve', () {
    test('posts the text with the key header, the model and the JSON schema',
        () async {
      await turnOn(OnlineFeature.gemini);
      await repo.setSetting(geminiModelSettingKey, 'gemini-3.8-flash');
      final client = clientAnswering((_) => answerWith([bread]));
      final result =
          await client.improve(const SmartInput.text('عيش ب ١٠'), day: day);

      expect(result!.lines.single.amountPiastres, 1000);
      expect(result.cleanText, 'عيش ب 10');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-3.8-flash:generateContent');
      expect(request.headers['x-goog-api-key'], 'k-123');
      expect(request.url.queryParameters, isEmpty,
          reason: 'the key never goes in the URL');
      final body = jsonDecode(request.body) as Map;
      final config = body['generationConfig'] as Map;
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseJsonSchema'], isA<Map>());
      final parts = (body['contents'] as List).single['parts'] as List;
      expect(parts.map((p) => p['text']).join('\n'), contains('عيش ب ١٠'));
    });

    test('uses the default model when none is set', () async {
      await turnOn(OnlineFeature.gemini);
      final client = clientAnswering((_) => answerWith([bread]));
      await client.improve(const SmartInput.text('عيش'), day: day);
      expect(requests.single.url.path,
          '/v1beta/models/$defaultGeminiModel:generateContent');
      expect(defaultGeminiModel, 'gemini-3.5-flash-lite');
    });

    test('photos go as inline JPEG data', () async {
      await turnOn(OnlineFeature.gemini);
      final client = clientAnswering((_) => answerWith([bread]));
      final jpeg = Uint8List.fromList([1, 2, 3]);
      await client.improve(SmartInput.photos([jpeg, jpeg]), day: day);
      final parts = (jsonDecode(requests.single.body)['contents'] as List)
          .single['parts'] as List;
      final inline = [
        for (final p in parts)
          if (p['inline_data'] != null) p['inline_data'],
      ];
      expect(inline, hasLength(2));
      expect(inline.first['mime_type'], 'image/jpeg');
      expect(inline.first['data'], base64Encode(jpeg));
    });

    test('audio goes as inline m4a, only with the audio switch', () async {
      await turnOn(OnlineFeature.gemini);
      final client = clientAnswering((_) => answerWith([bread]));
      final audio = SmartInput.audio(Uint8List.fromList([9, 9]));
      expect(await client.improve(audio, day: day), isNull);
      expect(built, 0);

      await repo.setSetting(OnlineFeature.geminiAudio.settingKey, 'true');
      expect(await client.improve(audio, day: day), isNotNull);
      final parts = (jsonDecode(requests.single.body)['contents'] as List)
          .single['parts'] as List;
      final inline =
          parts.firstWhere((p) => p['inline_data'] != null)['inline_data'];
      expect(inline['mime_type'], 'audio/m4a');
    });

    test('every failure gives null', () async {
      await turnOn(OnlineFeature.gemini);
      final failures = <FutureOr<http.Response> Function(http.Request)>[
        (_) => http.Response('{"error":{}}', 400),
        (_) => http.Response('oops', 503),
        (_) => http.Response('not json', 200),
        (_) => http.Response('{"candidates":[]}', 200),
        (_) => answerWith([
              {...bread, 'categoryKey': 'Cars'},
            ]),
        (_) => throw http.ClientException('offline'),
      ];
      for (final (i, answer) in failures.indexed) {
        final client = clientAnswering(answer);
        expect(await client.improve(const SmartInput.text('عيش'), day: day),
            isNull,
            reason: 'failure $i');
      }
    });

    test('a request past the timeout gives null', () async {
      await turnOn(OnlineFeature.gemini);
      final client = clientAnswering(
          (_) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 50));
      expect(await client.improve(const SmartInput.text('عيش'), day: day),
          isNull);
    });

    test('switched off or with no key, nothing is sent', () async {
      final off = clientAnswering((_) => answerWith([bread]));
      expect(await off.improve(const SmartInput.text('عيش'), day: day),
          isNull);
      await turnOn(OnlineFeature.gemini);
      final keyless = clientAnswering((_) => answerWith([bread]),
          keys: MemoryKeyStore());
      expect(await keyless.improve(const SmartInput.text('عيش'), day: day),
          isNull);
      expect(built, 0);
    });
  });

  group('usage', () {
    Future<GeminiMonthUsage> september() async => GeminiMonthUsage.fromJson(
        '2026-09', await repo.setting('gemini_usage:2026-09'));

    test('a request records its tokens, model and feature', () async {
      await turnOn(OnlineFeature.gemini);
      await repo.setSetting(geminiModelSettingKey, 'gemini-3.8-flash');
      final client = clientAnswering((_) => answerWith([bread], usage: {
            'promptTokenCount': 1200,
            'candidatesTokenCount': 80,
            'thoughtsTokenCount': 20,
            'totalTokenCount': 1300,
          }));
      await client.improve(const SmartInput.text('عيش ب ١٠'), day: day);
      await client.improve(SmartInput.photos([Uint8List(3)]), day: day);

      final usage = await september();
      expect(usage.total.requests, 2);
      expect(usage.total.failures, 0);
      expect(usage.total.promptTokens, 2400);
      expect(usage.total.outputTokens, 200,
          reason: 'thinking tokens are billed as output');
      expect(usage.total.totalTokens, 2600);
      expect(usage.feature(GeminiUsageFeature.rewrite).requests, 1);
      expect(usage.feature(GeminiUsageFeature.photo).requests, 1);
      expect(usage.models, {'gemini-3.8-flash': 2});
      expect(usage.day(DateTime(2026, 9, 22)).requests, 2);
    });

    test('a voice note counts as audio', () async {
      await turnOn(OnlineFeature.gemini);
      await repo.setSetting(OnlineFeature.geminiAudio.settingKey, 'true');
      final client = clientAnswering((_) => answerWith([bread]));
      await client.improve(SmartInput.audio(Uint8List(2)), day: day);
      expect(
          (await september()).feature(GeminiUsageFeature.audio).requests, 1);
    });

    test('failures are counted with a short error', () async {
      await turnOn(OnlineFeature.gemini);
      await clientAnswering((_) => http.Response('{"error":{}}', 429))
          .improve(const SmartInput.text('عيش'), day: day);
      expect((await september()).lastError, 'HTTP 429');
      await clientAnswering((_) => http.Response('not json', 200))
          .improve(const SmartInput.text('عيش'), day: day);
      expect((await september()).lastError, 'bad answer');
      await clientAnswering((_) => throw http.ClientException('offline'))
          .improve(const SmartInput.text('عيش'), day: day);
      expect((await september()).lastError, 'no connection');
      await clientAnswering((_) => Completer<http.Response>().future,
              timeout: const Duration(milliseconds: 50))
          .improve(const SmartInput.text('عيش'), day: day);

      final usage = await september();
      expect(usage.total.requests, 4);
      expect(usage.total.failures, 4);
      expect(usage.lastError, 'timeout');
      expect(usage.lastErrorAt, DateTime(2026, 9, 22, 10, 30));
    });

    test('nothing is recorded when nothing is sent', () async {
      await clientAnswering((_) => answerWith([bread]))
          .improve(const SmartInput.text('عيش'), day: day);
      expect(await repo.setting('gemini_usage:2026-09'), isNull);
    });

    test('the counters never hold the note, the answer or the key',
        () async {
      await turnOn(OnlineFeature.gemini);
      await clientAnswering((_) => answerWith([bread]))
          .improve(const SmartInput.text('طماطم سرية'), day: day);
      final stored = (await repo.setting('gemini_usage:2026-09'))!;
      expect(stored, isNot(contains('طماطم')));
      expect(stored, isNot(contains('عيش')));
      expect(stored, isNot(contains('k-123')));
    });

    test('a counter that cannot be written does not fail the request',
        () async {
      repo = _NoUsageRepo();
      await turnOn(OnlineFeature.gemini);
      final result = await clientAnswering((_) => answerWith([bread]))
          .improve(const SmartInput.text('عيش'), day: day);
      expect(result, isNotNull);
    });
  });

  group('check', () {
    test('asks for the model with the key given and says whether it works',
        () async {
      await turnOn(OnlineFeature.gemini);
      final ok = clientAnswering((_) => http.Response('{}', 200));
      expect(await ok.check(key: 'typed-key', model: 'gemini-3.8-flash'),
          GeminiCheck.works);
      expect(requests.single.headers['x-goog-api-key'], 'typed-key');
      expect(requests.single.url.path, '/v1beta/models/gemini-3.8-flash');

      final bad = clientAnswering((_) => http.Response('{}', 403));
      expect(await bad.check(key: 'wrong', model: defaultGeminiModel),
          GeminiCheck.fails);
    });

    test('switched off, it says so without sending anything', () async {
      final client = clientAnswering((_) => http.Response('{}', 200));
      expect(await client.check(key: 'k', model: defaultGeminiModel),
          GeminiCheck.switchedOff);
      expect(built, 0);
    });

    test('a model id that is not a plain name is never put in a URL',
        () async {
      await turnOn(OnlineFeature.gemini);
      final client = clientAnswering((_) => http.Response('{}', 200));
      expect(await client.check(key: 'k', model: '../../x?y'),
          GeminiCheck.fails);
      expect(built, 0);
    });
  });
}

class _ThrowingKeyStore implements GeminiKeyStore {
  @override
  Future<String?> read() => throw StateError('keystore unavailable');

  @override
  Future<void> write(String? value) => throw StateError('keystore unavailable');
}

class _NoUsageRepo extends FixtureSpendingRepository {
  @override
  Future<void> setSetting(String key, String value) async {
    if (key.startsWith('gemini_usage:')) throw StateError('disk full');
    return super.setSetting(key, value);
  }
}
