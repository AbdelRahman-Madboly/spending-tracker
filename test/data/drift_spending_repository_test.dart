import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test(
      'itemsInSubcategory only returns items tagged with that subcategory, '
      'scored', () async {
    final now = DateTime.now();
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'soda-1',
          nameAr: 'كولا',
          nameEn: 'cola',
          categoryKey: 'Drinks',
          subcategoryKey: const Value('Soda'),
          useCount: const Value(10),
          lastUsedAt: Value(now),
        ));
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'juice-1',
          nameAr: 'عصير مانجا',
          nameEn: 'mango juice',
          categoryKey: 'Drinks',
          subcategoryKey: const Value('Juice'),
          useCount: const Value(10),
          lastUsedAt: Value(now),
        ));

    final soda = await repo.itemsInSubcategory('Soda', 12);
    expect(soda.map((i) => i.id), ['soda-1']);
    expect(soda.every((i) => i.subcategoryKey == 'Soda'), isTrue);
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

  test('createItem persists a subcategory when one is given', () async {
    final created = await repo.createItem(
      nameAr: 'كولا',
      categoryKey: 'Drinks',
      subcategoryKey: 'Soda',
      defaultAmountPiastres: 1500,
    );

    expect(created.subcategoryKey, 'Soda');

    final fromDb =
        await (db.select(db.items)..where((t) => t.id.equals(created.id)))
            .getSingle();
    expect(fromDb.subcategoryKey, 'Soda');
  });

  test('createItem persists a barcode when one is given', () async {
    final created = await repo.createItem(
      nameAr: 'مياه',
      categoryKey: 'Drinks',
      defaultAmountPiastres: 1000,
      barcode: '6224000123456',
    );

    expect(created.barcode, '6224000123456');
    final fromDb =
        await (db.select(db.items)..where((t) => t.id.equals(created.id)))
            .getSingle();
    expect(fromDb.barcode, '6224000123456');
  });

  test('itemByBarcode resolves a previously learned item', () async {
    final created = await repo.createItem(
      nameAr: 'مياه',
      categoryKey: 'Drinks',
      defaultAmountPiastres: 1000,
      barcode: '6224000123456',
    );

    final found = await repo.itemByBarcode('6224000123456');

    expect(found != null, isTrue);
    expect(found!.id, created.id);
    expect(found.nameAr, 'مياه');
  });

  test('itemByBarcode returns null for a code that was never learned',
      () async {
    final found = await repo.itemByBarcode('0000000000000');
    expect(found == null, isTrue);
  });

  test('itemByBarcode ignores an archived item', () async {
    final created = await repo.createItem(
      nameAr: 'مياه',
      categoryKey: 'Drinks',
      defaultAmountPiastres: 1000,
      barcode: '6224000123456',
    );
    await repo.archiveItem(created.id);

    final found = await repo.itemByBarcode('6224000123456');
    expect(found == null, isTrue);
  });

  test("saveEntry persists the draft's subcategoryKey", () async {
    await repo.saveEntry(const DraftEntry(
      amountPiastres: 2000,
      description: 'كولا',
      categoryKey: 'Drinks',
      subcategoryKey: 'Soda',
      paymentMethod: 'Cash',
      source: EntrySource.quickPick,
    ));

    final row = await db.select(db.entries).getSingle();
    expect(row.subcategoryKey, 'Soda');
  });

  // Since v3 the photo is an attachment row; entries.photoPath is only
  // kept for rows written before v3.
  test("saveEntry persists the draft's photo as an attachment", () async {
    await repo.saveEntry(const DraftEntry(
      amountPiastres: 2000,
      description: 'كولا',
      categoryKey: 'Drinks',
      paymentMethod: 'Cash',
      photoPath: 'photos/172000-0.jpg',
      source: EntrySource.quickPick,
    ));

    final row = await db.select(db.entries).getSingle();
    expect(row.photoPath, isNull);
    final attachment = await db.select(db.attachments).getSingle();
    expect(attachment.entryId, row.id);
    expect(attachment.kind, 'photo');
    expect(attachment.path, 'photos/172000-0.jpg');
  });

  test('saveEntry leaves photoPath null when the draft has none', () async {
    await repo.saveEntry(const DraftEntry(
      amountPiastres: 2000,
      description: 'كولا',
      categoryKey: 'Drinks',
      paymentMethod: 'Cash',
      source: EntrySource.quickPick,
    ));

    final row = await db.select(db.entries).getSingle();
    expect(row.photoPath, null);
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

  group('category CRUD', () {
    test('createCategory inserts a new category', () async {
      final created = await repo.createCategory(
        key: 'Custom1',
        labelAr: 'مخصص',
        iconName: 'pets',
      );

      expect(created.key, 'Custom1');
      expect(created.labelAr, 'مخصص');
      final all = await repo.categories();
      expect(all.map((c) => c.key), contains('Custom1'));
    });

    test('updateCategory changes the label and icon but never the key',
        () async {
      await repo.updateCategory(
        key: 'Food',
        labelAr: 'أكل وشرب',
        iconName: 'lunch_dining',
      );

      final all = await repo.categories();
      final food = all.firstWhere((c) => c.key == 'Food');
      expect(food.labelAr, 'أكل وشرب');
      expect(food.iconName, 'lunch_dining');
    });

    test(
        'renaming a category never touches a past entry filed under it',
        () async {
      await seedEntry(id: 'e1', amount: 3500, categoryKey: 'Food');

      await repo.updateCategory(
        key: 'Food',
        labelAr: 'أكل وشرب',
        iconName: 'lunch_dining',
      );

      final entry = await (db.select(db.entries)
            ..where((t) => t.id.equals('e1')))
          .getSingle();
      expect(entry.categoryKey, 'Food');
      expect(entry.amountPiastres, 3500);
    });

    test(
        'archiving a category cascades to its subcategories and items, but '
        'never touches a past entry filed under it', () async {
      await seedEntry(id: 'e1', amount: 3500, categoryKey: 'Food');
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'food-item',
            nameAr: 'فول',
            nameEn: 'foul',
            categoryKey: 'Food',
          ));

      await repo.archiveCategory('Food');

      final categories = await repo.categories();
      expect(categories.map((c) => c.key), isNot(contains('Food')));

      final subcategoriesUnderFood = await (db.select(db.subcategories)
            ..where((t) => t.categoryKey.equals('Food')))
          .get();
      expect(subcategoriesUnderFood.every((s) => s.archived), isTrue);
      expect(await repo.subcategories('Food'), isEmpty);

      final items = await repo.allItems();
      expect(items.map((i) => i.id), isNot(contains('food-item')));

      final entry = await (db.select(db.entries)
            ..where((t) => t.id.equals('e1')))
          .getSingle();
      expect(entry.categoryKey, 'Food');
      expect(entry.amountPiastres, 3500);
    });
  });

  group('subcategory CRUD', () {
    test('createSubcategory inserts a new subcategory under a category',
        () async {
      final created = await repo.createSubcategory(
        key: 'PhoneAccessories',
        categoryKey: 'Shopping',
        labelAr: 'إكسسوارات موبايل',
        iconName: 'devices',
      );

      expect(created.categoryKey, 'Shopping');
      final subs = await repo.subcategories('Shopping');
      expect(subs.map((s) => s.key), contains('PhoneAccessories'));
    });

    test('updateSubcategory renames the label without changing the key',
        () async {
      await repo.updateSubcategory(
        key: 'Haircut',
        categoryKey: 'Personal Care',
        labelAr: 'حلاقة وتقصيص',
        iconName: 'content_cut',
      );

      final subs = await repo.subcategories('Personal Care');
      final haircut = subs.firstWhere((s) => s.key == 'Haircut');
      expect(haircut.labelAr, 'حلاقة وتقصيص');
    });

    test(
        'moving a subcategory to a new category updates the catalogue but '
        'never re-categorises a past entry filed under it', () async {
      await seedEntry(
        id: 'e1',
        amount: 1500,
        categoryKey: 'Personal Care',
      );
      await db.update(db.entries).write(
            const EntriesCompanion(subcategoryKey: Value('Haircut')),
          );
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'haircut-item',
            nameAr: 'حلاقة',
            nameEn: 'haircut',
            categoryKey: 'Personal Care',
            subcategoryKey: const Value('Haircut'),
          ));

      await repo.updateSubcategory(
        key: 'Haircut',
        categoryKey: 'Shopping',
        labelAr: 'حلاقة',
        iconName: 'content_cut',
      );

      // Catalogue moved: Haircut now lives under Shopping, and its
      // catalogue item followed it there.
      expect(await repo.subcategories('Personal Care'),
          isNot(contains(predicate<SubcategoryView>((s) => s.key == 'Haircut'))));
      final movedSubs = await repo.subcategories('Shopping');
      expect(movedSubs.map((s) => s.key), contains('Haircut'));
      final item = await (db.select(db.items)
            ..where((t) => t.id.equals('haircut-item')))
          .getSingle();
      expect(item.categoryKey, 'Shopping');

      // History untouched: the past entry keeps exactly what it was saved
      // with.
      final entry = await (db.select(db.entries)
            ..where((t) => t.id.equals('e1')))
          .getSingle();
      expect(entry.categoryKey, 'Personal Care');
      expect(entry.subcategoryKey, 'Haircut');
      expect(entry.amountPiastres, 1500);
    });

    test(
        'archiving a subcategory cascades to its items but never touches a '
        'past entry filed under it', () async {
      await seedEntry(id: 'e1', amount: 1500, categoryKey: 'Personal Care');
      await db.update(db.entries).write(
            const EntriesCompanion(subcategoryKey: Value('Haircut')),
          );
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'haircut-item',
            nameAr: 'حلاقة',
            nameEn: 'haircut',
            categoryKey: 'Personal Care',
            subcategoryKey: const Value('Haircut'),
          ));

      await repo.archiveSubcategory('Haircut');

      final subs = await repo.subcategories('Personal Care');
      expect(subs.map((s) => s.key), isNot(contains('Haircut')));

      final items = await repo.allItems();
      expect(items.map((i) => i.id), isNot(contains('haircut-item')));

      final entry = await (db.select(db.entries)
            ..where((t) => t.id.equals('e1')))
          .getSingle();
      expect(entry.categoryKey, 'Personal Care');
      expect(entry.subcategoryKey, 'Haircut');
      expect(entry.amountPiastres, 1500);
    });
  });

  group('archived items', () {
    test('archivedItems lists only archived items, and unarchiveItem '
        'restores one to allItems', () async {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'gone',
            nameAr: 'مؤرشف',
            nameEn: 'archived',
            categoryKey: 'Food',
            archived: const Value(true),
          ));
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'active',
            nameAr: 'نشط',
            nameEn: 'active',
            categoryKey: 'Food',
          ));

      final archived = await repo.archivedItems();
      expect(archived.map((i) => i.id), ['gone']);

      await repo.unarchiveItem('gone');

      final all = await repo.allItems();
      expect(all.map((i) => i.id), contains('gone'));
      expect(await repo.archivedItems(), isEmpty);
    });
  });

  group('unarchive category and subcategory', () {
    test(
        'unarchiveCategory restores the category, its subcategories and '
        'its items', () async {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'food-item',
            nameAr: 'فول',
            nameEn: 'foul',
            categoryKey: 'Food',
          ));
      await repo.archiveCategory('Food');

      expect((await repo.categories()).map((c) => c.key),
          isNot(contains('Food')));
      expect(await repo.archivedCategories(),
          contains(predicate<CategoryView>((c) => c.key == 'Food')));

      await repo.unarchiveCategory('Food');

      expect(
          (await repo.categories()).map((c) => c.key), contains('Food'));
      expect(await repo.subcategories('Food'), isNotEmpty);
      expect((await repo.allItems()).map((i) => i.id),
          contains('food-item'));
      expect(await repo.archivedCategories(), isEmpty);
    });

    test(
        'unarchiveSubcategory restores its items but never its parent '
        'category', () async {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'haircut-item',
            nameAr: 'حلاقة',
            nameEn: 'haircut',
            categoryKey: 'Personal Care',
            subcategoryKey: const Value('Haircut'),
          ));
      await repo.archiveCategory('Personal Care');

      expect((await repo.categories()).map((c) => c.key),
          isNot(contains('Personal Care')));

      await repo.unarchiveSubcategory('Haircut');

      // The item is back...
      expect((await repo.allItems()).map((i) => i.id),
          contains('haircut-item'));
      // ...but the parent category is still archived: unarchiving a
      // subcategory must never cascade upward.
      expect((await repo.categories()).map((c) => c.key),
          isNot(contains('Personal Care')));
      final haircutRow = await (db.select(db.subcategories)
            ..where((t) => t.key.equals('Haircut')))
          .getSingle();
      expect(haircutRow.archived, isFalse);
    });

    test(
        'a past entry survives an archive-then-unarchive round trip on its '
        'category with every field intact, including its date',
        () async {
      await seedEntry(
        id: 'e1',
        amount: 4200,
        categoryKey: 'Food',
        date: '2026-01-15',
      );
      await db.update(db.entries).write(
            const EntriesCompanion(subcategoryKey: Value('Breakfast')),
          );

      await repo.archiveCategory('Food');
      await repo.unarchiveCategory('Food');

      final entry = await (db.select(db.entries)
            ..where((t) => t.id.equals('e1')))
          .getSingle();
      expect(entry.categoryKey, 'Food');
      expect(entry.subcategoryKey, 'Breakfast');
      expect(entry.amountPiastres, 4200);
      expect(entry.date, '2026-01-15');
    });

    test('archivedCategories and archivedSubcategories list only archived '
        'rows', () async {
      expect(await repo.archivedCategories(), isEmpty);
      expect(await repo.archivedSubcategories(), isEmpty);

      await repo.archiveSubcategory('Haircut');

      final archivedSubs = await repo.archivedSubcategories();
      expect(archivedSubs.map((s) => s.key), ['Haircut']);
      expect(await repo.archivedCategories(), isEmpty);
    });
  });

  group('v3 storage', () {
    test('the database refuses an attachment that belongs to nothing',
        () async {
      await expectLater(
        db.into(db.attachments).insert(AttachmentsCompanion.insert(
              id: 'orphan',
              kind: 'text',
              body: const Value('x'),
              createdAt: DateTime.now(),
            )),
        throwsA(anything),
      );
    });

    test('a fresh install seeds every category with its own colour key',
        () async {
      final rows = await db.select(db.categories).get();
      expect(rows, hasLength(10));
      for (final c in rows) {
        expect(c.colorKey, c.key);
        expect(categoryColorKeys, contains(c.colorKey));
      }
    });

    test('knownExternalIds includes salary periods', () async {
      await db.into(db.salaryPeriods).insert(SalaryPeriodsCompanion.insert(
            id: 'sp-x',
            datePaid: '2026-09-23',
            amountPiastres: 900000,
            externalId: const Value('wt-salary-7'),
          ));
      expect(await repo.knownExternalIds(), {'wt-salary-7'});
    });

    test('a capture saves entries with the capture kind as their source',
        () async {
      final id = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.import,
        date: DateTime(2026, 9, 3),
        lines: const [
          CaptureLine(
              amountPiastres: 700, categoryKey: 'Transport', externalId: 'sn-1'),
        ],
      ));
      final entry = await db.select(db.entries).getSingle();
      expect(entry.source, 'import');
      expect(entry.captureGroupId, id);
      expect(entry.date, '2026-09-03');
      final group = await db.select(db.captureGroups).getSingle();
      expect(group.kind, 'import');
      expect(group.status, 'saved');
    });

    test('itemByBarcode resolves a barcode two live rows already share',
        () async {
      // The repository never writes such a pair, but a row written before
      // the rule existed must not crash a scan.
      for (final id in ['dup-1', 'dup-2']) {
        await db.into(db.items).insert(ItemsCompanion.insert(
              id: id,
              nameAr: 'بيبسي',
              nameEn: 'بيبسي',
              categoryKey: 'Drinks',
              barcode: const Value('6229'),
            ));
      }
      final item = await repo.itemByBarcode('6229');
      expect(['dup-1', 'dup-2'], contains(item!.id));
    });
  });

  group('salary periods (dashboard)', () {
    test('watchPeriods lists every period newest first with its own spend',
        () async {
      await seedSalary(id: 'aug', amount: 900000, datePaid: '2026-08-04');
      await seedSalary(id: 'sep', amount: 800000, datePaid: '2026-09-04');
      await seedEntry(id: 'e1', amount: 1000, date: '2026-08-10');
      await seedEntry(id: 'e2', amount: 500, date: '2026-09-03');
      await seedEntry(id: 'e3', amount: 2000, date: '2026-09-10');
      await seedEntry(
          id: 'e4',
          amount: 9900,
          date: '2026-09-11',
          deletedAt: DateTime(2026, 9, 12));

      final periods = await repo.watchPeriods().first;

      expect(periods, hasLength(2));
      final current = periods.first;
      expect(current.isCurrent, isTrue);
      expect(current.start, DateTime(2026, 9, 4));
      expect(current.salaryPiastres, 800000);
      expect(current.spentPiastres, 2000);
      // The current period runs one calendar month: 4 Sep to 3 Oct.
      expect(current.lengthDays, 30);
      expect(current.end, DateTime(2026, 10, 3));

      final past = periods.last;
      expect(past.isCurrent, isFalse);
      expect(past.start, DateTime(2026, 8, 4));
      expect(past.end, DateTime(2026, 9, 3));
      expect(past.lengthDays, 31);
      expect(past.salaryPiastres, 900000);
      expect(past.spentPiastres, 1500);
      expect(past.daysRemaining, 0);
    });

    test('watchCurrentPeriod reports the same period as watchPeriods',
        () async {
      await seedSalary(id: 'sep', datePaid: '2026-09-04');
      await seedEntry(id: 'e1', amount: 2000, date: '2026-09-10');

      expect(await repo.watchCurrentPeriod().first,
          (await repo.watchPeriods().first).first);
    });

    test('two salaries on the same day make one period, not an empty one',
        () async {
      await seedSalary(id: 'a', amount: 900000, datePaid: '2026-09-04');
      await seedSalary(id: 'b', amount: 750000, datePaid: '2026-09-04');

      final periods = await repo.watchPeriods().first;
      expect(periods, hasLength(1));
    });

    test('no salary yet is one empty current period', () async {
      final periods = await repo.watchPeriods().first;
      expect(periods, hasLength(1));
      expect(periods.single.start, isNull);
      expect(periods.single.salaryPiastres, 0);
    });

    test('an early salary still gives a whole calendar month', () async {
      await seedSalary(id: 'jul', datePaid: '2026-07-06');
      await seedSalary(id: 'aug', datePaid: '2026-08-02');
      await seedSalary(id: 'sep', datePaid: '2026-09-04');
      await seedSalary(id: 'sep2', datePaid: '2026-09-23');

      final current = (await repo.watchPeriods().first).first;

      expect(current.start, DateTime(2026, 9, 23));
      expect(current.end, DateTime(2026, 10, 22));
      expect(current.lengthDays, 30);
    });

    test('a month-end salary ends the day before the same day next month',
        () async {
      await seedSalary(id: 'jan', datePaid: '2027-01-31');

      final current = (await repo.watchPeriods().first).first;

      // 31 Jan + 1 month clamps to 28 Feb, so the period ends 27 Feb.
      expect(current.end, DateTime(2027, 2, 27));
    });

    test('watchPeriods switches to a salary recorded while watching',
        () async {
      await seedSalary(id: 'old', datePaid: '2026-09-04');
      final seen = <DateTime?>[];
      final sub = repo.watchPeriods().listen((p) => seen.add(p.first.start));
      await pumpEventQueue();
      await seedSalary(id: 'new', datePaid: '2026-09-23');
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.last, DateTime(2026, 9, 23));
    });

    test('watchPeriods updates when an entry is saved', () async {
      await seedSalary(datePaid: _fmt(DateTime.now()));
      final stream = repo.watchPeriods();
      final seen = <int>[];
      final sub = stream.listen((p) => seen.add(p.first.spentPiastres));
      await pumpEventQueue();
      await repo.saveEntry(const DraftEntry(
          amountPiastres: 700, categoryKey: 'Food', source: EntrySource.manual));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.last, 700);
    });
  });
}
