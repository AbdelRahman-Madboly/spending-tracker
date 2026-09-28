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

    test('can see the system speech recognition service', () {
      // Android 11+ package visibility hides the recogniser unless queried.
      expect(manifest, contains('android.speech.RecognitionService'));
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
