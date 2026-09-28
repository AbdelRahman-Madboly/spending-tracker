import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';

void main() {
  for (final (brightness, palette) in [
    (Brightness.light, AppPalette.light),
    (Brightness.dark, AppPalette.dark),
  ]) {
    group('${brightness.name} theme', () {
      final theme = buildAppTheme(brightness);

      test('carries its palette as an extension', () {
        expect(theme.brightness, brightness);
        expect(theme.extension<AppPalette>(), same(palette));
      });

      test('builds its colour scheme from the palette so Material 3 '
          'defaults never leak through', () {
        final scheme = theme.colorScheme;
        expect(scheme.brightness, brightness);
        expect(scheme.primary, palette.primary);
        expect(scheme.onPrimary, palette.onPrimary);
        expect(scheme.primaryContainer, palette.primaryContainer);
        expect(scheme.onPrimaryContainer, palette.onPrimaryContainer);
        expect(scheme.surface, palette.surface);
        expect(scheme.onSurface, palette.textPrimary);
        expect(scheme.onSurfaceVariant, palette.textSecondary);
        expect(scheme.outline, palette.outline);
        expect(scheme.outlineVariant, palette.divider);
        expect(scheme.error, palette.negative);
        // SegmentedButton paints its selected segment with
        // secondaryContainer; the M3 default is teal.
        expect(scheme.secondaryContainer, palette.primaryContainer);
        expect(scheme.onSecondaryContainer, palette.onPrimaryContainer);
        expect(theme.scaffoldBackgroundColor, palette.bg);
        expect(theme.dividerColor, palette.divider);
      });

      test('turns the surface tint off', () {
        expect(theme.colorScheme.surfaceTint, Colors.transparent);
        expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
        expect(theme.appBarTheme.backgroundColor, palette.bg);
      });

      test('sets text in IBM Plex Sans Arabic in the primary text colour', () {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'IBMPlexSansArabic');
        expect(theme.textTheme.bodyMedium?.color, palette.textPrimary);
        expect(theme.textTheme.bodySmall?.color, palette.textSecondary);
      });

      test('draws icons outlined at weight 400', () {
        expect(theme.iconTheme.fill, 0);
        expect(theme.iconTheme.weight, 400);
        expect(theme.iconTheme.color, palette.textPrimary);
      });

      test('keeps every button at a 48dp minimum', () {
        for (final style in [
          theme.filledButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
        ]) {
          expect(style?.minimumSize?.resolve({})?.height, 48);
        }
      });
    });
  }

  group('ThemeModeController', () {
    test('follows the system until a mode is stored', () async {
      final controller =
          ThemeModeController(FixtureSpendingRepository());
      await controller.load();
      expect(controller.value, ThemeMode.system);
    });

    test('loads a stored mode from app_settings', () async {
      final repository = FixtureSpendingRepository();
      await repository.setSetting(themeModeSettingKey, 'dark');
      final controller = ThemeModeController(repository);
      await controller.load();
      expect(controller.value, ThemeMode.dark);
    });

    test('an unreadable stored value falls back to the system', () async {
      final repository = FixtureSpendingRepository();
      await repository.setSetting(themeModeSettingKey, 'purple');
      final controller = ThemeModeController(repository);
      await controller.load();
      expect(controller.value, ThemeMode.system);
    });

    test('choosing a mode applies it at once and stores it', () async {
      final repository = FixtureSpendingRepository();
      final controller = ThemeModeController(repository);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.select(ThemeMode.light);

      expect(controller.value, ThemeMode.light);
      expect(notified, 1);
      expect(await repository.setting(themeModeSettingKey), 'light');
    });
  });
}
