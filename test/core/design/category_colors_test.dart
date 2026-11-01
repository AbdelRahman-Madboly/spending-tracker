import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/category_colors.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/data/db/database.dart';

void main() {
  test('every colour key the database can hold has an ink, and no more', () {
    expect(categoryInks.keys.toSet(), categoryColorKeys.toSet());
  });

  test('inks hold the spec §7.2 values', () {
    const expected = {
      'Drinks': (0xFF0B72C4, 0xFF6FB6F2),
      'Snacks': (0xFFC2410C, 0xFFFB9A5B),
      'Food': (0xFFB45309, 0xFFF2B04C),
      'Transport': (0xFF0F766E, 0xFF4FD1C0),
      'Bills': (0xFF4F46E5, 0xFFA5A8FF),
      'Personal Care': (0xFFBE185D, 0xFFF48CBF),
      'Shopping': (0xFF7C3AED, 0xFFC4A1FF),
      'Family/Social': (0xFF15803D, 0xFF6FD68F),
      'Gifts': (0xFFC026D3, 0xFFEE8CF7),
      'Loans': (0xFF57534E, 0xFFC9C2BA),
      'Health': (0xFF0E7490, 0xFF5CCBE6),
      'Education': (0xFFA16207, 0xFFE8C54F),
      'Home': (0xFF4D7C0F, 0xFFA3D95B),
      'Other': (0xFF475569, 0xFFAEB8C7),
    };
    for (final MapEntry(key: key, value: (light, dark)) in expected.entries) {
      expect(AppPalette.light.categoryInk(key), Color(light), reason: key);
      expect(AppPalette.dark.categoryInk(key), Color(dark), reason: key);
    }
  });

  test('an unknown or legacy colour key falls back to Other', () {
    expect(AppPalette.light.categoryInk('Nope'),
        AppPalette.light.categoryInk('Other'));
    expect(AppPalette.dark.categoryInk(''),
        AppPalette.dark.categoryInk('Other'));
  });

  test('the icon circle is the ink at 12% in light and 20% in dark', () {
    final light = AppPalette.light.categoryInkFill('Food');
    final dark = AppPalette.dark.categoryInkFill('Food');
    expect(light.a, closeTo(0.12, 0.005));
    expect(dark.a, closeTo(0.20, 0.005));
    expect(light.withValues(alpha: 1), AppPalette.light.categoryInk('Food'));
    expect(dark.withValues(alpha: 1), AppPalette.dark.categoryInk('Food'));
  });

  test('a selected chip is filled with the ink at 16%', () {
    expect(AppPalette.light.categoryChipFill('Bills').a, closeTo(0.16, 0.005));
    expect(AppPalette.dark.categoryChipFill('Bills').a, closeTo(0.16, 0.005));
  });

  test('every ink reads at 4.5:1 on a card in its own mode', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return la > lb ? (la + .05) / (lb + .05) : (lb + .05) / (la + .05);
    }

    for (final palette in [AppPalette.light, AppPalette.dark]) {
      for (final key in categoryColorKeys) {
        expect(contrast(palette.categoryInk(key), palette.surface),
            greaterThanOrEqualTo(4.5),
            reason: '${palette.brightness.name} $key');
      }
    }
  });

  test('no category ink borrows the negative colour, which means overspent',
      () {
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      for (final key in categoryColorKeys) {
        expect(palette.categoryInk(key), isNot(palette.negative));
      }
    }
  });
}
