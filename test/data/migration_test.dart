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
import '../generated_migrations/schema_v4.dart' as v4;

/// Proves the upgrade to schema v4 keeps every row the phone already has,
/// whichever schema it was installed on (v1, v2 or v3), that the additive
/// v3 changes (photo backfill into `attachments`, `categories.colorKey`)
/// land on older data, and that v4's item unit columns start empty so every
/// existing product behaves exactly as before. Built from
/// `drift_schemas/drift_schema_v{1,2,3,4}.json` via
/// `dart run drift_dev schema generate --data-classes --companions`.
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

  /// Drift's generated v3+ schemas store a date-time as unix seconds.
  int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  final seedItems = rows('items');

  /// Every catalogue item survives with its price, and none is sold by a
  /// unit until the user says so in the product editor.
  Future<void> validateItems(v4.DatabaseAtV4 db) async {
    final items = await db.select(db.items).get();
    expect(items, hasLength(seedItems.length),
        reason: 'no product may be lost by the migration');
    final priceOf = {for (final i in items) i.id: i.defaultAmountPiastres};
    for (final i in seedItems) {
      expect(priceOf[i['id']], i['defaultAmountPiastres'],
          reason: 'a product keeps its price');
    }
    for (final i in items) {
      expect(i.unit, isNull);
      expect(i.defaultQuantityMilli, isNull);
    }
  }

  Future<void> validate(v4.DatabaseAtV4 db) async {
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

    await validateItems(db);

    final fkViolations =
        await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fkViolations, isEmpty);
  }

  test(
      'migrating v1 to v4 keeps every entry, the money total, the salary '
      'rows and the products, and backfills photos into attachments',
      () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 4,
      createOld: v1.DatabaseAtV1.new,
      createNew: v4.DatabaseAtV4.new,
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
      validateItems: (v4.DatabaseAtV4 newDb) async {
        await validate(newDb);
        final subcategories = await newDb.select(newDb.subcategories).get();
        expect(subcategories, hasLength(27),
            reason: 'the v1 -> v2 step still seeds the subcategory catalogue');
      },
    );
  });

  test(
      'migrating v2 to v4 keeps every entry, the money total, the salary '
      'rows and the products, and backfills photos into attachments',
      () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 4,
      createOld: v2.DatabaseAtV2.new,
      createNew: v4.DatabaseAtV4.new,
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
      validateItems: (v4.DatabaseAtV4 newDb) async {
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
  test(
      'migrating v3 to v4 keeps every entry, the money total, the salary '
      'rows, the products and everything v3 recorded', () async {
    const groupId = 'group-voice-1';
    // The v3 app records quantities, units and unit prices on entries:
    // every fifth seed entry is "2 كيلو at half its amount".
    bool weighed(int n) => n % 5 == 0;
    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, [
          for (final c in rows('categories'))
            v3.CategoriesCompanion.insert(
              key: c['key'] as String,
              labelAr: c['labelAr'] as String,
              iconName: c['iconName'] as String,
              colorKey: Value(c['key'] as String),
              sortOrder: Value(c['sortOrder'] as int? ?? 0),
            ),
          v3.CategoriesCompanion.insert(
            key: customCategoryKey,
            labelAr: 'قهوة',
            iconName: 'local_cafe',
            colorKey: const Value('Other'),
          ),
        ]);
        batch.insertAll(oldDb.subcategories, [
          for (final s in rows('subcategories'))
            v3.SubcategoriesCompanion.insert(
              key: s['key'] as String,
              categoryKey: s['categoryKey'] as String,
              labelAr: s['labelAr'] as String? ?? s['key'] as String,
              iconName: s['iconName'] as String? ?? 'category',
            ),
        ]);
        batch.insertAll(oldDb.items, [
          for (final i in seedItems)
            v3.ItemsCompanion.insert(
              id: i['id'] as String,
              nameAr: i['nameAr'] as String,
              nameEn: i['nameEn'] as String,
              categoryKey: i['categoryKey'] as String,
              subcategoryKey: Value(i['subcategoryKey'] as String?),
              defaultAmountPiastres: Value(i['defaultAmountPiastres'] as int?),
              useCount: Value(i['useCount'] as int? ?? 0),
            ),
        ]);
        batch.insert(
          oldDb.captureGroups,
          v3.CaptureGroupsCompanion.insert(
            id: groupId,
            kind: 'voice',
            status: 'saved',
            rawText: const Value('اتنين كيلو طماطم ب ٣٠'),
            date: '2026-09-20',
            createdAt: secs(DateTime(2026, 9, 20)),
            updatedAt: secs(DateTime(2026, 9, 20)),
          ),
        );
        batch.insertAll(oldDb.entries, [
          for (var n = 0; n < seedEntries.length; n++)
            v3.EntriesCompanion.insert(
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
              createdAt: secs(at(seedEntries[n]['createdAt'])),
              updatedAt: secs(at(seedEntries[n]['updatedAt'])),
              quantityMilli: Value(weighed(n) ? 2000 : null),
              unit: Value(weighed(n) ? 'kg' : null),
              unitPricePiastres: Value(weighed(n)
                  ? (seedEntries[n]['amountPiastres'] as int) ~/ 2
                  : null),
              captureGroupId: Value(weighed(n) ? groupId : null),
              externalId: Value('ext-$n'),
            ),
          v3.EntriesCompanion.insert(
            id: 'entry-deleted',
            date: '2026-09-10',
            amountPiastres: 1500,
            categoryKey: 'Snacks',
            createdAt: secs(DateTime(2026, 9, 10)),
            updatedAt: secs(DateTime(2026, 9, 10)),
            deletedAt: Value(secs(DateTime(2026, 9, 11))),
          ),
          v3.EntriesCompanion.insert(
            id: 'entry-custom',
            date: '2026-09-12',
            amountPiastres: 4000,
            categoryKey: customCategoryKey,
            createdAt: secs(DateTime(2026, 9, 12)),
            updatedAt: secs(DateTime(2026, 9, 12)),
            reference: const Value('IP-123'),
          ),
        ]);
        batch.insertAll(oldDb.attachments, [
          for (final id in photoEntryIds)
            v3.AttachmentsCompanion.insert(
              id: 'photo-$id',
              entryId: Value(id),
              kind: 'photo',
              path: Value('photos/$id.jpg'),
              createdAt: secs(DateTime(2026, 9, 1)),
            ),
          v3.AttachmentsCompanion.insert(
            id: 'voice-1',
            captureGroupId: const Value(groupId),
            kind: 'voice',
            path: const Value('attachments/2026-09/voice-1.m4a'),
            transcript: const Value('اتنين كيلو طماطم ب ٣٠'),
            durationMs: const Value(4200),
            createdAt: secs(DateTime(2026, 9, 20)),
          ),
        ]);
        batch.insert(
          oldDb.itemAliases,
          v3.ItemAliasesCompanion.insert(
            alias: 'انودي',
            itemId: seedItems.first['id'] as String,
            createdAt: secs(DateTime(2026, 9, 20)),
          ),
        );
        batch.insert(
          oldDb.appSettings,
          v3.AppSettingsCompanion.insert(
              key: 'last_payment_method', value: 'InstaPay'),
        );
        batch.insertAll(oldDb.salaryPeriods, [
          for (final s in seedSalaries)
            v3.SalaryPeriodsCompanion.insert(
              id: s['id'] as String,
              datePaid: s['datePaid'] as String,
              amountPiastres: s['amountPiastres'] as int,
              note: Value(s['note'] as String?),
              externalId: Value('salary-${s['id']}'),
            ),
        ]);
      },
      validateItems: (v4.DatabaseAtV4 db) async {
        final entries = await db.select(db.entries).get();
        expect(entries, hasLength(expectedEntryCount));
        expect(entries.fold<int>(0, (sum, e) => sum + e.amountPiastres),
            expectedMoney,
            reason: 'the money must not move during a migration');
        final byId = {for (final e in entries) e.id: e};
        for (var n = 0; n < seedEntries.length; n++) {
          final e = byId[seedEntries[n]['id']]!;
          expect(e.quantityMilli, weighed(n) ? 2000 : null);
          expect(e.unit, weighed(n) ? 'kg' : null);
          expect(e.captureGroupId, weighed(n) ? groupId : null);
          expect(e.externalId, 'ext-$n');
        }
        expect(byId['entry-custom']!.reference, 'IP-123');
        expect(entries.where((e) => e.deletedAt != null), hasLength(1));

        final salaries = await (db.select(db.salaryPeriods)
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
        expect(
            [
              for (final s in salaries)
                (s.id, s.datePaid, s.amountPiastres, s.externalId)
            ],
            [
              for (final s in seedSalaries)
                (s['id'], s['datePaid'], s['amountPiastres'],
                    'salary-${s['id']}'),
            ]);

        await validateItems(db);
        expect(await db.select(db.captureGroups).get(), hasLength(1));
        expect(await db.select(db.attachments).get(),
            hasLength(photoEntryIds.length + 1));
        expect((await db.select(db.itemAliases).get()).single.alias, 'انودي');
        expect((await db.select(db.appSettings).get()).single.value,
            'InstaPay');
        expect(await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty);
      },
    );
  });
}
