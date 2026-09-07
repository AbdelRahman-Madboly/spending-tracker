import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v1.dart' as v1;
import '../generated_migrations/schema_v2.dart' as v2;

/// Proves the v1 -> v2 migration is additive: it introduces the
/// Subcategories table and the two nullable `subcategoryKey` columns
/// without touching a single row of the user's real, already-installed
/// spending history. Built from `drift_schemas/drift_schema_v{1,2}.json`
/// via `dart run drift_dev schema generate`.
void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  // The ten categories every real installation has from onCreate, so the
  // full subcategory seed (which references all ten) can migrate in
  // cleanly under the same foreign-key enforcement the real app runs
  // with.
  const categoryKeys = [
    'Drinks',
    'Snacks',
    'Food',
    'Transport',
    'Bills',
    'Personal Care',
    'Shopping',
    'Family/Social',
    'Gifts',
    'Loans',
  ];

  test(
      'migrating v1 to v2 preserves every item, entry and salary period '
      'with its amount intact, and adds the subcategory catalogue', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, [
          for (final key in categoryKeys)
            v1.CategoriesCompanion.insert(
              key: key,
              labelAr: key,
              iconName: 'category',
            ),
        ]);
        batch.insertAll(oldDb.items, [
          v1.ItemsCompanion.insert(
            id: 'item-01',
            nameAr: 'شويبس',
            nameEn: 'Schweppes',
            categoryKey: 'Drinks',
            defaultAmountPiastres: const Value(4000),
            useCount: const Value(5),
          ),
        ]);
        batch.insertAll(oldDb.entries, [
          v1.EntriesCompanion.insert(
            id: 'entry-001',
            date: '2026-01-01',
            amountPiastres: 3500,
            categoryKey: 'Drinks',
            itemId: const Value('item-01'),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          v1.EntriesCompanion.insert(
            id: 'entry-002',
            date: '2026-01-02',
            amountPiastres: 1000,
            categoryKey: 'Food',
            createdAt: DateTime(2026, 1, 2),
            updatedAt: DateTime(2026, 1, 2),
          ),
        ]);
        batch.insertAll(oldDb.salaryPeriods, [
          v1.SalaryPeriodsCompanion.insert(
            id: 'sp-1',
            datePaid: '2026-01-01',
            amountPiastres: 900000,
          ),
        ]);
      },
      validateItems: (v2.DatabaseAtV2 newDb) async {
        final items = await newDb.select(newDb.items).get();
        expect(items, hasLength(1));
        expect(items.single.id, 'item-01');
        expect(items.single.nameAr, 'شويبس');
        expect(items.single.defaultAmountPiastres, 4000);
        expect(items.single.subcategoryKey, isNull,
            reason: 'a pre-existing item has no subcategory yet');

        final entries = await newDb.select(newDb.entries).get();
        expect(entries, hasLength(2));
        final total = entries.fold<int>(0, (sum, e) => sum + e.amountPiastres);
        expect(total, 4500,
            reason: 'the money must not move during a migration');
        for (final e in entries) {
          expect(e.subcategoryKey, isNull,
              reason: 'a pre-existing entry has no subcategory yet');
        }

        final salaryPeriods = await newDb.select(newDb.salaryPeriods).get();
        expect(salaryPeriods, hasLength(1));
        expect(salaryPeriods.single.amountPiastres, 900000);

        final subcategories = await newDb.select(newDb.subcategories).get();
        expect(subcategories.length, 27,
            reason: 'the migration must seed the full subcategory catalogue '
                'for an upgrading installation, not just create the table');
      },
    );
  });
}
