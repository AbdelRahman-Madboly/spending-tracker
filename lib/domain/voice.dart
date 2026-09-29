/// The pure parts of voice capture (spec §6.4): which recogniser locale to
/// ask for, where the audio is stored, which recogniser errors mean what,
/// and how the live transcript and timer read. No Flutter or plugin
/// imports, so all of it is unit tested directly.
library;

/// A recording stops by itself after this long (spec §6.4).
const voiceMaxDuration = Duration(minutes: 2);

/// The recogniser locale to listen in: `ar-EG`, then `ar-SA`, then any
/// other Arabic, from the ids the recogniser reports. Android reports
/// `ar_EG` and some engines `ar-EG`, so both separators match, and the id
/// comes back exactly as reported.
///
/// Null when the recogniser lists locales and none is Arabic. An empty
/// list (some engines report nothing) still asks for `ar-EG`: the engine
/// may well support it without saying so, and a refusal comes back as an
/// error the capture already handles.
String? pickArabicLocale(Iterable<String> localeIds) {
  final ids = localeIds.toList();
  if (ids.isEmpty) return 'ar-EG';
  String norm(String id) => id.toLowerCase().replaceAll('_', '-');
  for (final wanted in const ['ar-eg', 'ar-sa']) {
    for (final id in ids) {
      if (norm(id) == wanted) return id;
    }
  }
  for (final id in ids) {
    final n = norm(id);
    if (n == 'ar' || n.startsWith('ar-')) return id;
  }
  return null;
}

/// Where a voice note is stored, relative to the app documents directory
/// (spec §5: `attachments/<yyyy-MM>/<id>.<ext>`).
String voiceNotePath(DateTime now, String id) {
  final month = now.month.toString().padLeft(2, '0');
  return 'attachments/${now.year}-$month/$id.m4a';
}

/// Recogniser errors that, on an on-device attempt, mean there is no
/// offline recogniser for Arabic here: the language is missing, or the
/// engine tried to reach its servers (it falls back to them when it has
/// no offline pack). The capture then keeps recording audio only, or
/// switches to online recognition when the user allowed it.
bool speechErrorMeansUnavailable(String code) => const {
      'error_language_not_supported',
      'error_language_unavailable',
      'error_network',
      'error_network_timeout',
      'error_server',
      'error_server_disconnected',
      'recognizerNotAvailable',
    }.contains(code);

/// Recogniser errors after which listening again cannot help. Silence
/// (`error_no_match`, `error_speech_timeout`) is not one: the recogniser
/// stops after a pause, and the capture listens again while it records.
bool speechErrorIsPermanent(String code) => const {
      'error_permission',
      'error_audio_error',
      'error_client',
    }.contains(code);

/// The live transcript: every phrase the recogniser finished, one per
/// line, then the phrase it is hearing now. A line per phrase is what the
/// parser splits items on.
String joinTranscript(List<String> finished, String hearing) => [
      ...finished,
      hearing,
    ].map((p) => p.trim()).where((p) => p.isNotEmpty).join('\n');

/// The recording timer, `m:ss` in Latin digits.
String formatRecordingTime(Duration elapsed) {
  final seconds = elapsed.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// A microphone level in dBFS (0 is loudest) as 0..1 for the waveform.
/// Anything at or below -60 dBFS is silence.
double levelFromDbfs(double dbfs) {
  if (dbfs.isNaN) return 0;
  const floor = -60.0;
  return ((dbfs.clamp(floor, 0) - floor) / -floor).toDouble();
}
