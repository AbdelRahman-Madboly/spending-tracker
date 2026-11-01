import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/online_features.dart';

void main() {
  test('every feature is off by default', () async {
    final repo = FixtureSpendingRepository();
    for (final feature in OnlineFeature.values) {
      expect(await isOnlineFeatureOn(repo, feature), isFalse,
          reason: feature.name);
    }
  });

  test('a feature switch without the master switch stays off', () async {
    final repo = FixtureSpendingRepository();
    await repo.setSetting(OnlineFeature.onlineSpeech.settingKey, 'true');
    expect(await isOnlineFeatureOn(repo, OnlineFeature.onlineSpeech), isFalse);
  });

  test('the master switch alone turns nothing on', () async {
    final repo = FixtureSpendingRepository();
    await repo.setSetting(onlineFeaturesSettingKey, 'true');
    expect(await isOnlineFeatureOn(repo, OnlineFeature.onlineSpeech), isFalse);
  });

  test('both switches on turn that feature on, and only that one', () async {
    final repo = FixtureSpendingRepository();
    await repo.setSetting(onlineFeaturesSettingKey, 'true');
    await repo.setSetting(OnlineFeature.onlineSpeech.settingKey, 'true');
    expect(await isOnlineFeatureOn(repo, OnlineFeature.onlineSpeech), isTrue);
    expect(await isOnlineFeatureOn(repo, OnlineFeature.gemini), isFalse);
  });

  test('every feature has its own setting key', () {
    final keys = {for (final f in OnlineFeature.values) f.settingKey};
    expect(keys, hasLength(OnlineFeature.values.length));
    expect(keys, isNot(contains(onlineFeaturesSettingKey)));
  });
}
