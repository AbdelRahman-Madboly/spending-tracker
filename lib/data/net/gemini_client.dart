import 'dart:convert';

import '../../domain/online_features.dart';
import '../../domain/smart_parse.dart';
import '../../domain/spending_repository.dart';
import '../gemini_key_store.dart';
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
class GeminiClient implements SmartImprover {
  GeminiClient(this._gate, this._repository, this._keys,
      {this.timeout = defaultTimeout});

  final NetworkGate _gate;
  final SpendingRepository _repository;
  final GeminiKeyStore _keys;
  /// How long a request may take; tests shorten it.
  final Duration timeout;

  static const host = 'generativelanguage.googleapis.com';

  /// Spec §6.6: a smart request may take 20 seconds, the body included.
  static const defaultTimeout = Duration(seconds: 20);

  /// A model id goes into the request path, so only a plain name is used.
  static final _modelId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

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
      final key = await _key();
      final model = await _model();
      if (key == null || !_modelId.hasMatch(model)) return null;
      final catalogue = await loadSmartCatalogue(_repository);
      final response = await _gate.post(
        feature,
        Uri.https(host, '/v1beta/models/$model:generateContent'),
        headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': smartPrompt(catalogue, input.kind)},
                ..._partsOf(input),
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'responseJsonSchema': smartResponseSchema(catalogue),
          },
        }),
        timeout: timeout,
      );
      if (response.statusCode != 200) return null;
      final answer = _answerText(response.body);
      if (answer == null) return null;
      return readSmartResult(answer, catalogue, day: day);
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

  /// The text of the first candidate's parts, which with a JSON response
  /// type is the JSON answer itself.
  static String? _answerText(String body) {
    final decoded = jsonDecode(body);
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
