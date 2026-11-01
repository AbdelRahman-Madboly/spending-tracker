import 'package:flutter/painting.dart';

import 'tokens.dart';

/// One category colour: the ink used in each mode.
typedef CategoryInkPair = ({Color light, Color dark});

/// Category inks by `colorKey` (spec §7.2).
///
/// The key set matches `categoryColorKeys` in `lib/data/db/database.dart`,
/// which is what the database accepts. A category keeps its colour across
/// every screen and period because the colour belongs to the category row,
/// not to its rank in a chart. Every ink clears 4.5:1 on a card in its own
/// mode, so it is safe for a glyph or a short label, and none of them is the
/// palette's `negative`, which means "overspent".
const Map<String, CategoryInkPair> categoryInks = {
  'Drinks': (light: Color(0xFF0B72C4), dark: Color(0xFF6FB6F2)),
  'Snacks': (light: Color(0xFFC2410C), dark: Color(0xFFFB9A5B)),
  'Food': (light: Color(0xFFB45309), dark: Color(0xFFF2B04C)),
  'Transport': (light: Color(0xFF0F766E), dark: Color(0xFF4FD1C0)),
  'Bills': (light: Color(0xFF4F46E5), dark: Color(0xFFA5A8FF)),
  'Personal Care': (light: Color(0xFFBE185D), dark: Color(0xFFF48CBF)),
  'Shopping': (light: Color(0xFF7C3AED), dark: Color(0xFFC4A1FF)),
  'Family/Social': (light: Color(0xFF15803D), dark: Color(0xFF6FD68F)),
  'Gifts': (light: Color(0xFFC026D3), dark: Color(0xFFEE8CF7)),
  'Loans': (light: Color(0xFF57534E), dark: Color(0xFFC9C2BA)),
  'Health': (light: Color(0xFF0E7490), dark: Color(0xFF5CCBE6)),
  'Education': (light: Color(0xFFA16207), dark: Color(0xFFE8C54F)),
  'Home': (light: Color(0xFF4D7C0F), dark: Color(0xFFA3D95B)),
  'Other': (light: Color(0xFF475569), dark: Color(0xFFAEB8C7)),
};

/// Category colours resolved for the palette's mode.
extension CategoryColors on AppPalette {
  /// The ink for [colorKey]: glyphs, chart slices, the selected chip's
  /// border. An unknown key gets `Other`'s ink.
  Color categoryInk(String colorKey) {
    final pair = categoryInks[colorKey] ?? categoryInks['Other']!;
    return isDark ? pair.dark : pair.light;
  }

  /// The icon circle behind a category glyph: the ink at 12% in light mode
  /// and 20% in dark, where 12% all but vanishes on the dark surface.
  Color categoryInkFill(String colorKey) =>
      categoryInk(colorKey).withValues(alpha: isDark ? 0.20 : 0.12);

  /// A selected category chip's fill: the ink at 16% (spec §7.3).
  Color categoryChipFill(String colorKey) =>
      categoryInk(colorKey).withValues(alpha: 0.16);
}
