import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/speech_recognition_service.dart';
import '../../data/voice_recorder.dart';
import '../../domain/online_features.dart';
import '../../domain/spending_repository.dart';
import '../../domain/voice.dart';

enum VoicePhase {
  idle,
  recording,
  stopped,
  discarded,
  permissionDenied,

  /// Neither the recorder nor the recogniser could start: nothing can be
  /// captured.
  failed,
}

/// Where the words come from. [unavailable] means audio only: there is no
/// Arabic recogniser the capture may use, and the text is typed later.
enum RecognitionMode { onDevice, online, unavailable }

/// What one recording produced.
class VoiceCaptureResult {
  /// The `.m4a` relative to the app documents directory, or null when the
  /// recorder could not open the microphone.
  final String? audioPath;
  final int durationMs;
  final String transcript;

  const VoiceCaptureResult({
    required this.audioPath,
    required this.durationMs,
    required this.transcript,
  });
}

/// `app_settings` key recording that the offline Arabic pack hint was
/// shown, so it shows once (spec §6.4).
const voiceOfflineHintSettingKey = 'voice_offline_hint_shown';

/// One voice capture (spec §6.4): records the audio and transcribes it at
/// the same time, with a timer, the live level and the live transcript.
///
/// Recognition is on the phone first. When the phone has no offline Arabic
/// recogniser, the online system recogniser is used only if the online
/// speech switch is on (spec §9.2 rule 3); otherwise the audio is still
/// recorded and the text is typed later.
class VoiceCaptureController extends ChangeNotifier {
  final VoiceRecorder recorder;
  final SpeechRecognitionService speech;
  final SpendingRepository repository;
  final DateTime Function() clock;
  final String Function() newId;

  /// Told the result when the recording stops, including the automatic
  /// stop at [voiceMaxDuration].
  void Function(VoiceCaptureResult result)? onFinished;

  /// How many levels the waveform shows.
  static const levelCount = 40;
  static const _tick = Duration(milliseconds: 100);

  /// The wait before listening again once the recogniser ends a session:
  /// long enough for its own end-of-session events to settle.
  static const _relistenDelay = Duration(milliseconds: 300);

  /// How many `error_client` in a row are retried before recognition is
  /// given up for this recording. Words heard in between reset the count.
  static const _clientErrorRetries = 3;

  VoiceCaptureController({
    required this.recorder,
    required this.speech,
    required this.repository,
    this.clock = DateTime.now,
    String Function()? newId,
  }) : newId = newId ??
            (() => DateTime.now().microsecondsSinceEpoch.toString());

  VoicePhase _phase = VoicePhase.idle;
  VoicePhase get phase => _phase;

  RecognitionMode? _mode;
  RecognitionMode? get mode => _mode;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  List<double> _levels = List.filled(levelCount, 0);
  List<double> get levels => _levels;

  final _finished = <String>[];
  String _hearing = '';
  String get transcript => joinTranscript(_finished, _hearing);

  bool _showOfflineHint = false;

  /// True the first time recognition turns out to be unavailable: the
  /// sheet then suggests installing the offline Arabic pack.
  bool get showOfflineHint => _showOfflineHint;

  String? _audioPath;
  String? _localeId;
  bool _onlineAllowed = false;
  int _clientErrors = 0;
  bool _disposed = false;
  VoiceCaptureResult? _result;
  VoiceCaptureResult? get result => _result;

  Timer? _ticker;
  Timer? _relisten;
  StreamSubscription<double>? _levelSub;

  bool get _recording => _phase == VoicePhase.recording;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_phase != VoicePhase.idle) return;
    if (!await recorder.requestPermission()) {
      _phase = VoicePhase.permissionDenied;
      _changed();
      return;
    }
    final path = voiceNotePath(clock(), newId());
    try {
      await recorder.start(path);
      _audioPath = path;
      _levelSub = recorder.levels.listen(_onLevel);
    } catch (_) {
      // The recogniser may still work (two apps can share the microphone
      // on some phones and not on others): carry on with words only.
      _audioPath = null;
    }
    _phase = VoicePhase.recording;
    _ticker = Timer.periodic(_tick, (_) => _onTick());
    _changed();
    await _startRecognition();
  }

  void _onLevel(double level) {
    _levels = [..._levels.skip(1), level.clamp(0, 1).toDouble()];
    _changed();
  }

  void _onTick() {
    if (!_recording) return;
    _elapsed += _tick;
    _changed();
    if (_elapsed >= voiceMaxDuration) unawaited(stop());
  }

  Future<void> _startRecognition() async {
    bool ready;
    try {
      ready = await speech.initialize(
          onError: _onSpeechError, onStatus: _onSpeechStatus);
    } catch (_) {
      ready = false;
    }
    if (!_recording) return;
    if (ready) {
      try {
        _localeId = pickArabicLocale(await speech.localeIds());
      } catch (_) {
        _localeId = null;
      }
    }
    if (!ready || _localeId == null) {
      await _recognitionUnavailable();
      return;
    }
    try {
      _onlineAllowed =
          await isOnlineFeatureOn(repository, OnlineFeature.onlineSpeech);
    } catch (_) {
      // Settings that cannot be read allow nothing online (spec §9.2).
      _onlineAllowed = false;
    }
    if (!_recording) return;
    _mode = RecognitionMode.onDevice;
    _changed();
    await _listen();
  }

  Future<void> _listen() async {
    final localeId = _localeId;
    if (!_recording || localeId == null) return;
    final mode = _mode;
    if (mode == null || mode == RecognitionMode.unavailable) return;
    try {
      await speech.listen(
        localeId: localeId,
        onDevice: mode == RecognitionMode.onDevice,
        onResult: _onResult,
      );
    } catch (_) {
      // A listen refused outright (the recogniser was still busy ending
      // its last session) is tried again after the usual wait.
      _scheduleRelisten();
    }
  }

  void _onResult(String words, bool isFinal) {
    if (!_recording) return;
    _clientErrors = 0;
    if (isFinal) {
      if (words.trim().isNotEmpty) _finished.add(words);
      _hearing = '';
    } else {
      _hearing = words;
    }
    _changed();
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') _scheduleRelisten();
  }

  void _onSpeechError(String code) {
    if (!_recording) return;
    if (speechErrorMeansUnavailable(code)) {
      unawaited(_fallBack());
    } else if (speechErrorIsPermanent(code) ||
        (code == 'error_client' && ++_clientErrors > _clientErrorRetries)) {
      unawaited(_recognitionUnavailable(hint: false));
    } else {
      _scheduleRelisten();
    }
  }

  /// There is no offline Arabic recogniser here. From on-device, go online
  /// when that is allowed; otherwise record audio only.
  ///
  /// The online session is started by the scheduled relisten, not called
  /// here: the failed session still reports that it stopped, and that
  /// report schedules a relisten too, so one timer means one listen.
  Future<void> _fallBack() async {
    if (_mode == RecognitionMode.onDevice && _onlineAllowed) {
      _mode = RecognitionMode.online;
      await _hintOnce();
      _changed();
      _scheduleRelisten();
      return;
    }
    await _recognitionUnavailable();
  }

  /// Recognition stops for the rest of this recording. [hint] suggests the
  /// offline Arabic pack, which is only worth it when a missing pack is the
  /// reason.
  Future<void> _recognitionUnavailable({bool hint = true}) async {
    _relisten?.cancel();
    _mode = RecognitionMode.unavailable;
    try {
      await speech.cancel();
    } catch (_) {}
    if (!_recording) return;
    if (_audioPath == null) {
      if (transcript.trim().isNotEmpty) {
        // No audio, but the words heard so far are the capture: keep them
        // (spec §6.7, closing never discards a capture).
        await stop();
        return;
      }
      // No audio and no words: nothing to keep.
      _stopTimers();
      _phase = VoicePhase.failed;
      _changed();
      return;
    }
    if (hint) await _hintOnce();
    _changed();
  }

  Future<void> _hintOnce() async {
    try {
      if (await repository.setting(voiceOfflineHintSettingKey) == 'true') {
        return;
      }
      _showOfflineHint = true;
      await repository.setSetting(voiceOfflineHintSettingKey, 'true');
    } catch (_) {
      // A hint is a nicety: a failed settings read or write never stops
      // the recording.
    }
  }

  void _scheduleRelisten() {
    if (!_recording) return;
    if (_mode == null || _mode == RecognitionMode.unavailable) return;
    _relisten?.cancel();
    _relisten = Timer(_relistenDelay, () => unawaited(_listen()));
  }

  void _stopTimers() {
    _ticker?.cancel();
    _relisten?.cancel();
    unawaited(_levelSub?.cancel());
    _levelSub = null;
  }

  /// Stops and keeps the recording. The phrase being heard counts as said.
  Future<VoiceCaptureResult> stop() async {
    final done = _result;
    if (done != null) return done;
    final unavailable = _mode == RecognitionMode.unavailable;
    _phase = VoicePhase.stopped;
    _stopTimers();
    final result = VoiceCaptureResult(
      audioPath: _audioPath,
      durationMs: _elapsed.inMilliseconds,
      transcript: transcript,
    );
    _result = result;
    _changed();
    if (!unavailable) {
      try {
        await speech.stop();
      } catch (_) {}
    }
    if (_audioPath != null) {
      try {
        await recorder.stop();
      } catch (_) {}
    }
    onFinished?.call(result);
    return result;
  }

  /// Stops and throws the recording away, file included.
  Future<void> discard() async {
    if (_phase == VoicePhase.discarded) return;
    final hadAudio = _audioPath != null && _result == null;
    _phase = VoicePhase.discarded;
    _stopTimers();
    _changed();
    try {
      await speech.cancel();
    } catch (_) {}
    if (hadAudio) {
      try {
        await recorder.cancel();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimers();
    unawaited(recorder.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
