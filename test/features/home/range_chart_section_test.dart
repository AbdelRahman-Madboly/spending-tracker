import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/home/widgets/range_chart_section.dart';
import 'package:spending_tracker/features/home/widgets/spending_bar_chart.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: RangeChartSection(repository: FixtureSpendingRepository()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sits in a titled card', (tester) async {
    await _pump(tester);
    expect(find.text('الصرف'), findsOneWidget);
  });

  for (final (label, count) in [('يوم', 7), ('أسبوع', 6), ('شهر', 6)]) {
    testWidgets(
      '$label: a dashed line traces the previous period at the same offset',
      (tester) async {
        await _pump(tester);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final chart = tester.widget<SpendingBarChart>(
          find.byType(SpendingBarChart),
        );
        expect(chart.points, hasLength(count));
        expect(chart.previous, hasLength(count));
        final paint = tester.widget<CustomPaint>(
          find.byKey(const Key('trend-previous')),
        );
        expect(
          paint.foregroundPainter ?? paint.painter,
          isA<PreviousPeriodPainter>(),
        );
      },
    );
  }

  test('the previous line is the window just before the shown one', () {
    // 14 days oldest first: the first seven are last week's.
    final totals = [
      for (var i = 1; i <= 14; i++) (label: '$i', totalPiastres: i * 100),
    ];
    final (shown, previous) = splitCurrentAndPrevious(totals, 7);
    expect(shown.map((p) => p.label), ['8', '9', '10', '11', '12', '13', '14']);
    expect(previous, [100, 200, 300, 400, 500, 600, 700]);
  });
}
