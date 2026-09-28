import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/home/home_screen.dart';
import 'package:spending_tracker/features/home/widgets/capture_bar.dart';
import 'package:spending_tracker/features/home/widgets/range_chart_section.dart';

/// The fixture's frozen "today": its entries are dated 5 and 6 September.
DateTime _fixtureToday() => DateTime(2026, 9, 6, 12);

class _Calls {
  int adds = 0;
  int statistics = 0;
  final captures = <CaptureAction>[];
  final transactionDays = <DateTime>[];
  final drafts = <CaptureGroupView>[];
}

Future<_Calls> _pump(
  WidgetTester tester,
  FixtureSpendingRepository repository, {
  DateTime Function() clock = _fixtureToday,
}) async {
  // A tall phone, so every section is laid out without scrolling.
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: HomeScreen(
        repository: repository,
        clock: clock,
        onAdd: () => calls.adds++,
        onCapture: calls.captures.add,
        onOpenStatistics: () => calls.statistics++,
        onOpenTransactions: calls.transactionDays.add,
        onOpenDraft: calls.drafts.add,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets(
      'lays out the period header, hero, capture bar, today, trend and top '
      'categories in order', (tester) async {
    await _pump(tester, FixtureSpendingRepository());

    expect(find.text('4 سبتمبر – 3 أكتوبر'), findsOneWidget);
    expect(find.byKey(const Key('hero-card')), findsOneWidget);
    expect(find.text('8,915'), findsOneWidget);
    expect(find.byType(CaptureBar), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);

    double y(Finder f) => tester.getTopLeft(f).dy;
    final order = [
      find.byKey(const Key('period-header')),
      find.byKey(const Key('hero-card')),
      find.byType(CaptureBar),
      find.byKey(const Key('today-section')),
      find.byKey(const Key('trend-section')),
      find.byKey(const Key('top-categories-section')),
    ];
    for (var i = 1; i < order.length; i++) {
      expect(y(order[i]), greaterThan(y(order[i - 1])));
    }
    // No donut on the dashboard (spec §4.2).
    expect(find.byType(PieChart), findsNothing);
  });

  testWidgets('needs review and upcoming bills stay hidden when empty',
      (tester) async {
    await _pump(tester, FixtureSpendingRepository());
    expect(find.byKey(const Key('needs-review-section')), findsNothing);
    expect(find.byKey(const Key('upcoming-bills-section')), findsNothing);
  });

  testWidgets('the ‹ › buttons move between salary periods', (tester) async {
    await _pump(tester, FixtureSpendingRepository());
    final next = find.byKey(const Key('period-next'));
    expect(tester.widget<IconButton>(next).onPressed, isNull);

    await tester.tap(find.byKey(const Key('period-previous')));
    await tester.pumpAndSettle();
    expect(find.text('4 أغسطس – 3 سبتمبر'), findsOneWidget);
    expect(find.text('فترة منتهية'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('period-previous')))
            .onPressed,
        isNull);

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('4 سبتمبر – 3 أكتوبر'), findsOneWidget);
  });

  testWidgets('a horizontal swipe on the hero moves to the previous period',
      (tester) async {
    await _pump(tester, FixtureSpendingRepository());
    // Right to left: the finger moving toward the end side (left) goes
    // back in time, as the › start-side button does.
    await tester.fling(
        find.byKey(const Key('hero-card')), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('4 أغسطس – 3 سبتمبر'), findsOneWidget);

    await tester.fling(
        find.byKey(const Key('hero-card')), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('4 سبتمبر – 3 أكتوبر'), findsOneWidget);
  });

  testWidgets('today shows its total, count and last three entries',
      (tester) async {
    final calls = await _pump(tester, FixtureSpendingRepository());
    final today = find.byKey(const Key('today-section'));
    expect(find.descendant(of: today, matching: find.text('لبن')),
        findsOneWidget);
    expect(find.descendant(of: today, matching: find.text('35')),
        findsWidgets);
    expect(find.descendant(of: today, matching: find.text('1 مصروف')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('today-see-all')));
    expect(calls.transactionDays.single, DateTime(2026, 9, 6));
  });

  testWidgets('an empty day shows the empty state, whose button adds',
      (tester) async {
    final calls = await _pump(tester, FixtureSpendingRepository(),
        clock: () => DateTime(2026, 9, 7, 9));
    expect(find.text('مفيش مصاريف النهارده'), findsOneWidget);
    await tester.tap(find.text('أضف أول مصروف'));
    expect(calls.adds, 1);
  });

  testWidgets('a newly saved entry slides and fades into today',
      (tester) async {
    final repository = FixtureSpendingRepository();
    await _pump(tester, repository);

    await repository.saveEntry(const DraftEntry(
      amountPiastres: 2500,
      description: 'فول',
      categoryKey: 'Food',
      source: EntrySource.manual,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final opacity = tester.widget<Opacity>(find
        .ancestor(of: find.text('فول'), matching: find.byType(Opacity))
        .first);
    expect(opacity.opacity, lessThan(1));

    await tester.pumpAndSettle();
    final settled = tester.widget<Opacity>(find
        .ancestor(of: find.text('فول'), matching: find.byType(Opacity))
        .first);
    expect(settled.opacity, 1);
  });

  testWidgets('top categories show amount and share, and open statistics',
      (tester) async {
    final calls = await _pump(tester, FixtureSpendingRepository());
    final section = find.byKey(const Key('top-categories-section'));
    // Food 4500 and Drinks 4000 of 8500.
    expect(find.descendant(of: section, matching: find.text('أكل')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('45')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('53%')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('47%')),
        findsOneWidget);
    final food = tester.getTopLeft(
        find.descendant(of: section, matching: find.text('أكل')));
    final drinks = tester.getTopLeft(
        find.descendant(of: section, matching: find.text('مشروبات')));
    expect(food.dy, lessThan(drinks.dy));

    await tester.tap(find.byKey(const Key('top-categories-see-all')));
    expect(calls.statistics, 1);
  });

  testWidgets('drafts show with a count badge, three at most, and open',
      (tester) async {
    final repository = FixtureSpendingRepository();
    for (final text in ['واحد', 'اتنين', 'تلاتة', 'أربعة']) {
      await repository.saveCapture(CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 9, 6),
        rawText: text,
        lines: const [],
        isDraft: true,
      ));
    }
    final calls = await _pump(tester, repository);

    final section = find.byKey(const Key('needs-review-section'));
    expect(section, findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('4')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('أربعة')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('واحد')),
        findsNothing);

    await tester.tap(find.text('أربعة'));
    expect(calls.drafts.single.rawText, 'أربعة');
  });

  testWidgets('bills due within ten days are listed', (tester) async {
    final repository = FixtureSpendingRepository();
    await repository.createRecurringBill(
      nameAr: 'النت',
      amountPiastres: 30000,
      categoryKey: 'Bills',
      nextDue: DateTime(2026, 9, 9),
    );
    await repository.createRecurringBill(
      nameAr: 'بعيدة',
      amountPiastres: 10000,
      categoryKey: 'Bills',
      nextDue: DateTime(2026, 10, 30),
    );
    await _pump(tester, repository);

    final section = find.byKey(const Key('upcoming-bills-section'));
    expect(find.descendant(of: section, matching: find.text('النت')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('300')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('بعيدة')),
        findsNothing);
  });

  testWidgets(
      'the month comparison is one sentence against the same day last '
      'month, and opens statistics', (tester) async {
    final repository = FixtureSpendingRepository();
    await repository.saveCapture(CaptureDraft(
      kind: CaptureKind.manual,
      date: DateTime(2026, 8, 3),
      lines: const [
        CaptureLine(amountPiastres: 10000, categoryKey: 'Food', description: 'x'),
      ],
    ));
    final calls = await _pump(tester, repository);

    // 1–6 September: 8500. 1–6 August: 10000.
    final sentence = find.text('أقل بـ 15% من الشهر الماضي في نفس اليوم');
    expect(sentence, findsOneWidget);
    await tester.tap(sentence);
    expect(calls.statistics, 1);
  });

  testWidgets('the month comparison is a level-1 card like the others',
      (tester) async {
    final repository = FixtureSpendingRepository();
    await repository.saveCapture(CaptureDraft(
      kind: CaptureKind.manual,
      date: DateTime(2026, 8, 3),
      lines: const [
        CaptureLine(amountPiastres: 10000, categoryKey: 'Food', description: 'x'),
      ],
    ));
    await _pump(tester, repository);
    final box = tester.widget<DecoratedBox>(find
        .ancestor(
            of: find.byKey(const Key('month-comparison')),
            matching: find.byType(DecoratedBox))
        .first);
    expect((box.decoration as BoxDecoration).boxShadow,
        AppPalette.light.cardShadow);
  });

  testWidgets('the capture bar hands its action to the shell', (tester) async {
    final calls = await _pump(tester, FixtureSpendingRepository());
    await tester.tap(find.byKey(const Key('capture-camera')));
    expect(calls.captures, [CaptureAction.camera]);
  });

  testWidgets('tapping the trend chart opens statistics', (tester) async {
    final calls = await _pump(tester, FixtureSpendingRepository());
    await tester.tap(find.byType(BarChart));
    expect(calls.statistics, 1);
  });

  testWidgets('the trend keeps its chosen range when an entry is saved',
      (tester) async {
    final repository = FixtureSpendingRepository();
    await _pump(tester, repository);
    await tester.tap(find.text('يوم'));
    await tester.pumpAndSettle();

    await repository.saveEntry(const DraftEntry(
      amountPiastres: 2500,
      description: 'فول',
      categoryKey: 'Food',
      source: EntrySource.manual,
    ));
    await tester.pump();
    // The previous chart stays on screen while the new totals load.
    expect(find.byType(BarChart), findsOneWidget);
    await tester.pumpAndSettle();

    final control = tester.widget<SegmentedButton<ChartRange>>(
        find.byKey(const Key('chart-range-control')));
    expect(control.selected, {ChartRange.day});
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('today moves on at midnight with the app left open',
      (tester) async {
    var now = DateTime(2026, 9, 6, 23, 59);
    await _pump(tester, FixtureSpendingRepository(), clock: () => now);
    expect(find.text('مفيش مصاريف النهارده'), findsNothing);

    now = DateTime(2026, 9, 7, 0, 1);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.text('مفيش مصاريف النهارده'), findsOneWidget);
  });

  testWidgets('coming back to the app on a new day moves today on',
      (tester) async {
    var now = DateTime(2026, 9, 6, 12);
    await _pump(tester, FixtureSpendingRepository(), clock: () => now);
    expect(find.text('مفيش مصاريف النهارده'), findsNothing);

    now = DateTime(2026, 9, 7, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('مفيش مصاريف النهارده'), findsOneWidget);
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
}
