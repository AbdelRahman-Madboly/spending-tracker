import 'dart:async';
import 'dart:convert';

import '../../domain/gemini_usage.dart';
import '../../domain/online_features.dart';
import '../../domain/smart_parse.dart';
import '../../domain/spending_repository.dart';
import '../gemini_key_store.dart';
import '../gemini_usage_log.dart';
import 'network_gate.dart';

/// The `app_settings` key of the Gemini model id (spec §4.6). A setting,
/// not a constant, so a newer or stronger model needs no release.
const geminiModelSettingKey = 'gemini_model';
const defaultGeminiModel = 'gemini-3.5-flash-lite';

/// What the key test in Settings found.
enum GeminiCheck { works, fails, switchedOff }

/// Gemini's `generateContent` (spec §6.6), through [NetworkGate] as
/// [OnlineFeature.gemini], or [OnlineFeature.geminiAudio] for a voice
/// note.
///
/// Every failure gives null rather than an error: the local result is
/// already on screen and stays there. That covers the switch being off, no
/// key, no connection, the 20-second timeout, a 4xx or 5xx, and an answer
/// that does not match the schema.
///
/// Every request that is actually sent is counted in [GeminiUsageLog]:
/// its tokens from `usageMetadata`, the model, the feature and whether it
/// worked. Nothing that was sent or received goes into the counters.
class GeminiClient implements SmartImprover {
  GeminiClient(this._gate, this._repository, this._keys,
      {this.timeout = defaultTimeout, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _usage = GeminiUsageLog(_repository);

  final NetworkGate _gate;
  final SpendingRepository _repository;
  final GeminiKeyStore _keys;
  final DateTime Function() _clock;
  final GeminiUsageLog _usage;

  /// How long a request may take; tests shorten it.
  final Duration timeout;

  static const host = 'generativelanguage.googleapis.com';

  /// Spec §6.6: a smart request may take 20 seconds, the body included.
  static const defaultTimeout = Duration(seconds: 20);

  /// A model id goes into the request path, so only a plain name is used.
  static final _modelId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  static GeminiUsageFeature _usageFeatureFor(SmartInputKind kind) =>
      switch (kind) {
        SmartInputKind.text => GeminiUsageFeature.rewrite,
        SmartInputKind.photo => GeminiUsageFeature.photo,
        SmartInputKind.audio => GeminiUsageFeature.audio,
      };

  static OnlineFeature _featureFor(SmartInputKind kind) =>
      kind == SmartInputKind.audio
          ? OnlineFeature.geminiAudio
          : OnlineFeature.gemini;

  @override
  Future<Set<SmartInputKind>> available() async {
    try {
      final kinds = {
        for (final kind in SmartInputKind.values)
          if (await isOnlineFeatureOn(_repository, _featureFor(kind))) kind,
      };
      // The key is read only once a switch is on: with online features off
      // nothing, secure storage included, is touched.
      if (kinds.isEmpty || await _key() == null) return const {};
      return kinds;
    } catch (_) {
      return const {};
    }
  }

  /// The repository the switches and the usage counters live in.
  SpendingRepository get repository => _repository;

  /// Whether a key is saved. Reads secure storage, so callers check the
  /// switches first.
  Future<bool> hasKey() async {
    try {
      return await _key() != null;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _key() async {
    final key = (await _keys.read())?.trim() ?? '';
    return key.isEmpty ? null : key;
  }

  Future<String> _model() async {
    final model = (await _repository.setting(geminiModelSettingKey))?.trim();
    return model == null || model.isEmpty ? defaultGeminiModel : model;
  }

  @override
  Future<SmartResult?> improve(SmartInput input,
      {required DateTime day}) async {
    try {
      final feature = _featureFor(input.kind);
      if (!await isOnlineFeatureOn(_repository, feature)) return null;
      final catalogue = await loadSmartCatalogue(_repository);
      return await generate(
        feature: feature,
        usage: _usageFeatureFor(input.kind),
        parts: [
          {'text': smartPrompt(catalogue, input.kind)},
          ..._partsOf(input),
        ],
        generationConfig: {
          'responseMimeType': 'application/json',
          'responseJsonSchema': smartResponseSchema(catalogue),
        },
        read: (answer) => readSmartResult(answer, catalogue, day: day),
      );
    } catch (_) {
      return null;
    }
  }

  /// Sends one `generateContent` request for [feature] with [parts] as the
  /// user's turn, and gives what [read] makes of the answer's text.
  ///
  /// Null when the switch is off, there is no key, the request fails or
  /// [read] gives null. Every request actually sent is counted under
  /// [usage], as worked only when [read] gave something.
  Future<T?> generate<T>({
    required OnlineFeature feature,
    required GeminiUsageFeature usage,
    required List<Map<String, Object?>> parts,
    Map<String, Object?>? generationConfig,
    List<Map<String, Object?>>? tools,
    required T? Function(String answer) read,
  }) async {
    try {
      if (!await isOnlineFeatureOn(_repository, feature)) return null;
      final key = await _key();
      final model = await _model();
      if (key == null || !_modelId.hasMatch(model)) return null;
      Future<void> count({bool ok = false, String? error, Object? body}) =>
          _usage.record(_eventOf(
              model: model,
              feature: usage,
              ok: ok,
              error: error,
              body: body));
      final GateResponse response;
      try {
        response = await _gate.post(
          feature,
          Uri.https(host, '/v1beta/models/$model:generateContent'),
          headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {'role': 'user', 'parts': parts},
            ],
            'tools': ?tools,
            'generationConfig': ?generationConfig,
          }),
          timeout: timeout,
        );
      } on NetworkDisabled {
        // Refused before anything was sent: nothing to count.
        return null;
      } on TimeoutException {
        await count(error: 'timeout');
        return null;
      } catch (_) {
        await count(error: 'no connection');
        return null;
      }
      if (response.statusCode != 200) {
        await count(error: 'HTTP ${response.statusCode}');
        return null;
      }
      Object? body;
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        body = null;
      }
      final answer = _answerText(body);
      T? result;
      try {
        result = answer == null ? null : read(answer);
      } catch (_) {
        result = null;
      }
      await count(
          ok: result != null,
          error: result == null ? 'bad answer' : null,
          body: body);
      return result;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, Object?>> _partsOf(SmartInput input) =>
      switch (input.kind) {
        SmartInputKind.text => [
            {'text': 'Input:\n${input.text}'},
          ],
        SmartInputKind.photo => [
            for (final image in input.images)
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Encode(image),
                },
              },
          ],
        SmartInputKind.audio => [
            {
              'inline_data': {
                'mime_type': 'audio/m4a',
                'data': base64Encode(input.audio!),
              },
            },
          ],
      };

  /// The usage event of one sent request. The tokens come from the
  /// response's `usageMetadata` when there is one; output is everything
  /// past the prompt, so thinking tokens count as the output they are
  /// billed as.
  GeminiUsageEvent _eventOf({
    required String model,
    required GeminiUsageFeature feature,
    required bool ok,
    String? error,
    Object? body,
  }) {
    final meta = body is Map ? body['usageMetadata'] : null;
    int count(String name) => switch (meta is Map ? meta[name] : null) {
          final int n when n >= 0 => n,
          _ => 0,
        };
    final prompt = count('promptTokenCount');
    var total = count('totalTokenCount');
    if (total < prompt) total = prompt + count('candidatesTokenCount');
    return GeminiUsageEvent(
      at: _clock(),
      model: model,
      feature: feature,
      ok: ok,
      promptTokens: prompt,
      outputTokens: total - prompt,
      totalTokens: total,
      error: error,
    );
  }

  /// The text of the first candidate's parts, which with a JSON response
  /// type is the JSON answer itself.
  static String? _answerText(Object? decoded) {
    if (decoded is! Map || decoded['candidates'] is! List) return null;
    final candidates = decoded['candidates'] as List;
    if (candidates.isEmpty || candidates.first is! Map) return null;
    final content = (candidates.first as Map)['content'];
    if (content is! Map || content['parts'] is! List) return null;
    final text = [
      for (final part in content['parts'] as List)
        if (part is Map && part['text'] is String) part['text'] as String,
    ].join();
    return text.isEmpty ? null : text;
  }

  /// The Settings test button: whether [key] can reach [model]. It reads
  /// the model's description, which costs no tokens, and goes through the
  /// gate like everything else, so it too needs the switches on.
  Future<GeminiCheck> check(
      {required String key, required String model}) async {
    if (!await isOnlineFeatureOn(_repository, OnlineFeature.gemini)) {
      return GeminiCheck.switchedOff;
    }
    final id = model.trim().isEmpty ? defaultGeminiModel : model.trim();
    if (key.trim().isEmpty || !_modelId.hasMatch(id)) return GeminiCheck.fails;
    try {
      final response = await _gate.get(
        OnlineFeature.gemini,
        Uri.https(host, '/v1beta/models/$id'),
        headers: {'x-goog-api-key': key.trim()},
        timeout: timeout,
      );
      return response.statusCode == 200
          ? GeminiCheck.works
          : GeminiCheck.fails;
    } catch (_) {
      return GeminiCheck.fails;
    }
  }
}
