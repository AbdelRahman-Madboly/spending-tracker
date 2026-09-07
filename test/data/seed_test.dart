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

  test('seeding loads exactly 87 entries and 3 salary periods totalling '
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

    expect(entries.length, 87);
    expect(salaryPeriods.length, 3);
    expect(items.length, 13);
  });
}
