import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/gemini_usage.dart';

GeminiUsageEvent _event(
  DateTime at, {
  GeminiUsageFeature feature = GeminiUsageFeature.rewrite,
  bool ok = true,
  int prompt = 100,
  int total = 150,
  String model = 'gemini-3.5-flash-lite',
  String? error,
}) =>
    GeminiUsageEvent(
      at: at,
      model: model,
      feature: feature,
      ok: ok,
      promptTokens: prompt,
      outputTokens: total - prompt,
      totalTokens: total,
      error: error,
    );

void main() {
  group('the settings key', () {
    test('is one per month', () {
      expect(geminiUsageSettingKey(DateTime(2026, 9, 30, 23, 59)),
          'gemini_usage:2026-09');
      expect(geminiUsageSettingKey(DateTime(2026, 10, 1)),
          'gemini_usage:2026-10');
    });
  });

  group('recording', () {
    test('adds requests and tokens to the month, the day and the feature',
        () {
      final usage = GeminiMonthUsage.empty('2026-09')
          .recorded(_event(DateTime(2026, 9, 22, 9)))
          .recorded(_event(DateTime(2026, 9, 22, 18),
              feature: GeminiUsageFeature.photo, prompt: 1000, total: 1200))
          .recorded(_event(DateTime(2026, 9, 23, 8),
              feature: GeminiUsageFeature.audio, prompt: 400, total: 500));

      expect(usage.total.requests, 3);
      expect(usage.total.promptTokens, 1500);
      expect(usage.total.outputTokens, 350);
      expect(usage.total.totalTokens, 1850);
      expect(usage.day(DateTime(2026, 9, 22)).requests, 2);
      expect(usage.day(DateTime(2026, 9, 22)).totalTokens, 1350);
      expect(usage.day(DateTime(2026, 9, 23)).requests, 1);
      expect(usage.feature(GeminiUsageFeature.photo).totalTokens, 1200);
      expect(usage.feature(GeminiUsageFeature.rewrite).requests, 1);
      expect(usage.models, {'gemini-3.5-flash-lite': 3});
    });

    test('a new day starts from nothing', () {
      final usage = GeminiMonthUsage.empty('2026-09')
          .recorded(_event(DateTime(2026, 9, 22, 23, 59)));
      expect(usage.day(DateTime(2026, 9, 23)).requests, 0);
      expect(usage.day(DateTime(2026, 9, 23)).totalTokens, 0);
      expect(usage.day(DateTime(2026, 9, 22)).requests, 1);
    });

    test('an event of another month is refused, so months never mix', () {
      final september = GeminiMonthUsage.empty('2026-09');
      expect(() => september.recorded(_event(DateTime(2026, 10, 1))),
          throwsArgumentError);
      expect(GeminiMonthUsage.empty('2026-10').day(DateTime(2026, 10, 1)),
          isA<GeminiUsageCounts>());
    });

    test('failures are counted with the last error and when it happened', () {
      final usage = GeminiMonthUsage.empty('2026-09')
          .recorded(_event(DateTime(2026, 9, 22, 9),
              ok: false, prompt: 0, total: 0, error: 'HTTP 429'))
          .recorded(_event(DateTime(2026, 9, 22, 10)))
          .recorded(_event(DateTime(2026, 9, 22, 11),
              ok: false, prompt: 0, total: 0, error: 'timeout'));
      expect(usage.total.requests, 3);
      expect(usage.total.failures, 2);
      expect(usage.day(DateTime(2026, 9, 22)).failures, 2);
      expect(usage.lastError, 'timeout');
      expect(usage.lastErrorAt, DateTime(2026, 9, 22, 11));
    });

    test('survives a trip through JSON', () {
      final usage = GeminiMonthUsage.empty('2026-09')
          .recorded(_event(DateTime(2026, 9, 22, 9),
              feature: GeminiUsageFeature.photo))
          .recorded(_event(DateTime(2026, 9, 22, 10),
              ok: false, prompt: 0, total: 0, error: 'HTTP 500'));
      final back = GeminiMonthUsage.fromJson('2026-09', usage.toJson());
      expect(jsonDecode(back.toJson()), jsonDecode(usage.toJson()));
      expect(back.lastErrorAt, DateTime(2026, 9, 22, 10));
      expect(back.feature(GeminiUsageFeature.photo).requests, 1);
    });

    test('stored JSON never holds more than counts, names and the error', () {
      final json = GeminiMonthUsage.empty('2026-09')
          .recorded(_event(DateTime(2026, 9, 22, 9)))
          .toJson();
      final keys = <String>{};
      void walk(Object? node) {
        if (node is Map) {
          for (final entry in node.entries) {
            keys.add(entry.key as String);
            walk(entry.value);
          }
        }
      }

      walk(jsonDecode(json));
      expect(keys.where((k) => k.contains('text') || k.contains('key')),
          isEmpty);
    });

    test('missing or broken JSON reads as an empty month', () {
      for (final bad in [null, '', 'not json', '[]', '{"total":"x"}']) {
        final usage = GeminiMonthUsage.fromJson('2026-09', bad);
        expect(usage.total.requests, 0, reason: bad);
      }
    });
  });

  group('cost', () {
    test('prices per 1M tokens read without floating point', () {
      expect(parseUsdPrice('0.30'), 3000);
      expect(parseUsdPrice('2.5'), 25000);
      expect(parseUsdPrice('0.0375'), 375);
      expect(parseUsdPrice('1.23456'), isNull);
      expect(parseUsdPrice('-1'), isNull);
      expect(parseUsdPrice('abc'), isNull);
    });

    test('estimates input and output at their own prices', () {
      const counts = GeminiUsageCounts(
          requests: 2,
          promptTokens: 1000000,
          outputTokens: 200000,
          totalTokens: 1200000);
      // $0.30 for 1M in, plus $2.50 x 0.2 for 200k out.
      expect(
          estimateCostMicroUsd(counts,
              inputPrice: parseUsdPrice('0.30')!,
              outputPrice: parseUsdPrice('2.50')!),
          800000);
      expect(formatUsdMicro(800000), r'$0.8000');
      expect(formatUsdMicro(1234), r'$0.0012');
      expect(formatUsdMicro(0), r'$0.0000');
    });
  });
}
