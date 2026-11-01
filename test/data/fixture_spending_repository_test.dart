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

  test('spentInMonth totals the fixture entries, all dated in September 2026',
      () async {
    expect(await repo.spentInMonth(2026, 9), 8500);
    expect(await repo.spentInMonth(2026, 8), 0);
  });

  test('monthlyTotals is oldest-first, ends at the fixture\'s "today" month, '
      'and zero-fills months with no data', () async {
    final totals = await repo.monthlyTotals(3);
    expect(totals.length, 3);
    expect(totals.map((t) => t.yearMonth).toList(),
        ['2026-07', '2026-08', '2026-09']);
    expect(totals.last.totalPiastres, 8500);
    expect(totals[0].totalPiastres, 0);
    expect(totals[1].totalPiastres, 0);
  });

  test('saving an entry adds it to today', () async {
    final before =
        (await repo.watchEntriesForDay(DateTime(2026, 9, 6)).first).length;
    await repo.saveEntry(const DraftEntry(
      amountPiastres: 3500,
      description: 'لبن',
      categoryKey: 'Food',
      paymentMethod: 'Cash',
      source: EntrySource.quickPick,
    ));
    final after =
        (await repo.watchEntriesForDay(DateTime(2026, 9, 6)).first).length;
    expect(after, before + 1);
  });

  test(
      'dailyTotals is oldest-first, ends at the fixture\'s "today" '
      '(2026-09-06), and zero-fills days with no spending', () async {
    final totals = await repo.dailyTotals(7);

    expect(totals.length, 7);
    expect(totals.map((t) => t.label).toList(),
        ['31', '1', '2', '3', '4', '5', '6']);
    // 2026-09-05: إندومي 1000 + شويبس 4000 = 5000.
    expect(totals[5].totalPiastres, 5000);
    // 2026-09-06: لبن 3500.
    expect(totals[6].totalPiastres, 3500);
    expect(totals.take(5).every((t) => t.totalPiastres == 0), isTrue);
  });

  test(
      'weeklyTotals is oldest-first and its last bucket spans the '
      'July/August-to-September boundary, picking up all of the fixture\'s '
      'spending while every earlier week zero-fills', () async {
    final totals = await repo.weeklyTotals(6);

    expect(totals.length, 6);
    expect(
      totals.map((t) => t.label).toList(),
      ['27', '3', '10', '17', '24', '31'],
    );
    // Last bucket (2026-08-31..2026-09-06) crosses the August/September
    // boundary and contains all three fixture entries.
    expect(totals.last.totalPiastres, 8500);
    expect(totals.take(5).every((t) => t.totalPiastres == 0), isTrue);
  });

  test('updateItem changes an item\'s name, category and price in place',
      () async {
    await repo.updateItem(
      itemId: 'i1',
      nameAr: 'شويبس مانجا',
      categoryKey: 'Snacks',
      defaultAmountPiastres: 4500,
    );

    final items = await repo.allItems();
    final updated = items.firstWhere((i) => i.id == 'i1');
    expect(updated.nameAr, 'شويبس مانجا');
    expect(updated.categoryKey, 'Snacks');
    expect(updated.defaultAmountPiastres, 4500);
  });

  test('createItem stores the given barcode, and itemByBarcode resolves it',
      () async {
    final created = await repo.createItem(
      nameAr: 'مياه',
      categoryKey: 'Drinks',
      defaultAmountPiastres: 1000,
      barcode: '6224000123456',
    );

    final found = await repo.itemByBarcode('6224000123456');
    expect(found, isNotNull);
    expect(found!.id, created.id);
  });

  test('itemByBarcode returns null for a code that was never learned',
      () async {
    expect(await repo.itemByBarcode('nope'), isNull);
  });

  test('createCategory adds a new category to categories()', () async {
    final created = await repo.createCategory(
      key: 'Custom1',
      labelAr: 'مخصص',
      iconName: 'pets',
    );
    expect(created.key, 'Custom1');
    final all = await repo.categories();
    expect(all.map((c) => c.key), contains('Custom1'));
  });

  test('updateCategory renames a category without changing its key',
      () async {
    await repo.updateCategory(
        key: 'Food', labelAr: 'أكل وشرب', iconName: 'lunch_dining');
    final food = (await repo.categories()).firstWhere((c) => c.key == 'Food');
    expect(food.labelAr, 'أكل وشرب');
    expect(food.iconName, 'lunch_dining');
  });

  test(
      'archiving a category cascades to its subcategories and items, '
      'without touching past entries', () async {
    final before =
        (await repo.watchEntriesForDay(DateTime(2026, 9, 6)).first).length;

    await repo.archiveCategory('Drinks');

    expect((await repo.categories()).map((c) => c.key),
        isNot(contains('Drinks')));
    expect(await repo.subcategories('Drinks'), isEmpty);
    expect((await repo.allItems()).map((i) => i.categoryKey),
        isNot(contains('Drinks')));

    final after =
        (await repo.watchEntriesForDay(DateTime(2026, 9, 6)).first).length;
    expect(after, before);
  });

  test('createSubcategory adds a new subcategory under a category',
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

  test('updateSubcategory can move a subcategory to a new category',
      () async {
    await repo.updateSubcategory(
      key: 'Haircut',
      categoryKey: 'Shopping',
      labelAr: 'حلاقة',
      iconName: 'content_cut',
    );

    expect((await repo.subcategories('Personal Care')).map((s) => s.key),
        isNot(contains('Haircut')));
    expect((await repo.subcategories('Shopping')).map((s) => s.key),
        contains('Haircut'));
  });

  test('archiveSubcategory cascades to items filed under it', () async {
    await repo.archiveSubcategory('Soda');
    expect((await repo.subcategories('Drinks')).map((s) => s.key),
        isNot(contains('Soda')));
    expect((await repo.allItems()).map((i) => i.id), isNot(contains('i1')));
  });

  test('archivedItems lists archived items, and unarchiveItem restores one',
      () async {
    await repo.archiveItem('i1');
    expect((await repo.archivedItems()).map((i) => i.id), contains('i1'));

    await repo.unarchiveItem('i1');
    expect((await repo.allItems()).map((i) => i.id), contains('i1'));
    expect((await repo.archivedItems()).map((i) => i.id),
        isNot(contains('i1')));
  });

  test(
      'unarchiveCategory restores the category, its subcategories and its '
      'items', () async {
    await repo.archiveCategory('Drinks');
    expect((await repo.categories()).map((c) => c.key),
        isNot(contains('Drinks')));
    expect(await repo.archivedCategories(),
        contains(predicate<CategoryView>((c) => c.key == 'Drinks')));

    await repo.unarchiveCategory('Drinks');

    expect((await repo.categories()).map((c) => c.key), contains('Drinks'));
    expect(await repo.subcategories('Drinks'), isNotEmpty);
    expect((await repo.allItems()).map((i) => i.id), contains('i1'));
    expect(await repo.archivedCategories(), isEmpty);
  });

  test(
      'unarchiveSubcategory restores its items but never its parent '
      'category', () async {
    await repo.archiveCategory('Drinks');
    expect((await repo.categories()).map((c) => c.key),
        isNot(contains('Drinks')));

    await repo.unarchiveSubcategory('Soda');

    expect((await repo.allItems()).map((i) => i.id), contains('i1'));
    expect((await repo.categories()).map((c) => c.key),
        isNot(contains('Drinks')));
  });

  test(
      'a past entry survives an archive-then-unarchive round trip on its '
      'category with every field intact, including its date', () async {
    final before =
        (await repo.watchEntriesForDay(DateTime(2026, 9, 6)).first).single;

    await repo.archiveCategory('Food');
    await repo.unarchiveCategory('Food');

    final after =
        (await repo.watchEntriesForDay(DateTime(2026, 9, 6)).first).single;
    expect(after.categoryKey, before.categoryKey);
    expect(after.amountPiastres, before.amountPiastres);
    expect(after.date, before.date);
  });

  test('archivedCategories and archivedSubcategories list only archived '
      'rows', () async {
    expect(await repo.archivedCategories(), isEmpty);
    expect(await repo.archivedSubcategories(), isEmpty);

    await repo.archiveSubcategory('Soda');

    final archivedSubs = await repo.archivedSubcategories();
    expect(archivedSubs.map((s) => s.key), contains('Soda'));
    expect(await repo.archivedCategories(), isEmpty);
  });
}
