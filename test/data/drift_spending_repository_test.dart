import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  late AppDatabase db;
  late DriftSpendingRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftSpendingRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seedSalary({
    String id = 'sp1',
    int amount = 900000,
    String? datePaid,
  }) async {
    await db.into(db.salaryPeriods).insert(SalaryPeriodsCompanion.insert(
          id: id,
          datePaid: datePaid ?? _today(),
          amountPiastres: amount,
        ));
  }

  Future<void> seedEntry({
    required String id,
    required int amount,
    String categoryKey = 'Food',
    String? date,
    DateTime? deletedAt,
  }) async {
    final now = DateTime.now();
    await db.into(db.entries).insert(EntriesCompanion.insert(
          id: id,
          date: date ?? _today(),
          amountPiastres: amount,
          categoryKey: categoryKey,
          createdAt: now,
          updatedAt: now,
          deletedAt: Value(deletedAt),
        ));
  }

  test('the ten categories are seeded when the database is created', () async {
    final cats = await db.select(db.categories).get();
    expect(cats.length, 10);
    expect(cats.map((c) => c.key), contains('Family/Social'));
  });

  test('current period reports spent and left from salary and entries',
      () async {
    await seedSalary();
    await seedEntry(id: 'e1', amount: 3500);
    await seedEntry(id: 'e2', amount: 1000);

    final summary = await repo.watchCurrentPeriod().first;
    expect(summary.salaryPiastres, 900000);
    expect(summary.spentPiastres, 4500);
    expect(summary.leftPiastres, 895500);
  });

  test(
      'saveEntry inserts and both streams emit again for listeners '
      'subscribed before the save', () async {
    await seedSalary();

    final periodEvents = <PeriodSummary>[];
    final periodDone = Completer<void>();
    final periodSub = repo.watchCurrentPeriod().listen((s) {
      periodEvents.add(s);
      if (periodEvents.length == 2 && !periodDone.isCompleted) {
        periodDone.complete();
      }
    });

    final dayEvents = <List<EntryView>>[];
    final dayDone = Completer<void>();
    final daySub = repo.watchEntriesForDay(DateTime.now()).listen((e) {
      dayEvents.add(e);
      if (dayEvents.length == 2 && !dayDone.isCompleted) {
        dayDone.complete();
      }
    });

    // Let the initial values land before triggering the write.
    await Future<void>.delayed(Duration.zero);
    expect(periodEvents, hasLength(1));
    expect(dayEvents, hasLength(1));

    await repo.saveEntry(const DraftEntry(
      amountPiastres: 2000,
      description: 'قهوة',
      categoryKey: 'Food',
      paymentMethod: 'Cash',
      source: EntrySource.quickPick,
    ));

    await periodDone.future.timeout(const Duration(seconds: 2));
    await dayDone.future.timeout(const Duration(seconds: 2));

    expect(periodEvents.last.spentPiastres, 2000);
    expect(dayEvents.last, hasLength(1));
    expect(dayEvents.last.first.displayName, 'قهوة');

    await periodSub.cancel();
    await daySub.cancel();
  });

  test('topItems returns items ordered by a recency-weighted score',
      () async {
    final now = DateTime.now();
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'stale-heavy',
          nameAr: 'مستخدم قديم',
          nameEn: 'stale heavy',
          categoryKey: 'Food',
          useCount: const Value(20),
          lastUsedAt: Value(now.subtract(const Duration(days: 40))),
        ));
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'fresh-light',
          nameAr: 'مستخدم جديد',
          nameEn: 'fresh light',
          categoryKey: 'Food',
          useCount: const Value(3),
          lastUsedAt: Value(now),
        ));
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'mid',
          nameAr: 'وسط',
          nameEn: 'mid',
          categoryKey: 'Food',
          useCount: const Value(5),
          lastUsedAt: Value(now.subtract(const Duration(days: 5))),
        ));

    final items = await repo.topItems(12);
    expect(
      items.map((i) => i.id).toList(),
      ['fresh-light', 'mid', 'stale-heavy'],
    );
  });

  test('spendByCategoryForPeriod groups by category', () async {
    await seedSalary();
    await seedEntry(id: 'e1', amount: 3500, categoryKey: 'Food');
    await seedEntry(id: 'e2', amount: 1000, categoryKey: 'Transport');
    await seedEntry(id: 'e3', amount: 500, categoryKey: 'Food');

    final byCategory = await repo.spendByCategoryForPeriod();
    expect(byCategory['Food'], 4000);
    expect(byCategory['Transport'], 1000);
  });

  test('soft-deleted entries are excluded from every total', () async {
    await seedSalary();
    await seedEntry(id: 'e1', amount: 3500, categoryKey: 'Food');
    await seedEntry(
      id: 'e2',
      amount: 1000,
      categoryKey: 'Food',
      deletedAt: DateTime.now(),
    );

    final summary = await repo.watchCurrentPeriod().first;
    expect(summary.spentPiastres, 3500);

    final byCategory = await repo.spendByCategoryForPeriod();
    expect(byCategory['Food'], 3500);

    final dayEntries = await repo.watchEntriesForDay(DateTime.now()).first;
    expect(dayEntries.length, 1);
    expect(dayEntries.first.id, 'e1');
  });
}
