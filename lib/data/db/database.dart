import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Categories, Items, Entries, SalaryPeriods])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by tests to run entirely in memory, with no filesystem access.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories(this);
        },
        // SQLite ignores foreign key constraints unless this pragma is set
        // on every connection — drift's `.references()` is otherwise only a
        // compile-time hint, so an invalid categoryKey would be silently
        // accepted. Runs on every open, not just onCreate.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Loads the real historical spending data (assets/seed/seed.json) and
  /// seeds it, but only the first time — safe to call every app start.
  /// The ten categories are already in place by the time this can matter
  /// (seeded in [onCreate]); this only ever adds items, entries and salary
  /// periods, and only when the entries table is still empty.
  Future<void> seedRealDataIfNeeded() async {
    final jsonString = await rootBundle.loadString('assets/seed/seed.json');
    await seedFromJsonString(jsonString);
  }

  /// The pure, asset-free half of [seedRealDataIfNeeded] — takes the seed
  /// JSON as a string so it can be exercised directly in tests without a
  /// Flutter asset bundle. Idempotent: a no-op whenever `entries` already
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
            sortOrder: Value(i),
          ),
        );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'spending.sqlite'));
    // A background isolate buys nothing here: this is a small, single-user
    // local file with modest query volume, and opening in the same isolate
    // avoids an extra isolate to tear down on every dispose.
    return NativeDatabase(file);
  });
}
