import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'pre_migration_backup.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Items,
  Entries,
  SalaryPeriods,
  Subcategories,
  CaptureGroups,
  Attachments,
  ItemAliases,
  RecurringBills,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by tests to run entirely in memory, with no filesystem access.
  ///
  /// By default this does NOT seed the real historical data — existing
  /// tests build their own synthetic rows and assert exact counts against
  /// them, so mixing in 87 real entries would break those counts. Pass
  /// [seedJsonLoader] to opt a specific test into exercising the real
  /// on-open seeding path (see [migration]'s `onCreate`) with an in-memory
  /// JSON string, without needing `rootBundle` or Flutter's service
  /// bindings — a plain `test()` suite (as opposed to `testWidgets()`)
  /// doesn't have those.
  AppDatabase.forTesting(super.executor, {this.seedJsonLoader});

  /// Loads assets/seed/seed.json. Set at construction: [AppDatabase()]
  /// (the real app) always seeds from the bundled asset; [forTesting]
  /// defaults to `null`, meaning "don't seed real data at all".
  Future<String> Function()? seedJsonLoader = _defaultSeedLoader;

  static Future<String> _defaultSeedLoader() =>
      rootBundle.loadString('assets/seed/seed.json');

  /// The schema this build writes. Also the target the pre-migration
  /// backup compares the on-disk `user_version` against.
  static const latestSchemaVersion = 3;

  @override
  int get schemaVersion => latestSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Seeding the real historical data here — as part of onCreate,
        // rather than as a separate fire-and-forget call after the
        // database is constructed — is what guarantees no query (a
        // one-shot `.get()`/`Future`, or a `.watch()` stream's very first
        // emission) can ever observe an empty, freshly-created database:
        // drift only allows a query to run once the executor has finished
        // opening, which includes running this whole callback to
        // completion. There is no ordering window left for a screen to
        // read a zero salary before the seed has landed.
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories(this);
          await _seedSubcategories(this);
          final loadSeedJson = seedJsonLoader;
          if (loadSeedJson != null) {
            await seedFromJsonString(await loadSeedJson());
          }
        },
        // v1 -> v2 introduces the Subcategories table (the second level of
        // the Category -> Subcategory -> Item structure) plus a nullable
        // `subcategoryKey` on both Items and Entries. This is an additive
        // migration only — it never drops or rewrites an existing table,
        // so every row the user already has on their phone (his real
        // spending history) survives untouched; existing rows simply get
        // `subcategoryKey = NULL` until re-categorised.
        //
        // v2 -> v3 is additive in the same way (spec §5): new nullable
        // columns, five new tables, indexes, and a backfill that only
        // inserts rows or fills columns that did not exist before. No
        // existing value is changed. The file itself was already copied to
        // documents/backups before drift opened it (see
        // [openDatabaseFileWithBackup]).
        //
        // Every step runs in one transaction. SQLite DDL is transactional,
        // so a failure half-way leaves the file exactly on its old version
        // instead of with some columns added, which would make the next
        // attempt fail on "duplicate column".
        onUpgrade: (m, from, to) async {
          await transaction(() async {
            if (from < 2) {
              await m.createTable(subcategories);
              await m.addColumn(items, items.subcategoryKey);
              await m.addColumn(entries, entries.subcategoryKey);
              await _seedSubcategories(this);
            }
            if (from < 3) {
              await _migrateToV3(m);
            }
          });
        },
        // SQLite ignores foreign key constraints unless this pragma is set
        // on every connection — drift's `.references()` is otherwise only a
        // compile-time hint, so an invalid categoryKey would be silently
        // accepted. Runs on every open, not just onCreate.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _migrateToV3(Migrator m) async {
    // capture_groups first: entries.capture_group_id references it.
    await m.createTable(captureGroups);
    await m.addColumn(entries, entries.quantityMilli);
    await m.addColumn(entries, entries.unit);
    await m.addColumn(entries, entries.unitPricePiastres);
    await m.addColumn(entries, entries.captureGroupId);
    await m.addColumn(entries, entries.externalId);
    await m.addColumn(entries, entries.reference);
    await m.addColumn(categories, categories.colorKey);
    await m.addColumn(salaryPeriods, salaryPeriods.externalId);
    await m.createTable(attachments);
    await m.createTable(itemAliases);
    await m.createTable(recurringBills);
    await m.createTable(appSettings);
    for (final index in [
      entriesDate,
      entriesCaptureGroupId,
      entriesDeletedAt,
      entriesExternalId,
      salaryPeriodsExternalId,
      attachmentsEntryId,
      attachmentsCaptureGroupId,
    ]) {
      await m.create(index);
    }

    // One photo attachment per pre-v3 photo. The id is derived from the
    // entry id, so it is unique and stable, and the path is copied as-is
    // (already relative to the documents directory).
    await customStatement(
      'INSERT INTO attachments (id, entry_id, kind, path, created_at) '
      "SELECT 'photo-' || id, id, 'photo', photo_path, created_at "
      'FROM entries WHERE photo_path IS NOT NULL',
    );

    // A category takes its own key as its colour when §7.2 has one for
    // it; a category the user created gets the neutral `Other`.
    final known = categoryColorKeys.map((k) => "'${k.replaceAll("'", "''")}'");
    await customStatement(
      'UPDATE categories SET color_key = CASE WHEN key IN '
      '(${known.join(', ')}) THEN key ELSE \'Other\' END '
      'WHERE color_key IS NULL',
    );
  }

  /// Inserts the parsed seed JSON's items, entries and salary periods, but
  /// only the first time — idempotent, a no-op whenever `entries` already
  /// has rows, so calling this more than once never duplicates data.
  Future<void> seedFromJsonString(String jsonString) async {
    final alreadySeeded =
        await (select(entries)..limit(1)).getSingleOrNull() != null;
    if (alreadySeeded) return;

    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    final entryRows = (data['entries'] as List).cast<Map<String, dynamic>>();
    final salaryRows =
        (data['salaryPeriods'] as List).cast<Map<String, dynamic>>();

    await transaction(() async {
      // Items before entries: entries reference items by id via itemId.
      for (final item in items) {
        await into(this.items).insert(
          ItemsCompanion.insert(
            id: item['id'] as String,
            nameAr: item['nameAr'] as String,
            nameEn: item['nameEn'] as String,
            categoryKey: item['categoryKey'] as String,
            subcategoryKey: Value(item['subcategoryKey'] as String?),
            defaultAmountPiastres: Value(
              item['defaultAmountPiastres'] as int?,
            ),
            barcode: Value(item['barcode'] as String?),
            useCount: Value(item['useCount'] as int? ?? 0),
            lastUsedAt: Value(
              item['lastUsedAt'] == null
                  ? null
                  : DateTime.parse(item['lastUsedAt'] as String),
            ),
            archived: Value(item['archived'] as bool? ?? false),
          ),
        );
      }

      for (final row in entryRows) {
        await into(entries).insert(
          EntriesCompanion.insert(
            id: row['id'] as String,
            date: row['date'] as String,
            amountPiastres: row['amountPiastres'] as int,
            categoryKey: row['categoryKey'] as String,
            subcategoryKey: Value(row['subcategoryKey'] as String?),
            itemId: Value(row['itemId'] as String?),
            description: Value(row['description'] as String? ?? ''),
            paymentMethod: Value(
              row['paymentMethod'] as String? ?? 'Cash',
            ),
            photoPath: Value(row['photoPath'] as String?),
            source: Value(row['source'] as String? ?? 'manual'),
            note: Value(row['note'] as String?),
            createdAt: DateTime.parse(row['createdAt'] as String),
            updatedAt: DateTime.parse(row['updatedAt'] as String),
            deletedAt: Value(
              row['deletedAt'] == null
                  ? null
                  : DateTime.parse(row['deletedAt'] as String),
            ),
          ),
        );
      }

      for (final row in salaryRows) {
        await into(salaryPeriods).insert(
          SalaryPeriodsCompanion.insert(
            id: row['id'] as String,
            datePaid: row['datePaid'] as String,
            amountPiastres: row['amountPiastres'] as int,
            evidencePhotoPath: Value(
              row['evidencePhotoPath'] as String?,
            ),
            note: Value(row['note'] as String?),
          ),
        );
      }
    });
  }
}

/// The colour keys of spec §7.2, one per category family plus `Other`.
/// A category's `colorKey` is always one of these.
const categoryColorKeys = [
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
  'Health',
  'Education',
  'Home',
  'Other',
];

/// The ten fixed categories this app understands. Keys are English and are
/// never shown to the user; labels are Arabic.
const _seedCategoryRows = [
  ('Drinks', 'مشروبات', 'local_drink'),
  ('Snacks', 'سناكس', 'cookie'),
  ('Food', 'أكل', 'restaurant'),
  ('Transport', 'مواصلات', 'directions_bus'),
  ('Bills', 'فواتير', 'receipt_long'),
  ('Personal Care', 'عناية شخصية', 'content_cut'),
  ('Shopping', 'تسوق', 'shopping_bag'),
  ('Family/Social', 'عائلة وزيارات', 'groups'),
  ('Gifts', 'هدايا', 'card_giftcard'),
  ('Loans', 'سلف', 'handshake'),
];

Future<void> _seedCategories(AppDatabase db) async {
  for (var i = 0; i < _seedCategoryRows.length; i++) {
    final (key, labelAr, iconName) = _seedCategoryRows[i];
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            key: key,
            labelAr: labelAr,
            iconName: iconName,
            colorKey: Value(key),
            sortOrder: Value(i),
          ),
        );
  }
}

/// The subcategories seeded under each of the ten categories above — the
/// second level of the Category -> Subcategory -> Item structure. Keys are
/// English and never shown to the user; labels are Arabic.
const _seedSubcategoryRows = [
  ('Soda', 'Drinks', 'صودا', 'local_bar'),
  ('Water', 'Drinks', 'مياه', 'water_drop'),
  ('Milk', 'Drinks', 'لبن', 'local_drink'),
  ('Juice', 'Drinks', 'عصير', 'emoji_food_beverage'),
  ('HotDrinks', 'Drinks', 'مشروبات ساخنة', 'local_cafe'),
  ('Chips', 'Snacks', 'شيبسي', 'tapas'),
  ('Chocolate', 'Snacks', 'شوكولاتة', 'cake'),
  ('Biscuits', 'Snacks', 'بسكوت', 'cookie'),
  ('Sweets', 'Snacks', 'حلويات', 'icecream'),
  ('FastFood', 'Snacks', 'وجبات سريعة', 'fastfood'),
  ('Breakfast', 'Food', 'فطار', 'free_breakfast'),
  ('Lunch', 'Food', 'غدا', 'lunch_dining'),
  ('Dinner', 'Food', 'عشا', 'dinner_dining'),
  ('Groceries', 'Food', 'بقالة', 'local_grocery_store'),
  ('PublicTransport', 'Transport', 'مواصلات عامة', 'directions_bus'),
  ('Taxi', 'Transport', 'تاكسي', 'local_taxi'),
  ('PhoneBill', 'Bills', 'فاتورة موبايل', 'smartphone'),
  ('HomeInternet', 'Bills', 'إنترنت المنزل', 'wifi'),
  ('Haircut', 'Personal Care', 'حلاقة', 'content_cut'),
  ('Cosmetics', 'Personal Care', 'مستحضرات', 'spa'),
  ('Clothes', 'Shopping', 'ملابس', 'checkroom'),
  ('Electronics', 'Shopping', 'إلكترونيات', 'devices'),
  ('OnlineShopping', 'Shopping', 'تسوق أونلاين', 'shopping_cart'),
  ('Trips', 'Family/Social', 'رحلات', 'flight'),
  ('Visits', 'Family/Social', 'زيارات', 'people'),
  ('Gifts', 'Gifts', 'هدايا', 'card_giftcard'),
  ('Loans', 'Loans', 'سلف', 'handshake'),
];

Future<void> _seedSubcategories(AppDatabase db) async {
  for (var i = 0; i < _seedSubcategoryRows.length; i++) {
    final (key, categoryKey, labelAr, iconName) = _seedSubcategoryRows[i];
    await db.into(db.subcategories).insert(
          SubcategoriesCompanion.insert(
            key: key,
            categoryKey: categoryKey,
            labelAr: labelAr,
            iconName: iconName,
            sortOrder: Value(i),
          ),
        );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    return openDatabaseFileWithBackup(
      dbFile: File(p.join(directory.path, 'spending.sqlite')),
      backupsDir: Directory(p.join(directory.path, 'backups')),
    );
  });
}

/// Opens [dbFile], first copying it into [backupsDir] when it is on an
/// older schema than [AppDatabase.latestSchemaVersion] (see
/// [backupBeforeMigration]).
///
/// The copy runs inside the lazy opener, so it finishes before drift ever
/// touches the file: drift only reads `user_version` and runs `onUpgrade`
/// once this returns. If the copy cannot be verified the open fails and
/// the file is left exactly as it was, rather than migrating real data
/// with no way back.
LazyDatabase openDatabaseFileWithBackup({
  required File dbFile,
  required Directory backupsDir,
}) {
  return LazyDatabase(() async {
    await backupBeforeMigration(
      dbFile: dbFile,
      backupsDir: backupsDir,
      targetVersion: AppDatabase.latestSchemaVersion,
    );
    // A background isolate buys nothing here: this is a small, single-user
    // local file with modest query volume, and opening in the same isolate
    // avoids an extra isolate to tear down on every dispose.
    return NativeDatabase(dbFile);
  });
}
