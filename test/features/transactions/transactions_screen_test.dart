import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/transactions/transactions_screen.dart';
import 'package:spending_tracker/features/transactions/widgets/entry_row.dart';

/// The fixture's entries are dated 5 and 6 September 2026.
DateTime _today() => DateTime(2026, 9, 6, 12);

Future<void> _pump(WidgetTester tester, {DateTime? initialDay}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: TransactionsScreen(
          repository: FixtureSpendingRepository(),
          clock: _today,
          initialDay: initialDay,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on today, titled اليوم, with its total and rows', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const Key('day-label')), findsOneWidget);
    expect(find.text('اليوم'), findsOneWidget);
    expect(find.byType(EntryRow), findsOneWidget);
    expect(find.text('لبن'), findsOneWidget);
    expect(find.byKey(const Key('day-total')), findsOneWidget);
  });

  testWidgets('the start-side button steps back a day, labelled أمس', (
    tester,
  ) async {
    await _pump(tester);
    final next = find.byKey(const Key('day-next'));
    // Nothing after today.
    expect(tester.widget<IconButton>(next).onPressed, isNull);

    await tester.tap(find.byKey(const Key('day-previous')));
    await tester.pumpAndSettle();
    expect(find.text('أمس'), findsOneWidget);
    expect(find.byType(EntryRow), findsWidgets);

    await tester.tap(find.byKey(const Key('day-previous')));
    await tester.pumpAndSettle();
    // Two days back: a full weekday and date.
    expect(find.text('الجمعة 4 سبتمبر'), findsOneWidget);
    expect(find.text('مفيش مصاريف في اليوم ده'), findsOneWidget);
  });

  testWidgets('initialDay opens on that day', (tester) async {
    await _pump(tester, initialDay: DateTime(2026, 9, 5));
    expect(find.text('أمس'), findsOneWidget);
  });
}
