import 'spending_repository.dart';

/// The `app_settings` key of the master online switch (spec §4.6). Off by
/// default: with it off no feature reaches the network, whatever its own
/// switch says.
const onlineFeaturesSettingKey = 'online_features';

/// The features that may reach the network (spec §9.2), each with its own
/// switch under the master one.
enum OnlineFeature {
  gemini('online_gemini'),
  geminiAudio('online_gemini_audio'),
  productLookup('online_product_lookup'),
  onlineSpeech('online_speech');

  const OnlineFeature(this.settingKey);

  /// The `app_settings` key of this feature's own switch.
  final String settingKey;
}

/// Whether [feature] may be used: both the master switch and the feature's
/// own switch read `true`. Anything else, a missing row included, is off.
Future<bool> isOnlineFeatureOn(
    SpendingRepository repository, OnlineFeature feature) async {
  if (await repository.setting(onlineFeaturesSettingKey) != 'true') {
    return false;
  }
  return await repository.setting(feature.settingKey) == 'true';
}
