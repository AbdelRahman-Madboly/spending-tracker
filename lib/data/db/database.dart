import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
      );
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
