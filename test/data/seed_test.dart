import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';

/// Verifies the sample spending history in assets/seed/seed.json loads
/// correctly and completely. Money data, so these checks are deliberately
/// exact rather than approximate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String seedJson;

  setUpAll(() async {
    seedJson = await rootBundle.loadString('assets/seed/seed.json');
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test(
      'seeding loads exactly 92 entries and 2 salary periods totalling '
      '500000 piastres', () async {
    await db.seedFromJsonString(seedJson);

    final entries = await db.select(db.entries).get();
    final salaryPeriods = await db.select(db.salaryPeriods).get();
    final categories = await db.select(db.categories).get();

    expect(entries.length, 92);
    expect(salaryPeriods.length, 2);

    final total = entries.fold<int>(0, (sum, e) => sum + e.amountPiastres);
    expect(total, 500000);

    final categoryKeys = categories.map((c) => c.key).toSet();
    for (final e in entries) {
      expect(
        categoryKeys,
        contains(e.categoryKey),
        reason: 'entry ${e.id} has unknown category ${e.categoryKey}',
      );
    }

    for (final e in entries) {
      expect(
        e.amountPiastres,
        greaterThan(0),
        reason: 'entry ${e.id} has a non-positive amount',
      );
    }
  });

  test('seeding twice does not duplicate data', () async {
    await db.seedFromJsonString(seedJson);
    await db.seedFromJsonString(seedJson);

    final entries = await db.select(db.entries).get();
    final salaryPeriods = await db.select(db.salaryPeriods).get();
    final items = await db.select(db.items).get();

    expect(entries.length, 92);
    expect(salaryPeriods.length, 2);
    expect(items.length, 12);
  });

  test(
      'the item catalogue has no duplicate or English-only Arabic names, '
      'and every item category is real', () async {
    await db.seedFromJsonString(seedJson);

    final items = await db.select(db.items).get();
    final categories = await db.select(db.categories).get();
    final categoryKeys = categories.map((c) => c.key).toSet();

    expect(items, isNotEmpty);

    final nameArValues = items.map((i) => i.nameAr).toList();
    expect(
      nameArValues.toSet().length,
      nameArValues.length,
      reason: 'two or more items share the same nameAr: $nameArValues',
    );

    final arabicChar = RegExp(r'[؀-ۿ]');
    for (final item in items) {
      expect(
        arabicChar.hasMatch(item.nameAr),
        isTrue,
        reason: 'item ${item.id} has no Arabic character in nameAr: '
            '"${item.nameAr}"',
      );
    }

    for (final item in items) {
      expect(
        categoryKeys,
        contains(item.categoryKey),
        reason: 'item ${item.id} has unknown category ${item.categoryKey}',
      );
    }
  });

  test(
      'every non-null subcategoryKey on an entry or item belongs to its '
      "own row's categoryKey", () async {
    // A subcategory seeded under a different category (e.g. an entry
    // tagged Food with a Drinks subcategory) would be a data-integrity
    // bug, not a valid mapping — this is real money data, so this is
    // checked exactly rather than sampled.
    await db.seedFromJsonString(seedJson);

    final entries = await db.select(db.entries).get();
    final items = await db.select(db.items).get();
    final subcategories = await db.select(db.subcategories).get();
    final categoryKeyBySubcategoryKey = {
      for (final s in subcategories) s.key: s.categoryKey,
    };

    expect(subcategories, isNotEmpty);

    var entriesWithSubcategory = 0;
    for (final e in entries) {
      final subcategoryKey = e.subcategoryKey;
      if (subcategoryKey == null) continue;
      entriesWithSubcategory++;
      expect(
        categoryKeyBySubcategoryKey,
        contains(subcategoryKey),
        reason: 'entry ${e.id} has unknown subcategory $subcategoryKey',
      );
      expect(
        categoryKeyBySubcategoryKey[subcategoryKey],
        e.categoryKey,
        reason: 'entry ${e.id} is categoryKey ${e.categoryKey} but its '
            'subcategory $subcategoryKey belongs to '
            '${categoryKeyBySubcategoryKey[subcategoryKey]}',
      );
    }
    expect(entriesWithSubcategory, greaterThan(0));

    var itemsWithSubcategory = 0;
    for (final it in items) {
      final subcategoryKey = it.subcategoryKey;
      if (subcategoryKey == null) continue;
      itemsWithSubcategory++;
      expect(
        categoryKeyBySubcategoryKey,
        contains(subcategoryKey),
        reason: 'item ${it.id} has unknown subcategory $subcategoryKey',
      );
      expect(
        categoryKeyBySubcategoryKey[subcategoryKey],
        it.categoryKey,
        reason: 'item ${it.id} is categoryKey ${it.categoryKey} but its '
            'subcategory $subcategoryKey belongs to '
            '${categoryKeyBySubcategoryKey[subcategoryKey]}',
      );
    }
    expect(itemsWithSubcategory, greaterThan(0));
  });

  test('no catalogue item is built from a single occurrence', () async {
    // A single purchase can't support a meaningful default price (e.g. a
    // lump-sum "juice, drinks, water" hospital-visit line is not a juice
    // price) — every item must be backed by at least two real purchases,
    // and must actually carry a default price once it exists.
    await db.seedFromJsonString(seedJson);

    final items = await db.select(db.items).get();
    expect(items, isNotEmpty);

    for (final item in items) {
      expect(
        item.useCount,
        greaterThanOrEqualTo(2),
        reason: 'item ${item.id} (${item.nameAr}) has useCount '
            '${item.useCount}, below the 2-occurrence threshold',
      );
      expect(
        item.defaultAmountPiastres,
        isNotNull,
        reason: 'item ${item.id} (${item.nameAr}) has no defaultAmountPiastres',
      );
    }
  });
}
