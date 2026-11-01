import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/features/home/home_screen.dart';
import 'package:spending_tracker/features/home/widgets/top_categories_section.dart';

/// Regression test for a bug seen on a phone: the home screen's "today"
/// list was frozen to a hard-coded date, so new purchases never showed up.
/// The fix replaced the per-entry list with a category breakdown for the
/// CURRENT SALARY PERIOD, driven by
/// [SpendingRepository.spendByCategoryForPeriod], which has no such date
/// freeze. This test seeds the bundled sample data and asserts the exact
/// numbers the period should show.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'with the sample seed, the home breakdown shows أكل 585 and '
      'مواصلات 440 for the period starting 2026-10-01', (tester) async {
    final seedJson = await rootBundle.loadString('assets/seed/seed.json');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedFromJsonString(seedJson);
    final repository = DriftSpendingRepository(db);

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(
          repository: repository,
          // Pinned to a day after the last seeded entry, so today's list
          // and the trend chart hold nothing that could match the numbers
          // below, whatever the real date is.
          clock: () => DateTime(2026, 11, 1, 12),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Only the top categories section: the trend chart's axis labels can
    // carry the same digits.
    final section = find.byType(TopCategoriesSection);
    await tester.scrollUntilVisible(section, 200);
    Finder inSection(String text) =>
        find.descendant(of: section, matching: find.text(text));
    expect(inSection('أكل'), findsOneWidget);
    expect(inSection('585'), findsOneWidget);
    expect(inSection('مواصلات'), findsOneWidget);
    expect(inSection('440'), findsOneWidget);

    // Unmount before the test ends (rather than relying on addTearDown)
    // and pump once more so dispose() can close the database and drift's
    // internal stream-cleanup timer fires before the test's invariant
    // check runs — see the identical note in test/app_test.dart.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });
}
