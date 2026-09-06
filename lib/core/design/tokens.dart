import 'package:flutter/material.dart';

/// Semantic colour palette for the app.
///
/// Grounded in Monekin's (https://github.com/enrique-lozano/Monekin) light
/// theme conventions — a softly tinted page background sitting just behind
/// near-white card surfaces, a dark neutral for body text, and a navy brand
/// accent — adapted for a single-screen "money left" hero number that must
/// read clearly at very large sizes and switch to an unmistakable warning
/// colour when the user has overspent.
abstract final class AppColors {
  /// Page background: a very soft, cool off-white with a whisper of the
  /// accent's hue, so cards visually lift off it.
  static const background = Color(0xFFF4F6FA);

  /// Card/surface background: near-white, one step lighter than
  /// [background], matching Monekin's pattern of surfaces reading brighter
  /// than the page behind them.
  static const surface = Color(0xFFFFFFFF);

  /// Primary text colour, including the hero "money left" number. Deep,
  /// near-black charcoal for maximum legibility at both caption and
  /// display sizes (15.4:1 contrast on [background]).
  static const textPrimary = Color(0xFF1C1E21);

  /// Secondary text colour for supporting labels and captions. A cool mid
  /// grey close to Monekin's hint colour, tuned to still clear 4.5:1
  /// contrast at small sizes (4.7:1 on [background]).
  static const textSecondary = Color(0xFF6B6E76);

  /// Positive balance / income colour. A deep, blue-shifted teal-green
  /// (not a pure grass green) so it stays visually distinct from
  /// [negative] for red-green colour-vision deficiencies, both in hue and
  /// in lightness.
  static const positive = Color(0xFF12784F);

  /// Negative balance / overspend colour. A saturated, alarm-grade
  /// crimson-red — noticeably lighter and warmer than [positive] — chosen
  /// to still read as a genuine warning when set at hero display sizes
  /// (56pt+), not just in a small badge.
  static const negative = Color(0xFFD7263D);

  /// Interactive accent (buttons, links, selected states). A rich indigo
  /// blue in the spirit of Monekin's navy brand colour, kept light enough
  /// to work as an interactive surface rather than a heavy hero colour.
  static const accent = Color(0xFF2A4FA0);
}

/// 4pt spacing scale used for all padding, gaps and margins.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Type styles. All money-bearing styles enable tabular figures so digit
/// columns line up — required because the app displays money with Latin
/// digits in an Arabic, RTL, IBM Plex Sans Arabic interface.
abstract final class AppText {
  static const _tabular = [FontFeature.tabularFigures()];

  /// The single enormous "money left until next salary" number. Rendered
  /// in [AppColors.textPrimary] normally and [AppColors.negative] when
  /// overspent.
  static const hero = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    fontFeatures: _tabular,
  );
}
