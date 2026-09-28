import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/home/widgets/hero_card.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

const _current = PeriodSummary(
  salaryPiastres: 900000,
  spentPiastres: 8500,
  daysRemaining: 28,
  lengthDays: 30,
);

Color _fillColour(WidgetTester tester) {
  final box = tester.widget<Container>(find.byKey(const Key('budget-bar-fill')));
  return (box.decoration as BoxDecoration).color!;
}

List<Color> _gradient(WidgetTester tester) {
  final card = tester.widget<Container>(find.byKey(const Key('hero-card')));
  return ((card.decoration as BoxDecoration).gradient as LinearGradient).colors;
}

void main() {
  testWidgets('shows what is left, spent, safe daily, days left and percent',
      (tester) async {
    await tester.pumpWidget(_wrap(const HeroCard(summary: _current)));
    await tester.pumpAndSettle();

    expect(find.text('8,915'), findsOneWidget);
    expect(find.text('باقي'), findsOneWidget);
    expect(find.text('صرفت'), findsOneWidget);
    expect(find.text('85'), findsOneWidget);
    expect(find.text('تقدر تصرف/يوم'), findsOneWidget);
    expect(find.text('318.39'), findsOneWidget);
    expect(find.text('باقي 28 يوم'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(_gradient(tester), AppPalette.light.heroGradient);
    expect(_fillColour(tester), AppPalette.light.positive);
  });

  testWidgets('the card is radius 28 with 24 padding', (tester) async {
    await tester.pumpWidget(_wrap(const HeroCard(summary: _current)));
    final card = tester.widget<Container>(find.byKey(const Key('hero-card')));
    expect((card.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(28));
    expect(card.padding, const EdgeInsets.all(24));
  });

  testWidgets('the today tick sits at the share of the period gone by',
      (tester) async {
    await tester.pumpWidget(_wrap(const HeroCard(
      summary: PeriodSummary(
        salaryPiastres: 900000,
        spentPiastres: 0,
        daysRemaining: 15,
        lengthDays: 30,
      ),
    )));
    await tester.pumpAndSettle();
    final track = tester.getRect(find.byKey(const Key('budget-bar-track')));
    final tick = tester.getRect(find.byKey(const Key('budget-bar-tick')));
    // Right to left: half the period gone puts the tick in the middle.
    expect(tick.center.dx, closeTo(track.center.dx, 1.5));
    expect(tick.width, 2);
  });

  testWidgets('from 80% spent the bar turns to warning', (tester) async {
    await tester.pumpWidget(_wrap(const HeroCard(
      summary: PeriodSummary(
          salaryPiastres: 10000, spentPiastres: 8000, daysRemaining: 5),
    )));
    await tester.pumpAndSettle();
    expect(_fillColour(tester), AppPalette.light.warning);
  });

  testWidgets(
      'overspent switches to the negative gradient and hides safe daily',
      (tester) async {
    await tester.pumpWidget(_wrap(const HeroCard(
      summary: PeriodSummary(
          salaryPiastres: 10000, spentPiastres: 12000, daysRemaining: 5),
    )));
    await tester.pumpAndSettle();

    expect(find.text('-20'), findsOneWidget);
    expect(find.text('تقدر تصرف/يوم'), findsNothing);
    expect(_gradient(tester), AppPalette.light.heroGradientOverspent);
    expect(_fillColour(tester), AppPalette.light.negative);
  });

  testWidgets('a past period shows its final result and no safe daily',
      (tester) async {
    await tester.pumpWidget(_wrap(HeroCard(
      summary: PeriodSummary(
        salaryPiastres: 900000,
        spentPiastres: 850000,
        daysRemaining: 0,
        lengthDays: 31,
        start: DateTime(2026, 8, 4),
        end: DateTime(2026, 9, 3),
        isCurrent: false,
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('500'), findsOneWidget);
    expect(find.text('فترة منتهية'), findsOneWidget);
    expect(find.text('تقدر تصرف/يوم'), findsNothing);
    expect(find.byKey(const Key('budget-bar-tick')), findsNothing);
  });

  testWidgets('the figure counts up over 400ms', (tester) async {
    await tester.pumpWidget(_wrap(const HeroCard(summary: _current)));
    await tester.pump();
    expect(find.text('8,915'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('8,915'), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('8,915'), findsOneWidget);
  });

  testWidgets('with animations off the figure is final at once',
      (tester) async {
    await tester.pumpWidget(
        _wrap(const HeroCard(summary: _current), disableAnimations: true));
    await tester.pump();
    expect(find.text('8,915'), findsOneWidget);
  });
}
