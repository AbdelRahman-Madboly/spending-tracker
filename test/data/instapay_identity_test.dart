import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/app_flavor.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/instapay_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FixtureSpendingRepository repo;
  setUp(() => repo = FixtureSpendingRepository());
  tearDown(() => AppFlavor.current = AppFlavor.personal);

  test('what the user typed wins, even when cleared', () async {
    await repo.setSetting(instaPayIdentitySettingKey, 'sara@instapay');
    expect(await instaPayIdentity(repo), 'sara@instapay');
    await repo.setSetting(instaPayIdentitySettingKey, '');
    expect(await instaPayIdentity(repo), '');
  });

  test('the personal build falls back to the owner defaults it bundles',
      () async {
    expect(await instaPayIdentity(repo), contains('sampleuser@instapay'));
    // The one the app reads, from the bundle rather than the disk.
    final bundled = instaPayDefaultFrom(
        await rootBundle.loadString(personalDefaultsAsset));
    expect(bundled, contains('sampleuser@instapay'));
  });

  test('the shared build knows nobody until told', () async {
    AppFlavor.current = AppFlavor.shared;
    var read = false;
    final identity = await instaPayIdentity(repo, defaults: () async {
      read = true;
      return 'someone';
    });
    expect(identity, '');
    expect(read, isFalse);
  });

  test('missing or broken defaults are no identity', () async {
    expect(await instaPayIdentity(repo, defaults: () async => null), '');
    expect(
        await instaPayIdentity(repo, defaults: () => throw Exception('gone')),
        '');
  });
}
