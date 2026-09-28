import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/tokens.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('spacing is the spec 4-point scale with a 16 gutter and 24 sections',
      () {
    expect(
      [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.ms,
        AppSpacing.md,
        AppSpacing.ml,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ],
      [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0, 48.0],
    );
    expect(AppSpacing.gutter, 16.0);
    expect(AppSpacing.section, 24.0);
  });

  test('radii are 6 / 10 / 14 / 20 / 28 / full', () {
    expect(
      [AppRadii.xs, AppRadii.sm, AppRadii.md, AppRadii.lg, AppRadii.xl],
      [6.0, 10.0, 14.0, 20.0, 28.0],
    );
    expect(AppRadii.full, greaterThanOrEqualTo(999));
  });

  group('type scale', () {
    final styles = {
      'display': (AppText.display, 44.0, 52.0, FontWeight.w700),
      'headline': (AppText.headline, 24.0, 32.0, FontWeight.w700),
      'title': (AppText.title, 18.0, 26.0, FontWeight.w600),
      'body': (AppText.body, 16.0, 24.0, FontWeight.w400),
      'bodyStrong': (AppText.bodyStrong, 16.0, 24.0, FontWeight.w600),
      'label': (AppText.label, 14.0, 20.0, FontWeight.w500),
      'caption': (AppText.caption, 12.0, 16.0, FontWeight.w500),
    };
    for (final MapEntry(key: name, value: (style, size, line, weight))
        in styles.entries) {
      test('$name is $size/$line at $weight with tabular figures', () {
        expect(style.fontSize, size);
        expect(style.fontSize! * style.height!, closeTo(line, 0.001));
        expect(style.fontWeight, weight);
        expect(style.fontFeatures,
            contains(const FontFeature.tabularFigures()));
      });

      // Colour comes from the theme, so one style serves light and dark.
      test('$name carries no colour of its own', () {
        expect(style.color, isNull);
      });
    }
  });

  group('palette', () {
    test('light and dark hold the spec §7.1 values', () {
      const l = AppPalette.light;
      const d = AppPalette.dark;
      expect(l.brightness, Brightness.light);
      expect(d.brightness, Brightness.dark);

      expect(l.bg, const Color(0xFFF4F6FA));
      expect(l.surface, const Color(0xFFFFFFFF));
      expect(l.surfaceAlt, const Color(0xFFEDF0F6));
      expect(l.outline, const Color(0xFF8C93A1));
      expect(l.divider, const Color(0xFFE3E7EE));
      expect(l.textPrimary, const Color(0xFF14171F));
      expect(l.textSecondary, const Color(0xFF5B606B));
      expect(l.primary, const Color(0xFF2A4FA0));
      expect(l.onPrimary, const Color(0xFFFFFFFF));
      expect(l.primaryContainer, const Color(0xFFE3E9F7));
      expect(l.onPrimaryContainer, const Color(0xFF173064));
      expect(l.positive, const Color(0xFF12784F));
      expect(l.negative, const Color(0xFFC8233A));
      expect(l.warning, const Color(0xFF8A5300));
      expect(l.heroGradient,
          const [Color(0xFF2A4FA0), Color(0xFF1D3A80)]);
      expect(l.heroGradientOverspent,
          const [Color(0xFFC8233A), Color(0xFF9E1B2E)]);
      expect(l.heroSubtext, const Color(0xFFC9D5F5));

      expect(d.bg, const Color(0xFF0E1117));
      expect(d.surface, const Color(0xFF171B23));
      expect(d.surfaceAlt, const Color(0xFF1F2430));
      expect(d.outline, const Color(0xFF666E7D));
      expect(d.divider, const Color(0xFF262B36));
      expect(d.textPrimary, const Color(0xFFECEFF4));
      expect(d.textSecondary, const Color(0xFFA3A9B6));
      expect(d.primary, const Color(0xFF8FA9F2));
      expect(d.onPrimary, const Color(0xFF0E1A3D));
      expect(d.primaryContainer, const Color(0xFF22335E));
      expect(d.onPrimaryContainer, const Color(0xFFDCE4FB));
      expect(d.positive, const Color(0xFF4CC38A));
      expect(d.negative, const Color(0xFFFF6B7A));
      expect(d.warning, const Color(0xFFF2B04C));
      expect(d.heroGradient,
          const [Color(0xFF22335E), Color(0xFF1A2748)]);
      expect(d.heroGradientOverspent,
          const [Color(0xFFC8233A), Color(0xFF9E1B2E)]);
      expect(d.heroSubtext, const Color(0xFFB9C6EE));
    });

    for (final palette in [AppPalette.light, AppPalette.dark]) {
      final mode = palette.brightness.name;

      test('$mode: every text and status colour reads at 4.5:1 on the page '
          'and on cards', () {
        final inks = {
          'textPrimary': palette.textPrimary,
          'textSecondary': palette.textSecondary,
          'primary': palette.primary,
          'positive': palette.positive,
          'negative': palette.negative,
          'warning': palette.warning,
        };
        for (final MapEntry(key: name, value: ink) in inks.entries) {
          for (final ground in [palette.bg, palette.surface]) {
            expect(_contrast(ink, ground), greaterThanOrEqualTo(4.5),
                reason: '$mode $name on $ground');
          }
        }
        expect(_contrast(palette.onPrimary, palette.primary),
            greaterThanOrEqualTo(4.5));
        expect(
            _contrast(palette.onPrimaryContainer, palette.primaryContainer),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(palette.heroSubtext, palette.heroGradient.first),
            greaterThanOrEqualTo(4.5));
      });

      test('$mode: outline clears 3:1 on cards (non-text contrast)', () {
        expect(_contrast(palette.outline, palette.surface),
            greaterThanOrEqualTo(3));
      });
    }

    test('light cards cast the two-layer shadow and carry no border', () {
      expect(AppPalette.light.cardShadow, hasLength(2));
      expect(AppPalette.light.raisedShadow, hasLength(1));
      expect(AppPalette.light.cardBorder, BorderSide.none);
    });

    test('dark cards cast no shadow and get a 1px divider border', () {
      expect(AppPalette.dark.cardShadow, isEmpty);
      expect(AppPalette.dark.raisedShadow, isEmpty);
      expect(AppPalette.dark.cardBorder,
          const BorderSide(color: Color(0xFF262B36), width: 1));
    });

    test('lerp lands on either end', () {
      expect(AppPalette.light.lerp(AppPalette.dark, 1).bg, AppPalette.dark.bg);
      expect(
          AppPalette.light.lerp(AppPalette.dark, 0).bg, AppPalette.light.bg);
    });

    testWidgets(
        'AppPalette.of reads the theme extension, and falls back by '
        'brightness when a bare MaterialApp has none', (tester) async {
      late AppPalette fromExtension;
      late AppPalette fromBareDark;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.dark]),
        home: Builder(builder: (context) {
          fromExtension = AppPalette.of(context);
          return const SizedBox();
        }),
      ));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (context) {
          fromBareDark = context.palette;
          return const SizedBox();
        }),
      ));
      expect(fromExtension, same(AppPalette.dark));
      expect(fromBareDark, same(AppPalette.dark));
    });
  });
}
