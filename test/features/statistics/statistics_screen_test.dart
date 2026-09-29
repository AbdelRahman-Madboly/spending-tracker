import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_icons.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/core/design/category_colors.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/statistics.dart';
import 'package:spending_tracker/features/statistics/statistics_screen.dart';

/// The fixture's entries, all in September 2026: لبن 35 and إندومي 10
/// (أكل), شويبس 40 (مشروبات).
DateTime _today() => DateTime(2026, 9, 6, 12);

Future<void> _spend(
  FixtureSpendingRepository repo,
  DateTime date,
  List<CaptureLine> lines,
) => repo.saveCapture(
  CaptureDraft(kind: CaptureKind.text, date: date, lines: lines),
);

Future<FixtureSpendingRepository> _pump(
  WidgetTester tester, {
  FixtureSpendingRepository? repository,
  ValueChanged<YearMonth>? onOpenMonth,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final repo = repository ?? FixtureSpendingRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: StatisticsScreen(
          repository: repo,
          clock: _today,
          onOpenMonth: onOpenMonth,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

String _monthLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('stats-month-label'))).data!;

List<PieChartSectionData> _slices(WidgetTester tester) =>
    tester.widget<PieChart>(find.byType(PieChart)).data.sections;

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('the month selector', () {
    testWidgets('opens on the current month', (tester) async {
      await _pump(tester);
      expect(_monthLabel(tester), 'سبتمبر 2026');
      final next = find.byKey(const Key('month-next'));
      expect(tester.widget<IconButton>(next).onPressed, isNull);
    });

    testWidgets('steps back to the oldest month with spending, and no '
        'further', (tester) async {
      final repo = FixtureSpendingRepository();
      await _spend(repo, DateTime(2026, 7, 3), const [
        CaptureLine(amountPiastres: 9000, categoryKey: 'Bills'),
      ]);
      await _pump(tester, repository: repo);

      await _tapKey(tester, 'month-previous');
      expect(_monthLabel(tester), 'أغسطس 2026');
      await _tapKey(tester, 'month-previous');
      expect(_monthLabel(tester), 'يوليو 2026');
      final previous = find.byKey(const Key('month-previous'));
      expect(tester.widget<IconButton>(previous).onPressed, isNull);

      await _tapKey(tester, 'month-next');
      expect(_monthLabel(tester), 'أغسطس 2026');
    });

    testWidgets('a swipe toward the end side goes back a month, the other '
        'way forward', (tester) async {
      final repo = FixtureSpendingRepository();
      await _spend(repo, DateTime(2026, 8, 3), const [
        CaptureLine(amountPiastres: 9000, categoryKey: 'Bills'),
      ]);
      await _pump(tester, repository: repo);

      // In RTL the end side is the left.
      await tester.fling(
        find.byKey(const Key('stats-month')),
        const Offset(-200, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(_monthLabel(tester), 'أغسطس 2026');

      await tester.fling(
        find.byKey(const Key('stats-month')),
        const Offset(200, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(_monthLabel(tester), 'سبتمبر 2026');
    });
  });

  group('the donut', () {
    testWidgets('covers the selected month only', (tester) async {
      final repo = FixtureSpendingRepository();
      await _spend(repo, DateTime(2026, 8, 3), const [
        CaptureLine(amountPiastres: 9000, categoryKey: 'Bills'),
      ]);
      await _pump(tester, repository: repo);
      expect(_slices(tester), hasLength(2));
      expect(find.byKey(const Key('legend-Bills')), findsNothing);

      await _tapKey(tester, 'month-previous');
      expect(_slices(tester), hasLength(1));
      expect(find.byKey(const Key('legend-Bills')), findsOneWidget);
      expect(find.byKey(const Key('legend-Food')), findsNothing);
    });

    testWidgets('every slice is labelled with its name and percent, in the '
        'legend and on the slice', (tester) async {
      await _pump(tester);
      final food = find.byKey(const Key('legend-Food'));
      expect(
        find.descendant(of: food, matching: find.text('أكل')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: food, matching: find.text('53%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: food, matching: find.text('45 ج.م')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('legend-Drinks')),
          matching: find.text('47%'),
        ),
        findsOneWidget,
      );
      expect([for (final s in _slices(tester)) s.title], ['53%', '47%']);
      expect(find.text('Food'), findsNothing);
      expect(find.byIcon(iconFor('restaurant')), findsOneWidget);
    });

    testWidgets('screen readers get the donut as one summary sentence', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(
        find.bySemanticsLabel(RegExp(r'أكل 53%.*مشروبات 47%')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('past six categories the rest merge into أخرى, which opens '
        'to list them', (tester) async {
      final repo = FixtureSpendingRepository();
      await _spend(repo, DateTime(2026, 9, 2), const [
        CaptureLine(amountPiastres: 9000, categoryKey: 'Bills'),
        CaptureLine(amountPiastres: 8000, categoryKey: 'Transport'),
        CaptureLine(amountPiastres: 7000, categoryKey: 'Shopping'),
        CaptureLine(amountPiastres: 300, categoryKey: 'Gifts'),
        CaptureLine(amountPiastres: 200, categoryKey: 'Loans'),
      ]);
      await _pump(tester, repository: repo);

      final slices = _slices(tester);
      expect(slices, hasLength(6));
      // Food 45, Drinks 40, then Gifts 3 and Loans 2 merge.
      expect(find.byKey(const Key('legend-other')), findsOneWidget);
      expect(find.byKey(const Key('legend-Gifts')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('legend-other')),
          matching: find.text('أخرى'),
        ),
        findsOneWidget,
      );

      await _tapKey(tester, 'legend-other');
      expect(find.byKey(const Key('legend-Gifts')), findsOneWidget);
      expect(find.byKey(const Key('legend-Loans')), findsOneWidget);
    });

    testWidgets("tapping a legend row drills into that category's "
        'subcategories for the month, and back', (tester) async {
      final repo = FixtureSpendingRepository();
      await _spend(repo, DateTime(2026, 9, 2), const [
        CaptureLine(
          amountPiastres: 3000,
          categoryKey: 'Transport',
          subcategoryKey: 'Taxi',
        ),
        CaptureLine(
          amountPiastres: 1000,
          categoryKey: 'Transport',
          subcategoryKey: 'PublicTransport',
        ),
      ]);
      await _spend(repo, DateTime(2026, 8, 2), const [
        CaptureLine(
          amountPiastres: 5000,
          categoryKey: 'Transport',
          subcategoryKey: 'Taxi',
        ),
      ]);
      await _pump(tester, repository: repo);

      await _tapKey(tester, 'legend-Transport');
      expect(find.byKey(const Key('drill-back')), findsOneWidget);
      expect(_slices(tester), hasLength(2));
      final taxi = find.byKey(const Key('legend-sub-Taxi'));
      expect(
        find.descendant(of: taxi, matching: find.text('30 ج.م')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: taxi, matching: find.text('75%')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('legend-sub-PublicTransport')),
        findsOneWidget,
      );

      await _tapKey(tester, 'drill-back');
      expect(find.byKey(const Key('drill-back')), findsNothing);
      expect(find.byKey(const Key('legend-Transport')), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('a percent inside a ${brightness.name}-mode slice stays '
          'readable on the palest drill-down shade', (tester) async {
        final repo = FixtureSpendingRepository();
        await _spend(repo, DateTime(2026, 9, 2), const [
          CaptureLine(
            amountPiastres: 1000,
            categoryKey: 'Transport',
            subcategoryKey: 'Taxi',
          ),
          CaptureLine(
            amountPiastres: 1000,
            categoryKey: 'Transport',
            subcategoryKey: 'PublicTransport',
          ),
        ]);
        await _pump(tester, repository: repo, brightness: brightness);
        await _tapKey(tester, 'legend-Transport');
        final surface = brightness == Brightness.dark
            ? AppPalette.dark.surface
            : AppPalette.light.surface;
        for (final slice in _slices(tester)) {
          final fill = Color.alphaBlend(slice.color, surface);
          final ink = slice.titleStyle!.color!;
          final l1 = fill.computeLuminance();
          final l2 = ink.computeLuminance();
          final ratio =
              (l1 > l2 ? l1 + 0.05 : l2 + 0.05) /
              (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${slice.title} on $fill',
          );
        }
      });
    }

    testWidgets('entries filed under the category alone drill into a row of '
        'their own', (tester) async {
      await _pump(tester);
      await _tapKey(tester, 'legend-Drinks');
      expect(find.byKey(const Key('legend-sub-none')), findsOneWidget);
    });

    testWidgets('tapping a slice drills in too', (tester) async {
      await _pump(tester);
      final touch = tester
          .widget<PieChart>(find.byType(PieChart))
          .data
          .pieTouchData
          .touchCallback!;
      final drinks = _slices(tester)[1];
      touch(
        FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
        PieTouchResponse(
          touchLocation: Offset.zero,
          touchedSection: PieTouchedSection(drinks, 1, 0, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('drill-back')), findsOneWidget);
      expect(find.byKey(const Key('drill-title')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('drill-title'))).data,
        'مشروبات',
      );
    });

    testWidgets('a month with nothing spent says so instead of a donut', (
      tester,
    ) async {
      final repo = FixtureSpendingRepository();
      for (final t in await repo.watchTransactions().first) {
        await repo.deleteEntries([t.id]);
      }
      await _pump(tester, repository: repo);
      expect(find.byType(PieChart), findsNothing);
      expect(find.text('مفيش مصاريف في الشهر ده'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets(
        'colours each ${brightness.name}-mode slice and glyph with its '
        "category's colorKey ink",
        (tester) async {
          await _pump(tester, brightness: brightness);
          final palette = brightness == Brightness.dark
              ? AppPalette.dark
              : AppPalette.light;
          expect(_slices(tester).map((s) => s.color).toSet(), {
            palette.categoryInk('Food'),
            palette.categoryInk('Drinks'),
          });
          final foodGlyph = tester.widget<Icon>(
            find.byIcon(iconFor('restaurant')),
          );
          expect(foodGlyph.color, palette.categoryInk('Food'));
        },
      );
    }
  });

  group('the month history', () {
    testWidgets('lists every month with spending: total, change and top '
        'three categories', (tester) async {
      final repo = FixtureSpendingRepository();
      await _spend(repo, DateTime(2026, 8, 3), const [
        CaptureLine(amountPiastres: 10000, categoryKey: 'Bills'),
      ]);
      await _pump(tester, repository: repo);

      final september = find.byKey(const Key('history-2026-09'));
      final august = find.byKey(const Key('history-2026-08'));
      await tester.ensureVisible(august);
      expect(september, findsOneWidget);
      expect(
        tester.getTopLeft(september).dy,
        lessThan(tester.getTopLeft(august).dy),
      );
      expect(
        find.descendant(of: september, matching: find.text('85 ج.م')),
        findsOneWidget,
      );
      // 85 against 100: 15% less.
      expect(
        find.descendant(of: september, matching: find.text('أقل بـ 15%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: september, matching: find.text('أكل · مشروبات')),
        findsOneWidget,
      );
      // August has no July to compare with.
      expect(
        find.descendant(of: august, matching: find.textContaining('%')),
        findsNothing,
      );
    });

    testWidgets('tapping a month asks to open السجل on it', (tester) async {
      final opened = <YearMonth>[];
      await _pump(tester, onOpenMonth: opened.add);
      await _tapKey(tester, 'history-2026-09');
      expect(opened, [const YearMonth(2026, 9)]);
    });

    testWidgets('follows a new entry without reopening the screen', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await _spend(repo, DateTime(2026, 6, 3), const [
        CaptureLine(amountPiastres: 10000, categoryKey: 'Bills'),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-2026-06')), findsOneWidget);
    });
  });

  testWidgets('opens on the month the shell asks for, again on each request', (
    tester,
  ) async {
    final repo = FixtureSpendingRepository();
    await _spend(repo, DateTime(2026, 8, 3), const [
      CaptureLine(amountPiastres: 9000, categoryKey: 'Bills'),
    ]);
    Widget screen(int request) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: StatisticsScreen(
          repository: repo,
          clock: _today,
          initialMonth: const YearMonth(2026, 9),
          monthRequest: request,
        ),
      ),
    );
    await tester.pumpWidget(screen(0));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'month-previous');
    expect(_monthLabel(tester), 'أغسطس 2026');

    await tester.pumpWidget(screen(1));
    await tester.pumpAndSettle();
    expect(_monthLabel(tester), 'سبتمبر 2026');
  });
}
