import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

/// Plays one voice note, behind one seam: just_audio talks to a platform
/// channel that does not run under `flutter test`, so widget tests inject
/// a fake, and the real player is only created when play is first tapped.
abstract class VoicePlayback {
  /// Loads [file] and returns its duration when the player knows it.
  Future<Duration?> open(File file);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// The play position while it changes.
  Stream<Duration> get positions;

  /// True while playing; false once paused or played to the end.
  Stream<bool> get playingChanges;
  Future<void> dispose();
}

class JustAudioVoicePlayback implements VoicePlayback {
  final _player = AudioPlayer();
  final _playing = StreamController<bool>.broadcast();
  StreamSubscription<PlayerState>? _states;

  JustAudioVoicePlayback() {
    _states = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Back to the start and paused, so the next tap plays it again.
        _player.pause();
        _player.seek(Duration.zero);
        _playing.add(false);
      } else {
        _playing.add(state.playing);
      }
    });
  }

  @override
  Future<Duration?> open(File file) => _player.setFilePath(file.path);

  // play() completes only when playback stops, so it is not awaited.
  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<Duration> get positions => _player.positionStream;

  @override
  Stream<bool> get playingChanges => _playing.stream;

  @override
  Future<void> dispose() async {
    await _states?.cancel();
    await _playing.close();
    await _player.dispose();
  }
}
