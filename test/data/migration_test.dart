import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v1.dart' as v1;
import '../generated_migrations/schema_v2.dart' as v2;
import '../generated_migrations/schema_v3.dart' as v3;

/// Proves the upgrade to schema v3 keeps every row the phone already has,
/// whichever schema it was installed on (v1 or v2), and that the additive
/// v3 changes (photo backfill into `attachments`, `categories.colorKey`)
/// land on that data. Built from `drift_schemas/drift_schema_v{1,2,3}.json`
/// via `dart run drift_dev schema generate --data-classes --companions`.
///
/// The rows are the sample history from `assets/seed/seed.json` (92
/// entries, 2 salary periods), plus the shapes a phone can hold that the seed does
/// not: entries with a photo, a soft-deleted entry, and a category the user
/// created in settings.
void main() {
  final verifier = SchemaVerifier(GeneratedHelper());
  final seed = jsonDecode(File('assets/seed/seed.json').readAsStringSync())
      as Map<String, dynamic>;
  List<Map<String, dynamic>> rows(String key) =>
      (seed[key] as List).cast<Map<String, dynamic>>();

  final seedEntries = rows('entries');
  final seedSalaries = rows('salaryPeriods');

  // A category the user added from settings: its key is generated, so it
  // has no match in the §7.2 colour table and must fall back to `Other`.
  const customCategoryKey = 'cat-1726000000000';

  // Every seventh entry gets a photo, as the v2 add sheet stores it.
  String? photoFor(int index, String id) =>
      index % 7 == 0 ? 'photos/$id.jpg' : null;

  final photoEntryIds = [
    for (var i = 0; i < seedEntries.length; i++)
      if (photoFor(i, seedEntries[i]['id'] as String) != null)
        seedEntries[i]['id'] as String,
  ];

  // Two rows on top of the seed: one soft-deleted (still a row, still has
  // to survive), one under the custom category.
  const extraEntryCount = 2;
  const extraEntryPiastres = 1500 + 4000;
  final expectedEntryCount = seedEntries.length + extraEntryCount;
  final expectedMoney = seedEntries.fold<int>(
          0, (sum, e) => sum + (e['amountPiastres'] as int)) +
      extraEntryPiastres;

  DateTime at(Object? iso) => DateTime.parse(iso as String);

  Future<void> validate(v3.DatabaseAtV3 db) async {
    final entries = await db.select(db.entries).get();
    expect(entries, hasLength(expectedEntryCount),
        reason: 'no entry may be lost by the migration');
    expect(entries.fold<int>(0, (sum, e) => sum + e.amountPiastres),
        expectedMoney,
        reason: 'the money must not move during a migration');
    for (final e in entries) {
      expect(e.quantityMilli, isNull);
      expect(e.unit, isNull);
      expect(e.unitPricePiastres, isNull);
      expect(e.captureGroupId, isNull);
      expect(e.externalId, isNull);
      expect(e.reference, isNull);
    }
    expect(entries.where((e) => e.deletedAt != null), hasLength(1));

    final salaries = await (db.select(db.salaryPeriods)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    expect([for (final s in salaries) (s.id, s.datePaid, s.amountPiastres)], [
      for (final s in seedSalaries)
        (s['id'], s['datePaid'], s['amountPiastres']),
    ]);
    expect(salaries.every((s) => s.externalId == null), isTrue);

    final attachments = await db.select(db.attachments).get();
    expect(attachments.map((a) => a.entryId).toSet(), photoEntryIds.toSet(),
        reason: 'every entry with a photoPath gets exactly one attachment');
    expect(attachments, hasLength(photoEntryIds.length));
    for (final a in attachments) {
      expect(a.kind, 'photo');
      expect(a.path, 'photos/${a.entryId}.jpg');
      expect(a.captureGroupId, isNull);
    }
    // photoPath is kept, never rewritten: the migration is additive.
    final withPhoto = entries.where((e) => e.photoPath != null);
    expect(withPhoto.map((e) => e.id).toSet(), photoEntryIds.toSet());

    final categories = await db.select(db.categories).get();
    final colorOf = {for (final c in categories) c.key: c.colorKey};
    for (final key in rows('categories').map((c) => c['key'] as String)) {
      expect(colorOf[key], key,
          reason: 'a seeded category takes its own key as its colour');
    }
    expect(colorOf[customCategoryKey], 'Other');

    final fkViolations =
        await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fkViolations, isEmpty);
  }

  test(
      'migrating v1 to v3 keeps every entry, the money total and the salary '
      'rows, and backfills photos into attachments', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 3,
      createOld: v1.DatabaseAtV1.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, [
          for (final c in rows('categories'))
            v1.CategoriesCompanion.insert(
              key: c['key'] as String,
              labelAr: c['labelAr'] as String,
              iconName: c['iconName'] as String,
              sortOrder: Value(c['sortOrder'] as int? ?? 0),
            ),
          v1.CategoriesCompanion.insert(
            key: customCategoryKey,
            labelAr: 'قهوة',
            iconName: 'local_cafe',
          ),
        ]);
        batch.insertAll(oldDb.items, [
          for (final i in rows('items'))
            v1.ItemsCompanion.insert(
              id: i['id'] as String,
              nameAr: i['nameAr'] as String,
              nameEn: i['nameEn'] as String,
              categoryKey: i['categoryKey'] as String,
              defaultAmountPiastres: Value(i['defaultAmountPiastres'] as int?),
              useCount: Value(i['useCount'] as int? ?? 0),
            ),
        ]);
        batch.insertAll(oldDb.entries, [
          for (var n = 0; n < seedEntries.length; n++)
            v1.EntriesCompanion.insert(
              id: seedEntries[n]['id'] as String,
              date: seedEntries[n]['date'] as String,
              amountPiastres: seedEntries[n]['amountPiastres'] as int,
              categoryKey: seedEntries[n]['categoryKey'] as String,
              itemId: Value(seedEntries[n]['itemId'] as String?),
              description:
                  Value(seedEntries[n]['description'] as String? ?? ''),
              photoPath:
                  Value(photoFor(n, seedEntries[n]['id'] as String)),
              createdAt: at(seedEntries[n]['createdAt']),
              updatedAt: at(seedEntries[n]['updatedAt']),
            ),
          v1.EntriesCompanion.insert(
            id: 'entry-deleted',
            date: '2026-09-10',
            amountPiastres: 1500,
            categoryKey: 'Snacks',
            createdAt: DateTime(2026, 9, 10),
            updatedAt: DateTime(2026, 9, 10),
            deletedAt: Value(DateTime(2026, 9, 11)),
          ),
          v1.EntriesCompanion.insert(
            id: 'entry-custom',
            date: '2026-09-12',
            amountPiastres: 4000,
            categoryKey: customCategoryKey,
            createdAt: DateTime(2026, 9, 12),
            updatedAt: DateTime(2026, 9, 12),
          ),
        ]);
        batch.insertAll(oldDb.salaryPeriods, [
          for (final s in seedSalaries)
            v1.SalaryPeriodsCompanion.insert(
              id: s['id'] as String,
              datePaid: s['datePaid'] as String,
              amountPiastres: s['amountPiastres'] as int,
              note: Value(s['note'] as String?),
            ),
        ]);
      },
      validateItems: (v3.DatabaseAtV3 newDb) async {
        await validate(newDb);
        final subcategories = await newDb.select(newDb.subcategories).get();
        expect(subcategories, hasLength(27),
            reason: 'the v1 -> v2 step still seeds the subcategory catalogue');
      },
    );
  });

  test(
      'migrating v2 to v3 keeps every entry, the money total and the salary '
      'rows, and backfills photos into attachments', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, [
          for (final c in rows('categories'))
            v2.CategoriesCompanion.insert(
              key: c['key'] as String,
              labelAr: c['labelAr'] as String,
              iconName: c['iconName'] as String,
              sortOrder: Value(c['sortOrder'] as int? ?? 0),
            ),
          v2.CategoriesCompanion.insert(
            key: customCategoryKey,
            labelAr: 'قهوة',
            iconName: 'local_cafe',
          ),
        ]);
        batch.insertAll(oldDb.subcategories, [
          for (final s in rows('subcategories'))
            v2.SubcategoriesCompanion.insert(
              key: s['key'] as String,
              categoryKey: s['categoryKey'] as String,
              // The seed file carries only keys for subcategories; the
              // labels are not what this test checks.
              labelAr: s['labelAr'] as String? ?? s['key'] as String,
              iconName: s['iconName'] as String? ?? 'category',
            ),
        ]);
        batch.insertAll(oldDb.items, [
          for (final i in rows('items'))
            v2.ItemsCompanion.insert(
              id: i['id'] as String,
              nameAr: i['nameAr'] as String,
              nameEn: i['nameEn'] as String,
              categoryKey: i['categoryKey'] as String,
              subcategoryKey: Value(i['subcategoryKey'] as String?),
              defaultAmountPiastres: Value(i['defaultAmountPiastres'] as int?),
              useCount: Value(i['useCount'] as int? ?? 0),
            ),
        ]);
        batch.insertAll(oldDb.entries, [
          for (var n = 0; n < seedEntries.length; n++)
            v2.EntriesCompanion.insert(
              id: seedEntries[n]['id'] as String,
              date: seedEntries[n]['date'] as String,
              amountPiastres: seedEntries[n]['amountPiastres'] as int,
              categoryKey: seedEntries[n]['categoryKey'] as String,
              subcategoryKey:
                  Value(seedEntries[n]['subcategoryKey'] as String?),
              itemId: Value(seedEntries[n]['itemId'] as String?),
              description:
                  Value(seedEntries[n]['description'] as String? ?? ''),
              paymentMethod:
                  Value(seedEntries[n]['paymentMethod'] as String? ?? 'Cash'),
              photoPath:
                  Value(photoFor(n, seedEntries[n]['id'] as String)),
              createdAt: at(seedEntries[n]['createdAt']),
              updatedAt: at(seedEntries[n]['updatedAt']),
            ),
          v2.EntriesCompanion.insert(
            id: 'entry-deleted',
            date: '2026-09-10',
            amountPiastres: 1500,
            categoryKey: 'Snacks',
            subcategoryKey: const Value('Chips'),
            createdAt: DateTime(2026, 9, 10),
            updatedAt: DateTime(2026, 9, 10),
            deletedAt: Value(DateTime(2026, 9, 11)),
          ),
          v2.EntriesCompanion.insert(
            id: 'entry-custom',
            date: '2026-09-12',
            amountPiastres: 4000,
            categoryKey: customCategoryKey,
            createdAt: DateTime(2026, 9, 12),
            updatedAt: DateTime(2026, 9, 12),
          ),
        ]);
        batch.insertAll(oldDb.salaryPeriods, [
          for (final s in seedSalaries)
            v2.SalaryPeriodsCompanion.insert(
              id: s['id'] as String,
              datePaid: s['datePaid'] as String,
              amountPiastres: s['amountPiastres'] as int,
              note: Value(s['note'] as String?),
            ),
        ]);
      },
      validateItems: (v3.DatabaseAtV3 newDb) async {
        await validate(newDb);
        final entries = await newDb.select(newDb.entries).get();
        final bySubcategory = {
          for (final e in seedEntries) e['id']: e['subcategoryKey'],
        };
        for (final e in entries.where((e) => bySubcategory.containsKey(e.id))) {
          expect(e.subcategoryKey, bySubcategory[e.id],
              reason: 'v2 subcategory links survive untouched');
        }
      },
    );
  });
}
