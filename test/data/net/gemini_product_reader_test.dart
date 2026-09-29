import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/gemini_usage_log.dart';
import 'package:spending_tracker/data/net/gemini_client.dart';
import 'package:spending_tracker/data/net/gemini_product_reader.dart';
import 'package:spending_tracker/data/net/network_gate.dart';
import 'package:spending_tracker/domain/gemini_usage.dart';
import 'package:spending_tracker/domain/online_features.dart';

import 'gemini_client_test.dart' show MemoryKeyStore;

void main() {
  late FixtureSpendingRepository repo;
  late List<http.Request> requests;
  late int built;

  setUp(() {
    repo = FixtureSpendingRepository();
    requests = [];
    built = 0;
  });

  Future<void> turnOn(Iterable<OnlineFeature> features) async {
    await repo.setSetting(onlineFeaturesSettingKey, 'true');
    for (final f in features) {
      await repo.setSetting(f.settingKey, 'true');
    }
  }

  GeminiProductReader readerAnswering(
      FutureOr<http.Response> Function(http.Request) answer) {
    final gate = NetworkGate(repo, clientFactory: () {
      built++;
      return MockClient((request) async {
        requests.add(request);
        return answer(request);
      });
    });
    return GeminiProductReader(GeminiClient(gate, repo, MemoryKeyStore('k-1'),
        clock: () => DateTime(2026, 9, 29, 10)));
  }

  http.Response answerText(String text) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'usageMetadata': {'promptTokenCount': 300, 'totalTokenCount': 420},
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text},
              ],
            },
          },
        ],
      })),
      200);

  group('search', () {
    test('asks Gemini with Google Search grounding and reads the JSON in '
        'its prose', () async {
      await turnOn([OnlineFeature.gemini, OnlineFeature.productWebSearch]);
      final reader = readerAnswering((_) => answerText(
          'Found it on Carrefour.\n```json\n{"found": true, '
          '"nameAr": "نوتيلا", "nameEn": "Nutella", "brand": "Ferrero", '
          '"size": "400 g", "priceEgp": "210", "priceSource": "Carrefour"}'
          '\n```'));

      final info = await reader.search('3017620422003');

      expect(info!.nameAr, 'نوتيلا');
      expect(info.pricePiastres, 21000);
      expect(info.priceSource, 'Carrefour');
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['tools'], [
        {'google_search': {}}
      ]);
      expect(jsonEncode(body['contents']), contains('3017620422003'));
      expect(jsonEncode(body['contents']), contains('Egypt'));
      expect(requests.single.headers['x-goog-api-key'], 'k-1');
    });

    test('is counted in the Gemini usage under products', () async {
      await turnOn([OnlineFeature.gemini, OnlineFeature.productWebSearch]);
      final reader =
          readerAnswering((_) => answerText('{"nameEn": "Nutella"}'));
      await reader.search('3017620422003');
      final month = await GeminiUsageLog(repo).month(DateTime(2026, 9, 29));
      expect(month.feature(GeminiUsageFeature.product).requests, 1);
      expect(month.total.totalTokens, 420);
    });

    test('an answer with no product, or a failure, is null', () async {
      await turnOn([OnlineFeature.gemini, OnlineFeature.productWebSearch]);
      expect(
          await readerAnswering((_) => answerText('No product found.'))
              .search('3017620422003'),
          isNull);
      expect(
          await readerAnswering((_) => http.Response('down', 503))
              .search('3017620422003'),
          isNull);
      final month = await GeminiUsageLog(repo).month(DateTime(2026, 9, 29));
      expect(month.feature(GeminiUsageFeature.product).failures, 2);
    });

    test('with its own switch off nothing is sent, Gemini on or not',
        () async {
      await turnOn([OnlineFeature.gemini]);
      final reader = readerAnswering((_) => answerText('{"nameEn": "x"}'));
      expect(await reader.canSearch(), isFalse);
      expect(await reader.search('3017620422003'), isNull);
      expect(built, 0);
    });

    test('with Gemini itself off nothing is sent either', () async {
      await turnOn([OnlineFeature.productWebSearch]);
      final reader = readerAnswering((_) => answerText('{"nameEn": "x"}'));
      expect(await reader.canSearch(), isFalse);
      expect(await reader.search('3017620422003'), isNull);
      expect(built, 0);
    });

    test('a code that is not a product number is never sent', () async {
      await turnOn([OnlineFeature.gemini, OnlineFeature.productWebSearch]);
      final reader = readerAnswering((_) => answerText('{"nameEn": "x"}'));
      expect(await reader.search('https://example.org/?q=1'), isNull);
      expect(built, 0);
    });
  });

  group('readPhoto', () {
    test('sends the photo to Gemini vision and reads the product', () async {
      await turnOn([OnlineFeature.gemini]);
      final reader = readerAnswering((_) => answerText(
          '{"nameAr": "جبنة دومتي", "nameEn": "Domty Cheese", '
          '"brand": "Domty", "size": "250 g"}'));
      final info = await reader.readPhoto(Uint8List.fromList([1, 2, 3]));
      expect(info!.nameAr, 'جبنة دومتي');
      expect(info.size, '250 g');
      final body = jsonDecode(requests.single.body) as Map;
      expect(jsonEncode(body['contents']), contains('inline_data'));
      expect(body.containsKey('tools'), isFalse);
    });

    test('with Gemini off nothing is sent', () async {
      final reader = readerAnswering((_) => answerText('{"nameEn": "x"}'));
      expect(await reader.canReadPhoto(), isFalse);
      expect(await reader.readPhoto(Uint8List.fromList([1])), isNull);
      expect(built, 0);
    });
  });

  test('the gate refuses the web search while its switch is off', () async {
    await turnOn([OnlineFeature.gemini]);
    final gate = NetworkGate(repo,
        clientFactory: () => throw StateError('no client may be built'));
    await expectLater(
        gate.post(OnlineFeature.productWebSearch,
            Uri.https(GeminiClient.host, '/x'),
            body: '{}'),
        throwsA(isA<NetworkDisabled>()));
  });
}
