import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(find.byIcon(Icons.local_drink), findsOneWidget);
  });

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
