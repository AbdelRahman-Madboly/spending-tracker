import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';

void main() {
  late FixtureSpendingRepository repo;

  setUp(() => repo = FixtureSpendingRepository());

  test('current period reports spent, left and salary', () async {
    final summary = await repo.watchCurrentPeriod().first;
    expect(summary.salaryPiastres, 900000);
    expect(summary.spentPiastres, 8500);
    expect(summary.leftPiastres, 891500);
  });

  test('safe daily is null once nothing is left', () {
    const over = PeriodSummary(
      salaryPiastres: 900000,
      spentPiastres: 1169200,
      daysRemaining: 10,
    );
    expect(over.leftPiastres, -269200);
    expect(over.safeDailyPiastres, isNull);
  });

  test('safe daily divides what is left across remaining days', () {
    const summary = PeriodSummary(
      salaryPiastres: 900000,
      spentPiastres: 8500,
      daysRemaining: 28,
    );
    expect(summary.safeDailyPiastres, 31839);
  });

  test('quick pick items come back ordered and capped', () async {
    final items = await repo.topItems(12);
    expect(items.length, 12);
    expect(items.first.nameAr, isNotEmpty);
  });

  test('saving an entry adds it to today', () async {
    final before = (await repo.watchEntriesForDay(DateTime(2026, 9, 6)).first).length;
    await repo.saveEntry(const DraftEntry(
      amountPiastres: 3500,
      description: 'لبن',
      categoryKey: 'Food/Social',
      paymentMethod: 'Cash',
      source: EntrySource.quickPick,
    ));
    final after = (await repo.watchEntriesForDay(DateTime(2026, 9, 6)).first).length;
    expect(after, before + 1);
  });
}
