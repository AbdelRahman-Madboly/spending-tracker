import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/features/home/widgets/month_comparison_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
          textDirection: TextDirection.rtl, child: Scaffold(body: child)),
    );

void main() {
  testWidgets('shows both months with their labels and totals',
      (tester) async {
    await tester.pumpWidget(_wrap(const MonthComparisonCard(
      thisMonthPiastres: 500000,
      lastMonthPiastres: 400000,
    )));

    expect(find.text('الشهر ده'), findsOneWidget);
    expect(find.text('الشهر اللي فات'), findsOneWidget);
    expect(find.text('5,000'), findsOneWidget);
    expect(find.text('4,000'), findsOneWidget);
  });

  testWidgets(
      'this month higher than last renders the difference in the negative '
      'colour, as a signed increase', (tester) async {
    await tester.pumpWidget(_wrap(const MonthComparisonCard(
      thisMonthPiastres: 500000,
      lastMonthPiastres: 400000,
    )));

    final diff = tester.widget<Text>(find.text('+1,000'));
    expect(diff.style?.color, AppPalette.light.negative);
  });

  testWidgets(
      'this month lower than last renders the difference in the positive '
      'colour', (tester) async {
    await tester.pumpWidget(_wrap(const MonthComparisonCard(
      thisMonthPiastres: 300000,
      lastMonthPiastres: 400000,
    )));

    final diff = tester.widget<Text>(find.text('-1,000'));
    expect(diff.style?.color, AppPalette.light.positive);
  });

  testWidgets('equal months render the difference in a neutral colour',
      (tester) async {
    await tester.pumpWidget(_wrap(const MonthComparisonCard(
      thisMonthPiastres: 400000,
      lastMonthPiastres: 400000,
    )));

    final diff = tester.widget<Text>(find.text('0'));
    expect(diff.style?.color, AppPalette.light.textSecondary);
  });

  testWidgets('in dark mode the difference takes the dark palette colour',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.dark),
      home: const Scaffold(
        body: MonthComparisonCard(
          thisMonthPiastres: 500000,
          lastMonthPiastres: 400000,
        ),
      ),
    ));

    final diff = tester.widget<Text>(find.text('+1,000'));
    expect(diff.style?.color, AppPalette.dark.negative);
    final card = tester.widget<Material>(find
        .descendant(
            of: find.byType(MonthComparisonCard),
            matching: find.byType(Material))
        .first);
    expect(card.color, AppPalette.dark.surface);
  });

  testWidgets('tapping the card invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(MonthComparisonCard(
      thisMonthPiastres: 500000,
      lastMonthPiastres: 400000,
      onTap: () => tapped = true,
    )));

    await tester.tap(find.byType(MonthComparisonCard));
    expect(tapped, isTrue);
  });
}
