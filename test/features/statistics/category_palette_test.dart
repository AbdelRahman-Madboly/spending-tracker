import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/features/statistics/category_palette.dart';

void main() {
  test(
      'the categorical palette never reuses a colour that already carries '
      'meaning elsewhere in the app', () {
    expect(categoryPalette, isNot(contains(AppColors.negative)));
    expect(categoryPalette, isNot(contains(AppColors.accent)));
  });

  test('the palette has ten entries so all ten categories are distinguishable',
      () {
    expect(categoryPalette.length, 10);
  });

  test('colorForCategory is stable for the same key across repeated calls',
      () {
    final first = colorForCategory('Family/Social');
    final second = colorForCategory('Family/Social');
    expect(first, second);
  });

  test('colorForCategory never returns the negative or accent colours', () {
    const keys = [
      'Drinks',
      'Snacks',
      'Food',
      'Transport',
      'Bills',
      'Personal Care',
      'Shopping',
      'Family/Social',
      'Gifts',
      'Loans',
    ];
    for (final key in keys) {
      final color = colorForCategory(key);
      expect(color, isNot(AppColors.negative));
      expect(color, isNot(AppColors.accent));
    }
  });
}
