import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/home/home_screen.dart';

void main() {
  testWidgets('renders the summary, today list and a single add button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(repository: FixtureSpendingRepository()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('8,915'), findsOneWidget);
    expect(find.text('لبن'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
