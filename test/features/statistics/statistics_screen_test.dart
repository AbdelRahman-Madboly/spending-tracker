import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_icons.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/core/design/category_colors.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/statistics/statistics_screen.dart';

void main() {
  testWidgets(
      'lists each category with its Arabic label, icon and total - not the '
      'raw English key', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: StatisticsScreen(repository: FixtureSpendingRepository()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('أكل'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('مشروبات'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);

    expect(find.text('Food'), findsNothing);
    expect(find.text('Drinks'), findsNothing);

    expect(find.byIcon(iconFor('restaurant')), findsOneWidget);
    expect(find.byIcon(iconFor('local_drink')), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'colours each ${brightness.name}-mode slice and glyph with its '
        "category's colorKey ink", (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(brightness),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: StatisticsScreen(repository: FixtureSpendingRepository()),
        ),
      ));
      await tester.pumpAndSettle();

      final palette = brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light;
      final slices =
          tester.widget<PieChart>(find.byType(PieChart)).data.sections;
      expect(
        slices.map((s) => s.color).toSet(),
        {palette.categoryInk('Food'), palette.categoryInk('Drinks')},
      );
      final foodGlyph =
          tester.widget<Icon>(find.byIcon(iconFor('restaurant')));
      expect(foodGlyph.color, palette.categoryInk('Food'));
    });
  }

  testWidgets('shows a category breakdown pie chart above the list',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: StatisticsScreen(repository: FixtureSpendingRepository()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);
  });
}
