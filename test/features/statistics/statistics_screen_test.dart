import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/statistics/statistics_screen.dart';

void main() {
  testWidgets('lists each category with its total', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: StatisticsScreen(repository: FixtureSpendingRepository()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Food/Social'), findsOneWidget);
    expect(find.text('85'), findsOneWidget);
  });
}
