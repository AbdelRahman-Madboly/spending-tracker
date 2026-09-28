import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';
import 'package:spending_tracker/features/home/home_screen.dart';
import 'package:spending_tracker/features/settings/settings_screen.dart';
import 'package:spending_tracker/features/shell/app_shell.dart';
import 'package:spending_tracker/features/statistics/statistics_screen.dart';

/// Colours a widget has set explicitly on text, icons and boxes. Colours
/// inherited from the theme aren't listed: they are right by construction.
Set<Color> _explicitColours(WidgetTester tester) => {
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        ?t.style?.color,
      for (final i in tester.widgetList<Icon>(find.byType(Icon))) ?i.color,
      for (final c in tester.widgetList<Container>(find.byType(Container)))
        ?c.color,
      for (final c in tester.widgetList<Container>(find.byType(Container)))
        if (c.decoration case BoxDecoration(:final color?)) color,
      for (final m in tester.widgetList<Material>(find.byType(Material)))
        ?m.color,
    };

/// Tokens whose value differs between the modes, so one showing up in the
/// other mode means a widget read a hard-coded colour instead of the theme.
Set<Color> _modeOnly(AppPalette mine, AppPalette other) {
  final theirs = {
    other.bg,
    other.surface,
    other.surfaceAlt,
    other.textPrimary,
    other.textSecondary,
    other.primary,
    other.positive,
    other.negative,
  };
  final ours = {
    mine.bg,
    mine.surface,
    mine.surfaceAlt,
    mine.textPrimary,
    mine.textSecondary,
    mine.primary,
    mine.positive,
    mine.negative,
    // The hero is dark in both modes, so its text is white in both.
    mine.onHero,
  };
  return theirs.difference(ours);
}

void main() {
  final screens = <String, Widget Function(FixtureSpendingRepository)>{
    'shell': (r) => AppShell(repository: r),
    'home': (r) => HomeScreen(repository: r),
    'statistics': (r) => StatisticsScreen(repository: r),
    'settings': (r) => SettingsScreen(repository: r),
    'add sheet': (r) =>
        Scaffold(body: AddSheet(repository: r, onSubmit: (_) {})),
  };

  for (final (brightness, palette, other) in [
    (Brightness.light, AppPalette.light, AppPalette.dark),
    (Brightness.dark, AppPalette.dark, AppPalette.light),
  ]) {
    for (final MapEntry(key: name, value: build) in screens.entries) {
      testWidgets(
          '$name renders in ${brightness.name} mode on its own palette only',
          (tester) async {
        tester.view.physicalSize = const Size(1080, 4800);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(brightness),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: build(FixtureSpendingRepository()),
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(Scaffold).first);
        expect(Theme.of(context).scaffoldBackgroundColor, palette.bg);
        expect(
          _explicitColours(tester).intersection(_modeOnly(palette, other)),
          isEmpty,
        );
      });
    }
  }
}
