import 'package:speech_to_text/speech_to_text.dart';

/// Turns speech into text with the phone's own recogniser, behind one seam:
/// speech_to_text talks to a platform channel that does not run under
/// `flutter test`, so the voice capture is tested against a fake of this
/// interface, as [PhotoCaptureService] and [BarcodeScanService] are.
///
/// The recogniser runs in the system's speech service, not in this app, so
/// it never opens a socket of ours. Whether it may use Google's servers is
/// decided by [listen]'s `onDevice`, which the capture sets from the online
/// speech switch (spec §9.2 rule 3).
abstract class SpeechRecognitionService {
  /// Readies the recogniser and says where its errors and status changes
  /// go. False when the phone has no recogniser at all.
  ///
  /// Errors arrive as the recogniser's code (`error_no_match`,
  /// `error_language_unavailable`, ...); statuses as `listening`,
  /// `notListening` or `done`.
  Future<bool> initialize({
    required void Function(String code) onError,
    required void Function(String status) onStatus,
  });

  /// The locale ids the recogniser reports, such as `ar_EG`.
  Future<List<String>> localeIds();

  /// Listens once, until a pause or [stop]. [onResult] gets the words
  /// heard so far, and `isFinal` once the phrase is finished.
  ///
  /// With [onDevice] the recogniser is asked to stay on the phone.
  Future<void> listen({
    required String localeId,
    required bool onDevice,
    required void Function(String words, bool isFinal) onResult,
  });

  /// Stops listening and delivers what was heard as final.
  Future<void> stop();

  /// Stops listening and drops what was being heard.
  Future<void> cancel();
}

class SpeechToTextRecognitionService implements SpeechRecognitionService {
  // speech_to_text hands out one shared instance.
  final _speech = SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String code) onError,
    required void Function(String status) onStatus,
  }) async {
    final ok = await _speech.initialize();
    // Set after initialize, not through it: the instance is shared and
    // only its first initialize takes listeners, so a second capture
    // would otherwise report to the first one.
    _speech.errorListener = (e) => onError(e.errorMsg);
    _speech.statusListener = onStatus;
    return ok;
  }

  @override
  Future<List<String>> localeIds() async =>
      [for (final l in await _speech.locales()) l.localeId];

  @override
  Future<void> listen({
    required String localeId,
    required bool onDevice,
    required void Function(String words, bool isFinal) onResult,
  }) async {
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        onDevice: onDevice,
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        // The recogniser ends a session on its own after a pause; the
        // capture listens again while it records, so long pauses between
        // items are fine.
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
