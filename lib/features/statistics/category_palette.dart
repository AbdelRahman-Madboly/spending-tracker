import 'package:flutter/material.dart';

/// Ten perceptually distinct colours for categorical charts (pie slices,
/// legend rows).
///
/// Deliberately excludes both semantic colours used elsewhere in the app —
/// `AppColors.negative` (means "you are overspending") and
/// `AppColors.accent` (means "the primary action") — and keeps every entry
/// at least ~30° of hue away from both, so an arbitrary category can never
/// borrow a warning or call-to-action meaning it doesn't have. `positive`
/// is not excluded: nothing here assigns it a meaning that conflicts with
/// a category colour.
const categoryPalette = <Color>[
  Color(0xFF6E7580), // neutral slate grey — no hue to collide with anything
  Color(0xFF12784F), // teal-green (same as AppColors.positive)
  Color(0xFFB8B32E), // gold
  Color(0xFFE8A33D), // amber
  Color(0xFF8E5FD9), // violet
  Color(0xFF2FA9B0), // cyan-teal
  Color(0xFFD46FA6), // pink
  Color(0xFF6B8E23), // olive
  Color(0xFF34A630), // green
  Color(0xFFA843B1), // magenta
];

/// A stable colour for [categoryKey], derived from the key itself rather
/// than from spend rank — so a category (e.g. مواصلات) keeps the same
/// colour across every period and every screen, instead of whichever
/// colour happens to land on its rank that month.
Color colorForCategory(String categoryKey) {
  final hash =
      categoryKey.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);
  return categoryPalette[hash % categoryPalette.length];
}
