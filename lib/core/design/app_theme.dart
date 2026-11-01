import 'package:flutter/material.dart';

import '../../domain/spending_repository.dart';
import 'tokens.dart';

/// The app's [ThemeData] for [brightness], built from [AppPalette].
///
/// Every button style sets a 48dp-tall minimum tap target at the theme
/// level, not per button, so any `FilledButton`, `OutlinedButton` or
/// `TextButton` added anywhere clears the floor without a `style:` override.
///
/// The [ColorScheme] is spelled out from the palette rather than seeded:
/// a seed would derive its own tones, and Material 3's stock purple and
/// teal would show up in buttons, AppBars and segmented controls whatever
/// individual widgets pass as their own colours.
ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final palette =
      brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  const minimumTapTarget = Size(64, 48);

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    primaryContainer: palette.primaryContainer,
    onPrimaryContainer: palette.onPrimaryContainer,
    // SegmentedButton paints its selected segment with secondaryContainer.
    // Left at the Material 3 default it renders teal, which reads as a
    // different app from the indigo primary used everywhere else.
    secondary: palette.primary,
    onSecondary: palette.onPrimary,
    secondaryContainer: palette.primaryContainer,
    onSecondaryContainer: palette.onPrimaryContainer,
    error: palette.negative,
    onError: palette.isDark ? palette.bg : Colors.white,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    surfaceContainerLowest: palette.surface,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surface,
    surfaceContainerHigh: palette.surface,
    surfaceContainerHighest: palette.surfaceAlt,
    outline: palette.outline,
    outlineVariant: palette.divider,
    // Material 3 tints raised surfaces (AppBar under scrolled content,
    // cards, dialogs) with a wash of the primary. The spec wants flat
    // surfaces in both modes.
    surfaceTint: Colors.transparent,
  );

  const fontFamily = 'IBMPlexSansArabic';
  final textTheme = Typography.material2021(
    platform: TargetPlatform.android,
    colorScheme: colorScheme,
  ).englishLike.merge(_textThemeFromTokens()).apply(
        fontFamily: fontFamily,
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: [palette],
    fontFamily: fontFamily,
    // bodySmall is the caption slot, which is secondary text.
    textTheme: textTheme.copyWith(
      bodySmall: textTheme.bodySmall?.copyWith(color: palette.textSecondary),
    ),
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    dividerColor: palette.divider,
    dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
    iconTheme: IconThemeData(
      color: palette.textPrimary,
      size: 24,
      fill: 0,
      weight: 400,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bg,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: palette.cardBorder,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.primary,
      foregroundColor: palette.onPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: minimumTapTarget),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: minimumTapTarget),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: minimumTapTarget),
    ),
  );
}

/// Maps [AppText] onto the Material slots, so stock widgets (list tiles,
/// dialogs, text fields) use the spec's type scale too.
TextTheme _textThemeFromTokens() => const TextTheme(
      displayLarge: AppText.display,
      headlineMedium: AppText.headline,
      titleLarge: AppText.title,
      titleMedium: AppText.bodyStrong,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      labelLarge: AppText.label,
      bodySmall: AppText.caption,
      labelSmall: AppText.caption,
    );

/// The `app_settings` key holding the chosen theme mode: `system`, `light`
/// or `dark`.
const themeModeSettingKey = 'theme_mode';

/// The app's theme mode: follows the system until the user picks one in
/// Settings, then remembers the choice in `app_settings`.
class ThemeModeController extends ValueNotifier<ThemeMode> {
  final SpendingRepository _repository;

  ThemeModeController(this._repository) : super(ThemeMode.system);

  /// Reads the stored choice. Anything missing or unrecognised means
  /// "follow the system", the safe default for a value the app can't read.
  Future<void> load() async {
    final stored = await _repository.setting(themeModeSettingKey);
    value = ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  /// Applies [mode] immediately, then stores it.
  Future<void> select(ThemeMode mode) async {
    value = mode;
    await _repository.setSetting(themeModeSettingKey, mode.name);
  }
}

/// Makes the app's [ThemeModeController] reachable from Settings without
/// threading it through every screen constructor on the way there.
class ThemeModeScope extends InheritedNotifier<ThemeModeController> {
  const ThemeModeScope({
    super.key,
    required ThemeModeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller above [context], or null outside the app (a screen
  /// pumped on its own in a test), where there is no mode to change.
  static ThemeModeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>()?.notifier;
}
