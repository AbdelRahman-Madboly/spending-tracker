import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the platform setup v3 depends on. These are plain file checks
/// rather than builds: a manifest or pubspec regression is caught by the
/// suite in seconds instead of at the next APK build or on the phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android manifest', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('declares INTERNET and no longer strips it', () {
      // v3 reaches the network only through NetworkGate and only when the
      // user switches an online feature on; the permission itself must be
      // present for that to be possible at all.
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.INTERNET"/>',
        ),
      );
      expect(
        RegExp(
          r'android\.permission\.INTERNET"\s+tools:node="remove"',
        ).hasMatch(manifest),
        isFalse,
      );
    });

    test('declares RECORD_AUDIO for voice capture', () {
      expect(manifest, contains('android.permission.RECORD_AUDIO'));
    });

    test('turns off Android cloud backup of app data', () {
      // Auto backup would upload the spending database to the cloud
      // outside NetworkGate, with the online switches off, and restore
      // secure-storage ciphertext whose Keystore key did not travel.
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));
    });

    test('is a share target for images, one or several, beside text and '
        'files', () {
      // An InstaPay screenshot, gallery photos or a WhatsApp image shared
      // in opens the photo capture; text and files still go to import.
      final filters = RegExp(r'<intent-filter>(.*?)</intent-filter>',
              dotAll: true)
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .toList();
      bool accepts(String action, String mime) => filters.any((f) =>
          f.contains('android.intent.action.$action"') &&
          f.contains('android:mimeType="$mime"') &&
          f.contains('android.intent.category.DEFAULT'));
      expect(accepts('SEND', 'image/*'), isTrue);
      expect(accepts('SEND_MULTIPLE', 'image/*'), isTrue);
      expect(accepts('SEND', 'text/*'), isTrue);
      expect(accepts('SEND', 'application/*'), isTrue);
    });

    test('can see the system speech recognition service', () {
      // Android 11+ package visibility hides the recogniser unless queried.
      expect(manifest, contains('android.speech.RecognitionService'));
    });
  });

  group('release shrinking', () {
    test('tells R8 the unused ML Kit script recognisers are absent', () {
      // The text recognition plugin references the Chinese, Devanagari,
      // Japanese and Korean options classes; only Latin is bundled, and
      // without these rules `flutter build apk --release` fails in R8.
      final rules = File('android/app/proguard-rules.pro').readAsStringSync();
      for (final script in ['chinese', 'devanagari', 'japanese', 'korean']) {
        expect(
          rules,
          contains('-dontwarn com.google.mlkit.vision.text.$script.'),
        );
      }
    });
  });

  group('pubspec assets', () {
    test('bundles the prepared import packs', () async {
      final manual = await rootBundle.loadString(
        'assets/import/manual_2026-09.json',
      );
      expect(manual, contains('manual-import/1'));
    });

    test('bundles the import evidence files', () async {
      final evidence = await rootBundle.load(
        'assets/import/evidence/2026-09-30_Sample-Salary.png',
      );
      expect(evidence.lengthInBytes, greaterThan(0));
    });
  });
}
