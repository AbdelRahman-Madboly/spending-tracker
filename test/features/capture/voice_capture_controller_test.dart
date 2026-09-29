import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/online_features.dart';
import 'package:spending_tracker/domain/voice.dart';
import 'package:spending_tracker/features/capture/voice_capture_controller.dart';

import 'voice_fakes.dart';

class _Setup {
  final recorder = FakeVoiceRecorder();
  final speech = FakeSpeechRecognition();
  final repo = FixtureSpendingRepository();
  late final controller = VoiceCaptureController(
    recorder: recorder,
    speech: speech,
    repository: repo,
    clock: () => DateTime(2026, 9, 22, 12),
    newId: () => 'v1',
  );
}

Future<void> _allowOnlineSpeech(FixtureSpendingRepository repo) async {
  await repo.setSetting(onlineFeaturesSettingKey, 'true');
  await repo.setSetting(OnlineFeature.onlineSpeech.settingKey, 'true');
}

void main() {
  testWidgets('starts recording to a month folder and listens on the phone '
      'in Egyptian Arabic', (tester) async {
    final s = _Setup();
    await s.controller.start();

    expect(s.controller.phase, VoicePhase.recording);
    expect(s.recorder.path, 'attachments/2026-09/v1.m4a');
    expect(s.speech.listens, [(localeId: 'ar_EG', onDevice: true)]);
    expect(s.controller.mode, RecognitionMode.onDevice);
    await s.controller.discard();
  });

  testWidgets('a refused microphone records nothing', (tester) async {
    final s = _Setup();
    s.recorder.permission = false;
    await s.controller.start();

    expect(s.controller.phase, VoicePhase.permissionDenied);
    expect(s.recorder.calls, ['permission']);
    expect(s.speech.listens, isEmpty);
  });

  testWidgets('the transcript grows live, phrase by phrase', (tester) async {
    final s = _Setup();
    await s.controller.start();

    s.speech.hear('طماطم');
    expect(s.controller.transcript, 'طماطم');
    s.speech.hear('طماطم ب 30', isFinal: true);
    s.speech.hear('عيش');
    expect(s.controller.transcript, 'طماطم ب 30\nعيش');
    await s.controller.discard();
  });

  testWidgets('the timer counts while recording', (tester) async {
    final s = _Setup();
    await s.controller.start();
    await tester.pump(const Duration(seconds: 3));

    expect(s.controller.elapsed, const Duration(seconds: 3));
    await s.controller.discard();
  });

  testWidgets('the waveform keeps the latest levels', (tester) async {
    final s = _Setup();
    await s.controller.start();
    s.recorder.emitLevel(0.2);
    s.recorder.emitLevel(0.9);
    await tester.pump();

    expect(s.controller.levels.last, 0.9);
    expect(s.controller.levels, hasLength(VoiceCaptureController.levelCount));
    await s.controller.discard();
  });

  testWidgets('stop keeps the audio, with its transcript and duration',
      (tester) async {
    final s = _Setup();
    await s.controller.start();
    s.speech.hear('طماطم ب 30', isFinal: true);
    // Still being heard when stop is tapped: it counts.
    s.speech.hear('عيش ب 10');
    await tester.pump(const Duration(seconds: 4));

    final result = await s.controller.stop();

    expect(s.controller.phase, VoicePhase.stopped);
    expect(s.recorder.calls, contains('stop'));
    expect(s.recorder.calls, isNot(contains('cancel')));
    expect(s.speech.stops, 1);
    expect(result.audioPath, 'attachments/2026-09/v1.m4a');
    expect(result.durationMs, 4000);
    expect(result.transcript, 'طماطم ب 30\nعيش ب 10');
    expect(result.recognitionUnavailable, isFalse);
  });

  testWidgets('recording stops by itself after two minutes', (tester) async {
    final s = _Setup();
    VoiceCaptureResult? finished;
    s.controller.onFinished = (r) => finished = r;
    await s.controller.start();
    await tester.pump(voiceMaxDuration - const Duration(seconds: 1));
    expect(s.controller.phase, VoicePhase.recording);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(s.controller.phase, VoicePhase.stopped);
    expect(finished?.durationMs, voiceMaxDuration.inMilliseconds);
  });

  testWidgets('discard deletes the recording', (tester) async {
    final s = _Setup();
    await s.controller.start();
    await s.controller.discard();

    expect(s.recorder.calls, contains('cancel'));
    expect(s.speech.cancels, greaterThan(0));
    expect(s.controller.phase, VoicePhase.discarded);
  });

  testWidgets('a pause ends a recogniser session; it listens again while '
      'recording', (tester) async {
    final s = _Setup();
    await s.controller.start();
    s.speech.hear('طماطم ب 30', isFinal: true);
    s.speech.end();
    await tester.pump(const Duration(seconds: 1));

    expect(s.speech.listens, hasLength(2));
    expect(s.speech.listens.last.onDevice, isTrue);
    s.speech.hear('عيش ب 10', isFinal: true);
    expect(s.controller.transcript, 'طماطم ب 30\nعيش ب 10');
    await s.controller.discard();
  });

  testWidgets('silence errors listen again too', (tester) async {
    final s = _Setup();
    await s.controller.start();
    s.speech.fail('error_no_match');
    await tester.pump(const Duration(seconds: 1));

    expect(s.speech.listens, hasLength(2));
    expect(s.controller.mode, RecognitionMode.onDevice);
    await s.controller.discard();
  });

  group('no offline Arabic recogniser', () {
    testWidgets('with online speech off, keeps recording audio only and '
        'never listens online', (tester) async {
      final s = _Setup();
      s.speech.onDeviceError = 'error_language_unavailable';
      await s.controller.start();
      await tester.pump(const Duration(seconds: 1));

      expect(s.controller.mode, RecognitionMode.unavailable);
      expect(s.controller.phase, VoicePhase.recording);
      expect(s.speech.listens.every((l) => l.onDevice), isTrue);
      expect(s.speech.listens, hasLength(1));

      final result = await s.controller.stop();
      expect(result.audioPath, isNotNull);
      expect(result.transcript, isEmpty);
      expect(result.recognitionUnavailable, isTrue);
    });

    testWidgets('with online speech on, falls back to the online recogniser',
        (tester) async {
      final s = _Setup();
      await _allowOnlineSpeech(s.repo);
      s.speech.onDeviceError = 'error_network';
      await s.controller.start();
      await tester.pump(const Duration(seconds: 1));

      expect(s.controller.mode, RecognitionMode.online);
      expect(s.speech.listens.last, (localeId: 'ar_EG', onDevice: false));
      s.speech.hear('عيش ب 10', isFinal: true);
      expect(s.controller.transcript, 'عيش ب 10');
      await s.controller.discard();
    });

    testWidgets('online speech alone, without the master switch, stays off',
        (tester) async {
      final s = _Setup();
      await s.repo.setSetting(OnlineFeature.onlineSpeech.settingKey, 'true');
      s.speech.onDeviceError = 'error_language_not_supported';
      await s.controller.start();
      await tester.pump(const Duration(seconds: 1));

      expect(s.controller.mode, RecognitionMode.unavailable);
      expect(s.speech.listens.where((l) => !l.onDevice), isEmpty);
      await s.controller.discard();
    });

    testWidgets('shows the offline pack hint once, ever', (tester) async {
      final s = _Setup();
      s.speech.onDeviceError = 'error_language_unavailable';
      await s.controller.start();
      await tester.pump(const Duration(seconds: 1));
      expect(s.controller.showOfflineHint, isTrue);
      await s.controller.discard();

      final again = VoiceCaptureController(
        recorder: FakeVoiceRecorder(),
        speech: FakeSpeechRecognition(
            onDeviceError: 'error_language_unavailable'),
        repository: s.repo,
      );
      await again.start();
      await tester.pump(const Duration(seconds: 1));
      expect(again.mode, RecognitionMode.unavailable);
      expect(again.showOfflineHint, isFalse);
      await again.discard();
    });

    testWidgets('a phone with no recogniser at all records audio only',
        (tester) async {
      final s = _Setup();
      s.speech.available = false;
      await s.controller.start();

      expect(s.controller.mode, RecognitionMode.unavailable);
      expect(s.controller.phase, VoicePhase.recording);
      expect(s.speech.listens, isEmpty);
      await s.controller.discard();
    });

    testWidgets('a recogniser with no Arabic records audio only',
        (tester) async {
      final s = _Setup();
      s.speech.locales = ['en_US'];
      await s.controller.start();

      expect(s.controller.mode, RecognitionMode.unavailable);
      expect(s.speech.listens, isEmpty);
      await s.controller.discard();
    });
  });

  testWidgets('a microphone the recorder cannot open still transcribes',
      (tester) async {
    final s = _Setup();
    s.recorder.failStart = true;
    await s.controller.start();
    s.speech.hear('عيش ب 10', isFinal: true);

    final result = await s.controller.stop();
    expect(result.audioPath, isNull);
    expect(result.transcript, 'عيش ب 10');
  });

  testWidgets('no audio and no recogniser fails', (tester) async {
    final s = _Setup();
    s.recorder.failStart = true;
    s.speech.available = false;
    await s.controller.start();

    expect(s.controller.phase, VoicePhase.failed);
  });
}
