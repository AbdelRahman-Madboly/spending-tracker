import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/models.dart';

void main() {
  group('DraftEntry.withPhotoPath', () {
    const base = DraftEntry(
      amountPiastres: 500,
      itemId: 'item-1',
      description: 'كولا',
      categoryKey: 'Drinks',
      subcategoryKey: 'Soda',
      paymentMethod: 'Cash',
      source: EntrySource.quickPick,
    );

    test('attaches a relative photo path without touching other fields', () {
      final withPhoto = base.withPhotoPath('photos/123.jpg');

      expect(withPhoto.photoPath, 'photos/123.jpg');
      expect(withPhoto.amountPiastres, base.amountPiastres);
      expect(withPhoto.itemId, base.itemId);
      expect(withPhoto.description, base.description);
      expect(withPhoto.categoryKey, base.categoryKey);
      expect(withPhoto.subcategoryKey, base.subcategoryKey);
      expect(withPhoto.paymentMethod, base.paymentMethod);
      expect(withPhoto.source, base.source);
    });

    test('passing null clears a previously attached photo', () {
      final withPhoto = base.withPhotoPath('photos/123.jpg');

      final cleared = withPhoto.withPhotoPath(null);

      expect(cleared.photoPath, isNull);
    });
  });
}
