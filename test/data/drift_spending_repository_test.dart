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

String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

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

  test('categories returns all ten seeded categories in sort order',
      () async {
    final cats = await repo.categories();
    expect(cats.length, 10);
    expect(cats.first.key, 'Drinks');
    expect(cats.map((c) => c.key), contains('Family/Social'));
    expect(
      cats.firstWhere((c) => c.key == 'Family/Social').labelAr,
      'عائلة وزيارات',
    );
  });

  test('itemsInCategory only returns items from that category, scored',
      () async {
    final now = DateTime.now();
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'drink-1',
          nameAr: 'مياه',
          nameEn: 'water',
          categoryKey: 'Drinks',
          useCount: const Value(10),
          lastUsedAt: Value(now),
        ));
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'food-1',
          nameAr: 'فول',
          nameEn: 'foul',
          categoryKey: 'Food',
          useCount: const Value(10),
          lastUsedAt: Value(now),
        ));

    final drinks = await repo.itemsInCategory('Drinks', 12);
    expect(drinks.map((i) => i.id), ['drink-1']);
    expect(drinks.every((i) => i.categoryKey == 'Drinks'), isTrue);
  });

  test('createItem inserts a new item and returns it as a QuickPickItem',
      () async {
    final created = await repo.createItem(
      nameAr: 'شاي',
      categoryKey: 'Drinks',
      defaultAmountPiastres: 1500,
    );

    expect(created.nameAr, 'شاي');
    expect(created.categoryKey, 'Drinks');
    expect(created.defaultAmountPiastres, 1500);

    final fromDb =
        await (db.select(db.items)..where((t) => t.id.equals(created.id)))
            .getSingleOrNull();
    expect(fromDb != null, isTrue);
    expect(fromDb!.nameAr, 'شاي');
  });

  test('enabling foreign keys rejects an entry with an unknown category',
      () async {
    await seedSalary();
    expect(
      () => seedEntry(id: 'bad', amount: 100, categoryKey: 'NotACategory'),
      throwsA(isA<SqliteException>().having(
        (e) => e.message,
        'message',
        contains('FOREIGN KEY constraint failed'),
      )),
    );
  });

  test(
      'spentInMonth sums only entries within that calendar month, excluding '
      'other months and soft-deleted entries', () async {
    await seedEntry(id: 'e1', amount: 3500, date: '2026-07-15');
    await seedEntry(id: 'e2', amount: 1000, date: '2026-07-31');
    await seedEntry(id: 'e3', amount: 5000, date: '2026-08-01');
    await seedEntry(
      id: 'e4',
      amount: 9999,
      date: '2026-07-20',
      deletedAt: DateTime.now(),
    );

    expect(await repo.spentInMonth(2026, 7), 4500);
    expect(await repo.spentInMonth(2026, 8), 5000);
  });

  test('spentInMonth returns zero for a month with no entries', () async {
    expect(await repo.spentInMonth(2020, 1), 0);
  });

  test(
      'monthlyTotals is oldest-first, ends at the current month, and '
      'zero-fills months with no spending', () async {
    final now = DateTime.now();
    final currentYearMonth = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
    await seedEntry(id: 'e1', amount: 1000, date: _today());

    final totals = await repo.monthlyTotals(3);

    expect(totals.length, 3);
    expect(totals.last.yearMonth, currentYearMonth);
    expect(totals.last.totalPiastres, 1000);
    expect(totals.first.totalPiastres, 0);
  });

  test('monthlyTotals excludes soft-deleted entries', () async {
    await seedEntry(
      id: 'e1',
      amount: 1000,
      date: _today(),
      deletedAt: DateTime.now(),
    );

    final totals = await repo.monthlyTotals(1);

    expect(totals.single.totalPiastres, 0);
  });

  test(
      'monthlyTotals produces chronologically consecutive YYYY-MM keys '
      'across a year boundary', () async {
    final totals = await repo.monthlyTotals(14);

    expect(totals.length, 14);
    DateTime? previous;
    for (final t in totals) {
      final parts = t.yearMonth.split('-');
      final current = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      if (previous != null) {
        expect(current, DateTime(previous.year, previous.month + 1));
      }
      previous = current;
    }
  });

  test(
      'updateSalary inserts a new salary_periods row dated today, keeping '
      'earlier rows intact', () async {
    await seedSalary(id: 'sp0', amount: 650000, datePaid: '2026-08-01');

    await repo.updateSalary(900000);

    final rows = await db.select(db.salaryPeriods).get();
    expect(rows.length, 2);
    expect(rows.any((r) => r.id == 'sp0' && r.amountPiastres == 650000), isTrue);
    final added = rows.firstWhere((r) => r.id != 'sp0');
    expect(added.amountPiastres, 900000);
    expect(added.datePaid, _today());
  });

  test('allItems returns every non-archived item in the catalogue', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'active',
          nameAr: 'نشط',
          nameEn: 'active',
          categoryKey: 'Food',
        ));
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'gone',
          nameAr: 'مؤرشف',
          nameEn: 'archived',
          categoryKey: 'Food',
          archived: const Value(true),
        ));

    final items = await repo.allItems();
    expect(items.map((i) => i.id), contains('active'));
    expect(items.map((i) => i.id), isNot(contains('gone')));
  });

  test(
      'archiveItem removes an item from allItems and from the quick-pick '
      'grid without deleting it', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'to-archive',
          nameAr: 'هيتشال',
          nameEn: 'to archive',
          categoryKey: 'Food',
          useCount: const Value(5),
        ));

    await repo.archiveItem('to-archive');

    final items = await repo.allItems();
    expect(items.map((i) => i.id), isNot(contains('to-archive')));

    final topItems = await repo.topItems(12);
    expect(topItems.map((i) => i.id), isNot(contains('to-archive')));

    final stillInDb =
        await (db.select(db.items)..where((t) => t.id.equals('to-archive')))
            .getSingleOrNull();
    expect(stillInDb != null, isTrue);
    expect(stillInDb!.archived, isTrue);
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

  test(
      'updateItem changes the catalogue row but never a past entry\'s own '
      'stored amount or category', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'item-x',
          nameAr: 'قديم',
          nameEn: 'old',
          categoryKey: 'Food',
          defaultAmountPiastres: const Value(1000),
        ));
    await db.into(db.entries).insert(EntriesCompanion.insert(
          id: 'entry-x',
          date: _today(),
          amountPiastres: 1000,
          categoryKey: 'Food',
          itemId: const Value('item-x'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

    await repo.updateItem(
      itemId: 'item-x',
      nameAr: 'جديد',
      categoryKey: 'Drinks',
      defaultAmountPiastres: 5000,
    );

    final item = await (db.select(db.items)
          ..where((t) => t.id.equals('item-x')))
        .getSingle();
    expect(item.nameAr, 'جديد');
    expect(item.categoryKey, 'Drinks');
    expect(item.defaultAmountPiastres, 5000);

    final entry = await (db.select(db.entries)
          ..where((t) => t.id.equals('entry-x')))
        .getSingle();
    expect(entry.categoryKey, 'Food');
    expect(entry.amountPiastres, 1000);
  });

  test(
      'dailyTotals is oldest-first, ends today, zero-fills empty days and '
      'excludes soft-deleted entries', () async {
    await seedEntry(id: 'e1', amount: 1500, date: _today());
    await seedEntry(
      id: 'e2',
      amount: 9999,
      date: _today(),
      deletedAt: DateTime.now(),
    );

    final totals = await repo.dailyTotals(7);

    expect(totals.length, 7);
    expect(totals.last.totalPiastres, 1500);
    expect(totals.first.totalPiastres, 0);
  });

  test('dailyTotals returns all zero totals when there is no spending',
      () async {
    final totals = await repo.dailyTotals(3);
    expect(totals.length, 3);
    expect(totals.every((t) => t.totalPiastres == 0), isTrue);
  });

  test(
      'weeklyTotals is oldest-first, ends with the week containing today, '
      'and zero-fills weeks with no spending', () async {
    await seedEntry(id: 'e1', amount: 2000, date: _today());

    final totals = await repo.weeklyTotals(6);

    expect(totals.length, 6);
    expect(totals.last.totalPiastres, 2000);
    expect(totals.first.totalPiastres, 0);
  });

  test(
      'weeklyTotals correctly buckets entries either side of a calendar '
      'month boundary without losing or double-counting either one',
      () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(today.year, today.month, 1);
    final lastOfPrevMonth = firstOfMonth.subtract(const Duration(days: 1));

    await seedEntry(id: 'e1', amount: 1000, date: _fmt(lastOfPrevMonth));
    await seedEntry(id: 'e2', amount: 2000, date: _fmt(firstOfMonth));

    final totals = await repo.weeklyTotals(8);
    final sum = totals.fold<int>(0, (s, t) => s + t.totalPiastres);

    expect(sum, 3000,
        reason: 'both entries must be counted exactly once across weeks, '
            'regardless of the month boundary between their dates');
  });
}
