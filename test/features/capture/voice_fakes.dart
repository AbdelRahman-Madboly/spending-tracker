import 'dart:async';

import 'package:spending_tracker/data/speech_recognition_service.dart';
import 'package:spending_tracker/data/voice_recorder.dart';

/// A recorder that records nothing, remembering what it was asked to do.
class FakeVoiceRecorder implements VoiceRecorder {
  bool permission;
  bool failStart;
  final calls = <String>[];
  String? path;
  final _levels = StreamController<double>.broadcast();

  FakeVoiceRecorder({this.permission = true, this.failStart = false});

  void emitLevel(double level) => _levels.add(level);

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return permission;
  }

  @override
  Future<void> start(String relativePath) async {
    calls.add('start');
    if (failStart) throw StateError('microphone busy');
    path = relativePath;
  }

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

/// One `listen` call as the capture made it.
typedef ListenCall = ({String localeId, bool onDevice});

/// A recogniser driven by the test: it hears what [hear] says, fails with
/// [fail], and ends a session with [end].
class FakeSpeechRecognition implements SpeechRecognitionService {
  bool available;
  List<String> locales;

  /// An error code to raise as soon as an on-device listen starts, as a
  /// phone with no offline Arabic pack does.
  String? onDeviceError;
  final listens = <ListenCall>[];
  int stops = 0;
  int cancels = 0;

  void Function(String code)? _onError;
  void Function(String status)? _onStatus;
  void Function(String words, bool isFinal)? _onResult;

  FakeSpeechRecognition({
    this.available = true,
    this.locales = const ['en_US', 'ar_SA', 'ar_EG'],
    this.onDeviceError,
  });

  void hear(String words, {bool isFinal = false}) =>
      _onResult?.call(words, isFinal);
  void fail(String code) => _onError?.call(code);
  void end() => _onStatus?.call('done');

  @override
  Future<bool> initialize({
    required void Function(String code) onError,
    required void Function(String status) onStatus,
  }) async {
    _onError = onError;
    _onStatus = onStatus;
    return available;
  }

  @override
  Future<List<String>> localeIds() async => locales;

  @override
  Future<void> listen({
    required String localeId,
    required bool onDevice,
    required void Function(String words, bool isFinal) onResult,
  }) async {
    listens.add((localeId: localeId, onDevice: onDevice));
    _onResult = onResult;
    final error = onDeviceError;
    if (onDevice && error != null) {
      scheduleMicrotask(() => _onError?.call(error));
    }
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async => cancels++;
}
