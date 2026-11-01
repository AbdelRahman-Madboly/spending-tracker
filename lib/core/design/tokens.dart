import 'package:flutter/material.dart';

/// The app's colour tokens (spec §7.1), one instance per brightness.
///
/// Carried on [ThemeData.extensions] rather than exposed as static
/// constants, so every widget reads the colours of the mode it is actually
/// rendered in: a static `AppColors.surface` would stay white in dark mode.
/// Read them through [AppPalette.of] or `context.palette`.
///
/// Every text and status colour clears 4.5:1 on both [bg] and [surface] in
/// both modes (asserted in `tokens_test.dart`), so any of them is safe for
/// small text on the page or on a card.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Brightness brightness;

  /// Page background, one step behind [surface] so cards lift off it.
  final Color bg;
  final Color surface;

  /// Inset areas inside a card: fields, secondary chips, tracks.
  final Color surfaceAlt;
  final Color outline;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Under budget, spending less than last month.
  final Color positive;

  /// Overspent, spending more than last month, destructive actions.
  final Color negative;

  /// The budget bar from 80% on.
  final Color warning;

  /// The dashboard hero card's two gradient stops, start to end.
  final List<Color> heroGradient;

  /// The hero gradient once the period is overspent. The same red in both
  /// modes: it has to read as an alarm, not as a themed surface.
  final List<Color> heroGradientOverspent;

  /// Secondary text on the hero gradient.
  final Color heroSubtext;

  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.heroGradient,
    required this.heroGradientOverspent,
    required this.heroSubtext,
  });

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDF0F6),
    outline: Color(0xFF8C93A1),
    divider: Color(0xFFE3E7EE),
    textPrimary: Color(0xFF14171F),
    textSecondary: Color(0xFF5B606B),
    primary: Color(0xFF2A4FA0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3E9F7),
    onPrimaryContainer: Color(0xFF173064),
    positive: Color(0xFF12784F),
    negative: Color(0xFFC8233A),
    warning: Color(0xFF8A5300),
    heroGradient: [Color(0xFF2A4FA0), Color(0xFF1D3A80)],
    heroGradientOverspent: [Color(0xFFC8233A), Color(0xFF9E1B2E)],
    heroSubtext: Color(0xFFC9D5F5),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E1117),
    surface: Color(0xFF171B23),
    surfaceAlt: Color(0xFF1F2430),
    outline: Color(0xFF666E7D),
    divider: Color(0xFF262B36),
    textPrimary: Color(0xFFECEFF4),
    textSecondary: Color(0xFFA3A9B6),
    primary: Color(0xFF8FA9F2),
    onPrimary: Color(0xFF0E1A3D),
    primaryContainer: Color(0xFF22335E),
    onPrimaryContainer: Color(0xFFDCE4FB),
    positive: Color(0xFF4CC38A),
    negative: Color(0xFFFF6B7A),
    warning: Color(0xFFF2B04C),
    heroGradient: [Color(0xFF22335E), Color(0xFF1A2748)],
    heroGradientOverspent: [Color(0xFFC8233A), Color(0xFF9E1B2E)],
    heroSubtext: Color(0xFFB9C6EE),
  );

  /// The palette of the nearest theme. A theme without the extension (a
  /// bare `MaterialApp` in a widget test) gets the palette matching its
  /// brightness, so a widget never has to handle a missing palette.
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  bool get isDark => brightness == Brightness.dark;

  /// Primary text, icons and the today tick on the hero gradient. White in
  /// both modes: the hero gradient is dark in both, so this is the one
  /// colour that is the same whichever mode is on.
  Color get onHero => const Color(0xFFFFFFFF);

  /// Elevation level 1 (cards). Light mode lifts cards with a soft
  /// two-layer shadow; dark mode has no shadows at all, because a shadow
  /// on a near-black page is invisible, and outlines cards with
  /// [cardBorder] instead.
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(
              color: Color(0x0F000000), offset: Offset(0, 1), blurRadius: 2),
          BoxShadow(
              color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 12),
        ];

  /// Elevation level 2 (sheets, the FAB, anything floating over cards).
  List<BoxShadow> get raisedShadow => isDark
      ? const []
      : const [
          BoxShadow(
              color: Color(0x1F000000), offset: Offset(0, 8), blurRadius: 24),
        ];

  /// The card edge: none in light mode, a 1px [divider] line in dark mode.
  BorderSide get cardBorder =>
      isDark ? BorderSide(color: divider, width: 1) : BorderSide.none;

  @override
  AppPalette copyWith() => this;

  /// Theme animations cross-fade between modes; brightness snaps at the
  /// midpoint so the shadow/border rule never mixes.
  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> g(List<Color> a, List<Color> b) =>
        [for (var i = 0; i < a.length; i++) c(a[i], b[i])];
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      outline: c(outline, other.outline),
      divider: c(divider, other.divider),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      onPrimaryContainer: c(onPrimaryContainer, other.onPrimaryContainer),
      positive: c(positive, other.positive),
      negative: c(negative, other.negative),
      warning: c(warning, other.warning),
      heroGradient: g(heroGradient, other.heroGradient),
      heroGradientOverspent:
          g(heroGradientOverspent, other.heroGradientOverspent),
      heroSubtext: c(heroSubtext, other.heroSubtext),
    );
  }
}

/// `context.palette` is shorthand for [AppPalette.of].
extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}

/// 4-point spacing scale used for all padding, gaps and margins.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double ms = 12;
  static const double md = 16;
  static const double ml = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Screen edge padding.
  static const double gutter = md;

  /// Gap between dashboard/list sections.
  static const double section = lg;
}

/// Corner radii. [xl] is the hero card, [full] a pill or circle.
abstract final class AppRadii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double full = 999;
}

/// Type styles (spec §7.1), IBM Plex Sans Arabic via the theme.
///
/// None of them sets a colour: text takes the theme's `textPrimary` by
/// default, so one style serves both modes, and a caller wanting secondary
/// text writes `copyWith(color: context.palette.textSecondary)`.
///
/// Every style enables tabular figures, not only the money ones, because
/// amounts turn up inside body and caption text too ("صرفت 85 من 9,000")
/// and their digit columns should still line up.
abstract final class AppText {
  static const _tabular = [FontFeature.tabularFigures()];

  /// The dashboard's single large figure.
  static const display = TextStyle(
    fontSize: 44,
    height: 52 / 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );

  static const headline = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  static const title = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    fontFeatures: _tabular,
  );

  static const bodyStrong = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  static const label = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );
}

/// Motion tokens (spec §7.3). Exits run on [exit], entries on [enter].
///
/// Every animated widget reads its duration through [of], so turning on the
/// system's "remove animations" setting drops all of them to zero at once.
abstract final class AppMotion {
  static const press = Duration(milliseconds: 120);
  static const chip = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 280);

  /// The hero figure's count-up, and nothing else.
  static const countUp = Duration(milliseconds: 400);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// [duration], or zero when the platform asks for no animations.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : duration;
}
