import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/app_flavor.dart';
import '../domain/spending_repository.dart';

/// The `app_settings` key holding «اسمك أو حسابك على InstaPay»: the names
/// and addresses a transfer screenshot names the user by, which is how a
/// transfer in is told from one sent (see `ownIdentityPattern`).
const instaPayIdentitySettingKey = 'instapay_identity';

/// The personal build's own defaults. Bundled only in that build, so the
/// shared one carries nothing of the owner.
const personalDefaultsAsset = 'assets/personal/defaults.json';

/// Who the user is on InstaPay: what they typed in the settings (even
/// cleared), else the personal build's bundled default, else nobody.
Future<String> instaPayIdentity(
  SpendingRepository repository, {
  Future<String?> Function()? defaults,
}) async {
  final stored = await repository.setting(instaPayIdentitySettingKey);
  if (stored != null) return stored;
  if (!AppFlavor.current.hasPersonalDefaults) return '';
  try {
    return await (defaults ?? personalInstaPayDefault)() ?? '';
  } catch (_) {
    return '';
  }
}

/// Where [instaPayIdentity] reads the personal default from. Widget tests
/// read the file straight from disk instead (test/flutter_test_config.dart),
/// since an asset load does not finish inside a test's fake clock.
Future<String?> Function() personalInstaPayDefault =
    () async => instaPayDefaultFrom(
          await rootBundle.loadString(personalDefaultsAsset),
        );

/// The InstaPay identity in the text of [personalDefaultsAsset], or null.
String? instaPayDefaultFrom(String text) {
  final json = jsonDecode(text);
  return json is Map<String, dynamic> && json['instaPayIdentity'] is String
      ? json['instaPayIdentity'] as String
      : null;
}
