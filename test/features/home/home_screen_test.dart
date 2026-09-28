import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_icons.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/home/home_screen.dart';
import 'package:spending_tracker/features/home/widgets/month_comparison_card.dart';
import 'package:spending_tracker/features/settings/settings_screen.dart';
import 'package:spending_tracker/features/statistics/statistics_screen.dart';

void main() {
  testWidgets(
      'renders the summary, month comparison, chart, add button and a '
      'category breakdown for the current period', (tester) async {
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

    // The fixture's spending is Food 4500 (لبن 3500 + إندومي 1000) and
    // Drinks 4000 (شويبس), so the breakdown must show both categories,
    // Food first (higher total), each with its own total rather than a
    // per-entry list. The segmented range control now pushes this section
    // below the fold on a small test surface, same as the old per-entry
    // list did — scroll it into view rather than assuming it fits.
    await tester.scrollUntilVisible(find.text('الأقسام'), 200);
    expect(find.text('الأقسام'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('أكل'), 200);
    expect(find.text('أكل'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('مشروبات'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
  });

  test('no widget under lib/features/home hard-codes a 2026 date', () {
    final dir = Directory('lib/features/home');
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final content = entity.readAsStringSync();
        if (content.contains('DateTime(2026')) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'hard-coded 2026 date(s) found in: $offenders');
  });

  testWidgets('tapping the monthly chart opens the statistics screen',
      (tester) async {
    // Tall enough that the chart never lands underneath the FAB's fixed
    // screen position — the segmented range control above it pushes it low
    // enough on the default small test surface that a tap there can hit
    // the FAB instead of the chart.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

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

    expect(find.byIcon(AppIcons.stats), findsOneWidget);
    expect(find.byKey(const Key('settings-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
