import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/home/widgets/period_summary_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
          textDirection: TextDirection.rtl, child: Scaffold(body: child)),
    );

void main() {
  testWidgets('shows what is left, what was spent, and the safe daily figure',
      (tester) async {
    await tester.pumpWidget(_wrap(const PeriodSummaryCard(
      summary: PeriodSummary(
        salaryPiastres: 900000,
        spentPiastres: 8500,
        daysRemaining: 28,
      ),
    )));

    expect(find.text('8,915'), findsOneWidget);
    expect(find.text('85'), findsOneWidget);
    expect(find.textContaining('246'), findsOneWidget);
  });

  testWidgets('left figure turns red and hides safe daily when overspent',
      (tester) async {
    await tester.pumpWidget(_wrap(const PeriodSummaryCard(
      summary: PeriodSummary(
        salaryPiastres: 900000,
        spentPiastres: 969200,
        daysRemaining: 10,
      ),
    )));

    final leftText = tester.widget<Text>(find.text('-2,692'));
    expect(leftText.style?.color, AppColors.negative);
    expect(find.textContaining('في اليوم'), findsNothing);
  });
}
