import 'dart:convert';

/// What a Gemini request was for, as the usage counters break it down.
enum GeminiUsageFeature {
  rewrite('تحسين نص'),
  photo('صور'),
  audio('صوت');

  const GeminiUsageFeature(this.labelAr);

  final String labelAr;
}

/// One Gemini request as the usage counters see it: when, which model,
/// what for, whether it worked and the tokens `usageMetadata` reported.
///
/// Deliberately nothing else. The prompt, the note, the photos, the audio
/// and the key never reach the counters, and [error] is a short code the
/// client makes up ("HTTP 429", "timeout"), never a server message that
/// could echo the request back.
class GeminiUsageEvent {
  final DateTime at;
  final String model;
  final GeminiUsageFeature feature;
  final bool ok;
  final int promptTokens;

  /// Everything billed as output: the answer and any thinking tokens,
  /// that is `totalTokenCount - promptTokenCount`.
  final int outputTokens;
  final int totalTokens;
  final String? error;

  const GeminiUsageEvent({
    required this.at,
    required this.model,
    required this.feature,
    required this.ok,
    this.promptTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.error,
  });
}

/// Requests, failures and tokens over some span: a month, a day or one
/// feature's share of a month.
class GeminiUsageCounts {
  final int requests;
  final int failures;
  final int promptTokens;
  final int outputTokens;
  final int totalTokens;

  const GeminiUsageCounts({
    this.requests = 0,
    this.failures = 0,
    this.promptTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
  });

  static const zero = GeminiUsageCounts();

  GeminiUsageCounts plus(GeminiUsageEvent event) => GeminiUsageCounts(
    requests: requests + 1,
    failures: failures + (event.ok ? 0 : 1),
    promptTokens: promptTokens + event.promptTokens,
    outputTokens: outputTokens + event.outputTokens,
    totalTokens: totalTokens + event.totalTokens,
  );

  Map<String, int> toJson() => {
    'requests': requests,
    'failures': failures,
    'promptTokens': promptTokens,
    'outputTokens': outputTokens,
    'totalTokens': totalTokens,
  };

  /// Reads what [toJson] wrote; anything else reads as [zero].
  static GeminiUsageCounts read(Object? json) {
    if (json is! Map) return zero;
    int count(String name) => switch (json[name]) {
      final int n when n >= 0 => n,
      _ => 0,
    };
    return GeminiUsageCounts(
      requests: count('requests'),
      failures: count('failures'),
      promptTokens: count('promptTokens'),
      outputTokens: count('outputTokens'),
      totalTokens: count('totalTokens'),
    );
  }
}

/// The `app_settings` key of [at]'s month of Gemini usage. One JSON row a
/// month, so the counters need no table and a new month starts from
/// nothing on its own.
String geminiUsageSettingKey(DateTime at) => 'gemini_usage:${_month(at)}';

String _month(DateTime at) =>
    '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}';

/// One month of Gemini usage: the month's totals, a breakdown by feature
/// and by model, a small per-day breakdown, and the last failure.
///
/// Immutable: [recorded] gives the month with one more request in it.
class GeminiMonthUsage {
  /// `yyyy-MM`.
  final String month;
  final GeminiUsageCounts total;
  final Map<GeminiUsageFeature, GeminiUsageCounts> features;

  /// Requests per model id.
  final Map<String, int> models;

  /// Keyed by day of the month.
  final Map<int, GeminiUsageCounts> days;
  final String? lastError;
  final DateTime? lastErrorAt;

  const GeminiMonthUsage._({
    required this.month,
    required this.total,
    required this.features,
    required this.models,
    required this.days,
    this.lastError,
    this.lastErrorAt,
  });

  factory GeminiMonthUsage.empty(String month) => GeminiMonthUsage._(
    month: month,
    total: GeminiUsageCounts.zero,
    features: const {},
    models: const {},
    days: const {},
  );

  /// Reads a month stored by [toJson]. A missing row or one that is not
  /// what [toJson] writes reads as an empty month rather than an error:
  /// the counters are a convenience and must never stop the screen.
  factory GeminiMonthUsage.fromJson(String month, String? json) {
    Object? body;
    try {
      body = json == null || json.isEmpty ? null : jsonDecode(json);
    } on FormatException {
      body = null;
    }
    if (body is! Map) return GeminiMonthUsage.empty(month);
    final features = body['features'];
    final models = body['models'];
    final days = body['days'];
    final lastError = body['lastError'];
    final lastErrorAt = body['lastErrorAt'];
    return GeminiMonthUsage._(
      month: month,
      total: GeminiUsageCounts.read(body['total']),
      features: {
        if (features is Map)
          for (final f in GeminiUsageFeature.values)
            if (features[f.name] != null)
              f: GeminiUsageCounts.read(features[f.name]),
      },
      models: {
        if (models is Map)
          for (final MapEntry(:key, :value) in models.entries)
            if (key is String && value is int) key: value,
      },
      days: {
        if (days is Map)
          for (final MapEntry(:key, :value) in days.entries)
            if (key is String && int.tryParse(key) != null)
              int.parse(key): GeminiUsageCounts.read(value),
      },
      lastError: lastError is String ? lastError : null,
      lastErrorAt: lastErrorAt is String
          ? DateTime.tryParse(lastErrorAt)
          : null,
    );
  }

  /// This month with [event] added. An event of another month is refused:
  /// it belongs in that month's own row.
  GeminiMonthUsage recorded(GeminiUsageEvent event) {
    if (_month(event.at) != month) {
      throw ArgumentError.value(event.at, 'event', 'not in $month');
    }
    final day = event.at.day;
    return GeminiMonthUsage._(
      month: month,
      total: total.plus(event),
      features: {
        ...features,
        event.feature: feature(event.feature).plus(event),
      },
      models: {...models, event.model: (models[event.model] ?? 0) + 1},
      days: {...days, day: (days[day] ?? GeminiUsageCounts.zero).plus(event)},
      lastError: event.ok ? lastError : event.error ?? 'error',
      lastErrorAt: event.ok ? lastErrorAt : event.at,
    );
  }

  /// [at]'s day of this month; nothing for a day with no requests.
  GeminiUsageCounts day(DateTime at) => _month(at) == month
      ? days[at.day] ?? GeminiUsageCounts.zero
      : GeminiUsageCounts.zero;

  GeminiUsageCounts feature(GeminiUsageFeature feature) =>
      features[feature] ?? GeminiUsageCounts.zero;

  String toJson() => jsonEncode({
    'total': total.toJson(),
    'features': {
      for (final MapEntry(:key, :value) in features.entries)
        key.name: value.toJson(),
    },
    'models': models,
    'days': {
      for (final MapEntry(:key, :value) in days.entries) '$key': value.toJson(),
    },
    if (lastError != null) 'lastError': lastError,
    if (lastErrorAt != null) 'lastErrorAt': lastErrorAt!.toIso8601String(),
  });
}

/// The `app_settings` keys of the paid-tier prices, in US dollars per 1M
/// tokens, and of the free tier's daily request limit.
const geminiInputPriceSettingKey = 'gemini_price_input';
const geminiOutputPriceSettingKey = 'gemini_price_output';
const geminiDailyLimitSettingKey = 'gemini_daily_limit';

/// The paid-tier prices of `gemini-3.5-flash-lite` (research notes, §e).
const defaultGeminiInputPrice = '0.30';
const defaultGeminiOutputPrice = '2.50';

/// Google shows the free tier's real limit only in AI Studio, so this is
/// a starting point the user corrects there.
const defaultGeminiDailyLimit = 1000;

/// A price in US dollars per 1M tokens, in units of $0.0001, read digit by
/// digit like money (never through a double). Null for anything but a
/// non-negative decimal with at most 4 places.
int? parseUsdPrice(String input) {
  final match = RegExp(r'^(\d{1,6})(?:\.(\d{1,4}))?$').firstMatch(input.trim());
  if (match == null) return null;
  final fraction = (match[2] ?? '').padRight(4, '0');
  return int.parse(match[1]!) * 10000 + int.parse(fraction);
}

/// The paid-tier cost of [counts] in millionths of a dollar: prompt tokens
/// at [inputPrice] and output tokens at [outputPrice], both from
/// [parseUsdPrice]. tokens x (price / 10^4 dollars) / 10^6 is
/// tokens x price / 10^4 millionths.
int estimateCostMicroUsd(
  GeminiUsageCounts counts, {
  required int inputPrice,
  required int outputPrice,
}) =>
    (counts.promptTokens * inputPrice + counts.outputTokens * outputPrice) ~/
    10000;

/// A cost from [estimateCostMicroUsd] as dollars to 4 places, like
/// `$0.0012`.
String formatUsdMicro(int micro) {
  final tenThousandths = micro ~/ 100;
  final dollars = tenThousandths ~/ 10000;
  final fraction = (tenThousandths % 10000).toString().padLeft(4, '0');
  return '\$$dollars.$fraction';
}
