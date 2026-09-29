import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/app_flavor.dart';

void main() {
  group('AppFlavor', () {
    test('a build without a flavour is the personal one', () {
      expect(AppFlavor.fromName(null), AppFlavor.personal);
      expect(AppFlavor.fromName('personal'), AppFlavor.personal);
      expect(AppFlavor.fromName('shared'), AppFlavor.shared);
    });

    test('the personal build seeds the owner history and offers his packs',
        () {
      const f = AppFlavor.personal;
      expect(f.seedAsset, 'assets/seed/seed.json');
      expect(f.bundlesImportPacks, isTrue);
      expect(f.suggestsSeedBills, isTrue);
      expect(f.offersWelcome, isFalse);
      expect(f.hasPersonalDefaults, isTrue);
    });

    test('the shared build starts empty and welcomes the new user', () {
      const f = AppFlavor.shared;
      expect(f.seedAsset, 'assets/seed/seed_shared.json');
      expect(f.bundlesImportPacks, isFalse);
      expect(f.suggestsSeedBills, isFalse);
      expect(f.offersWelcome, isTrue);
      expect(f.hasPersonalDefaults, isFalse);
    });

    test('tests run as the personal build unless they say otherwise', () {
      expect(AppFlavor.current, AppFlavor.personal);
    });
  });
}
