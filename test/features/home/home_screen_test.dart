import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/home/home_screen.dart';
import 'package:spending_tracker/features/home/widgets/month_comparison_card.dart';
import 'package:spending_tracker/features/settings/settings_screen.dart';
import 'package:spending_tracker/features/statistics/statistics_screen.dart';

void main() {
  testWidgets(
      'renders the summary, month comparison, chart, today list and a '
      'single add button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(repository: FixtureSpendingRepository()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('8,915'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(MonthComparisonCard), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);

    // The month stats push today's entries below the fold on a small test
    // surface; scroll the list into view rather than assuming it fits.
    await tester.scrollUntilVisible(find.text('لبن'), 200);
    expect(find.text('لبن'), findsOneWidget);
  });

  testWidgets('tapping the monthly chart opens the statistics screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(repository: FixtureSpendingRepository()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BarChart));
    await tester.pumpAndSettle();

    expect(find.byType(StatisticsScreen), findsOneWidget);
  });

  testWidgets('tapping the gear icon beside the chart icon opens settings',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(repository: FixtureSpendingRepository()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    expect(find.byKey(const Key('settings-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
