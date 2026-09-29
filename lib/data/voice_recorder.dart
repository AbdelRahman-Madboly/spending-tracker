import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../domain/voice.dart';

/// Records one voice note, behind one seam: record talks to a platform
/// channel that does not run under `flutter test`, so the voice capture is
/// tested against a fake of this interface, as [PhotoCaptureService] and
/// [BarcodeScanService] are.
abstract class VoiceRecorder {
  /// Asks for the microphone; false when it is refused.
  Future<bool> requestPermission();

  /// Starts writing AAC-LC audio to [relativePath], relative to the app
  /// documents directory. Throws when the microphone cannot be opened.
  Future<void> start(String relativePath);

  /// The microphone level while recording, 0 (silence) to 1.
  Stream<double> get levels;

  /// Stops and keeps the file.
  Future<void> stop();

  /// Stops and deletes the file: the recording was thrown away.
  Future<void> cancel();

  Future<void> dispose();
}

class RecordVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String relativePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final file = File(p.join(documents.path, relativePath));
    await file.parent.create(recursive: true);
    // Mono at 44.1 kHz and 64 kbps: plenty for speech, and a two-minute
    // note stays under 1 MB. AAC-LC in .m4a is what Gemini accepts as
    // audio/m4a (spec §6.6).
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: file.path,
    );
  }

  @override
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => levelFromDbfs(a.current));

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}
