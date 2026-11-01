import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/voice.dart';

void main() {
  group('pickArabicLocale', () {
    test('prefers Egyptian Arabic', () {
      expect(pickArabicLocale(['en_US', 'ar_SA', 'ar_EG']), 'ar_EG');
    });

    test('falls back to Saudi Arabic', () {
      expect(pickArabicLocale(['en_US', 'ar_AE', 'ar_SA']), 'ar_SA');
    });

    test('then any Arabic', () {
      expect(pickArabicLocale(['en_US', 'ar_AE']), 'ar_AE');
      expect(pickArabicLocale(['en-US', 'ar']), 'ar');
    });

    test('reads dashes and underscores alike, in any case', () {
      expect(pickArabicLocale(['ar-SA', 'AR-eg']), 'AR-eg');
    });

    test('is null when the recogniser lists no Arabic', () {
      expect(pickArabicLocale(['en_US', 'fr_FR']), isNull);
      expect(pickArabicLocale(['arn_CL']), isNull);
    });

    test('asks for ar-EG when the recogniser lists nothing at all', () {
      expect(pickArabicLocale(const []), 'ar-EG');
    });
  });

  test('a voice note lives under attachments by month', () {
    expect(voiceNotePath(DateTime(2026, 9, 5, 23), 'abc'),
        'attachments/2026-09/abc.m4a');
    expect(voiceNotePath(DateTime(2026, 12, 1), 'x'),
        'attachments/2026-12/x.m4a');
  });

  test('errors that mean no offline recogniser for the language', () {
    for (final code in [
      'error_language_not_supported',
      'error_language_unavailable',
      'error_network',
      'error_network_timeout',
      'error_server',
      'error_server_disconnected',
      'recognizerNotAvailable',
    ]) {
      expect(speechErrorMeansUnavailable(code), isTrue, reason: code);
    }
    for (final code in ['error_no_match', 'error_speech_timeout', 'error_busy']) {
      expect(speechErrorMeansUnavailable(code), isFalse, reason: code);
    }
  });

  test('errors that stop recognition for good', () {
    expect(speechErrorIsPermanent('error_permission'), isTrue);
    expect(speechErrorIsPermanent('error_audio_error'), isTrue);
    // Android raises it when listening starts again too soon after a
    // session ends: waiting and trying again can help.
    expect(speechErrorIsPermanent('error_client'), isFalse);
    expect(speechErrorIsPermanent('error_no_match'), isFalse);
    expect(speechErrorIsPermanent('error_speech_timeout'), isFalse);
  });

  test('the transcript joins finished phrases and the one being heard', () {
    expect(joinTranscript(const [], ''), '');
    expect(joinTranscript(const ['طماطم ب 30'], ''), 'طماطم ب 30');
    expect(joinTranscript(const ['طماطم ب 30', 'عيش ب 10'], ' لبن '),
        'طماطم ب 30\nعيش ب 10\nلبن');
    expect(joinTranscript(const ['  ', 'عيش'], ''), 'عيش');
  });

  test('the recording timer reads m:ss in Latin digits', () {
    expect(formatRecordingTime(Duration.zero), '0:00');
    expect(formatRecordingTime(const Duration(seconds: 9)), '0:09');
    expect(formatRecordingTime(const Duration(minutes: 1, seconds: 5)), '1:05');
    expect(formatRecordingTime(voiceMaxDuration), '2:00');
  });

  test('a level in dBFS maps to 0..1 for the waveform', () {
    expect(levelFromDbfs(0), 1.0);
    expect(levelFromDbfs(-60), 0.0);
    expect(levelFromDbfs(-160), 0.0);
    expect(levelFromDbfs(-30), closeTo(0.5, 0.001));
    expect(levelFromDbfs(double.negativeInfinity), 0.0);
    expect(levelFromDbfs(double.nan), 0.0);
  });
}
