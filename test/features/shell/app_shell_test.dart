import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';
import 'package:spending_tracker/features/home/home_screen.dart';
import 'package:spending_tracker/features/home/widgets/capture_bar.dart';
import 'package:spending_tracker/features/settings/settings_screen.dart';
import 'package:spending_tracker/features/shell/app_shell.dart';
import 'package:spending_tracker/features/statistics/statistics_screen.dart';
import 'package:spending_tracker/features/transactions/transactions_screen.dart';

DateTime _today() => DateTime(2026, 9, 6, 12);

Future<void> _pump(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            disableAnimations: disableAnimations,
          ),
          child: AppShell(
            repository: FixtureSpendingRepository(),
            clock: _today,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _destination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('four destinations run right to left: home, transactions, '
      'statistics, settings', (tester) async {
    await _pump(tester);
    final labels = ['الرئيسية', 'السجل', 'الإحصائيات', 'الإعدادات'];
    final xs = [for (final l in labels) tester.getCenter(_destination(l)).dx];
    expect(xs, [...xs]..sort((a, b) => b.compareTo(a)));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the FAB is 56dp and sits between السجل and الإحصائيات', (
    tester,
  ) async {
    await _pump(tester);
    final fab = find.byKey(const Key('add-fab'));
    expect(tester.getSize(fab), const Size(56, 56));
    final x = tester.getCenter(fab).dx;
    expect(x, lessThan(tester.getCenter(_destination('السجل')).dx));
    expect(x, greaterThan(tester.getCenter(_destination('الإحصائيات')).dx));
  });

  testWidgets('each destination shows its screen, and tabs keep their state', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(_destination('السجل'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionsScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing); // offstage

    // Step back a day, go elsewhere and come back: still on أمس.
    await tester.tap(find.byKey(const Key('day-previous')));
    await tester.pumpAndSettle();
    await tester.tap(_destination('الإحصائيات'));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsScreen), findsOneWidget);
    await tester.tap(_destination('السجل'));
    await tester.pumpAndSettle();
    expect(find.text('أمس'), findsOneWidget);

    await tester.tap(_destination('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('switching tabs fades the new one in', (tester) async {
    await _pump(tester);
    await tester.tap(_destination('السجل'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(TransactionsScreen),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
  });

  testWidgets('with animations off the new tab shows at once', (tester) async {
    await _pump(tester, disableAnimations: true);
    await tester.tap(_destination('السجل'));
    await tester.pump();
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(TransactionsScreen),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1);
  });

  testWidgets('tapping the FAB opens the add sheet', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('add-fab')));
    await tester.pumpAndSettle();
    expect(find.byType(AddSheet), findsOneWidget);
  });

  testWidgets('long-pressing the FAB opens the capture bar as a speed dial', (
    tester,
  ) async {
    await _pump(tester);
    await tester.longPress(find.byKey(const Key('add-fab')));
    await tester.pumpAndSettle();
    final dial = find.byKey(const Key('capture-speed-dial'));
    expect(dial, findsOneWidget);
    expect(
      find.descendant(of: dial, matching: find.byType(CaptureBar)),
      findsOneWidget,
    );

    // Voice has no flow before Phase C and says so.
    await tester.tap(
      find.descendant(
        of: dial,
        matching: find.byKey(const Key('capture-voice')),
      ),
    );
    await tester.pumpAndSettle();
    expect(dial, findsNothing);
    expect(find.byKey(const Key('capture-soon-voice')), findsOneWidget);
  });

  testWidgets("the dashboard's today عرض الكل opens السجل on that day", (
    tester,
  ) async {
    await _pump(tester);
    await tester.ensureVisible(find.byKey(const Key('today-see-all')));
    await tester.tap(find.byKey(const Key('today-see-all')));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionsScreen), findsOneWidget);
    expect(find.text('اليوم'), findsOneWidget);
  });

  testWidgets("the dashboard's statistics links switch to that tab", (
    tester,
  ) async {
    await _pump(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('top-categories-see-all')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('top-categories-see-all')));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsScreen), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    // Position 3: the FAB's gap sits at 2.
    expect(bar.selectedIndex, 3);
  });

  testWidgets(
    "عرض الكل opens السجل on today again after stepping away from it",
    (tester) async {
      await _pump(tester);
      final seeAll = find.byKey(const Key('today-see-all'));
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('day-previous')));
      await tester.pumpAndSettle();
      expect(find.text('أمس'), findsOneWidget);

      await tester.tap(_destination('الرئيسية'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionsScreen), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
    },
  );

  testWidgets('screen readers hear four tabs, not the FAB gap', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel(RegExp(r'Tab \d of 5')), findsNothing);
    final labels = ['الرئيسية', 'السجل', 'الإحصائيات', 'الإعدادات'];
    for (var i = 0; i < labels.length; i++) {
      expect(
        find.bySemanticsLabel('${labels[i]}\nTab ${i + 1} of 4'),
        findsOneWidget,
      );
    }

    // The relabelled tabs still switch tabs when activated.
    final transactions = tester.getSemantics(
      find.bySemanticsLabel('السجل\nTab 2 of 4'),
    );
    expect(
      transactions.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    handle.dispose();
  });
}
