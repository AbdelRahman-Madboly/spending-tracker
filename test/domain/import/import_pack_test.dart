import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/import/import_pack.dart';

ImportPack _bundled(String file) => parseImportPack(
      file,
      File('assets/import/$file').readAsStringSync(),
    );

void main() {
  group('Samsung notes pack', () {
    final pack = _bundled('samsung_notes_2026-09.json');

    test('reads every row but the one marked skip', () {
      expect(pack.rows, hasLength(17));
      expect(pack.skipped, 1);
      expect(pack.rows.map((r) => r.ref), isNot(contains('sn-018')));
    });

    test('identifies each row as pack:<file>:<ref>', () {
      expect(pack.rows.first.externalId,
          'pack:samsung_notes_2026-09.json:sn-001');
    });

    test('reads money, date, category, item and flags as recorded', () {
      final row = pack.rows.firstWhere((r) => r.ref == 'sn-007');
      expect(row.amountPiastres, 2400);
      expect(row.date, DateTime(2026, 9, 10));
      expect(row.description, 'إندومي');
      expect(row.categoryKey, 'Food');
      expect(row.subcategoryKey, 'Lunch');
      expect(row.itemId, 'item-05');
      expect(row.paymentMethod, 'Cash');
      expect(row.rawText, 'انودي ١٢ اتنين');
      expect(row.flags, hasLength(1));
      expect(row.flags.single, startsWith('amount_ambiguous'));
    });

    test('turns a quantity and Arabic unit into milli-units and a unit key',
        () {
      final row = pack.rows.firstWhere((r) => r.ref == 'sn-016');
      expect(row.quantityMilli, 5000);
      expect(row.unit, 'piece');
      final bags = pack.rows.firstWhere((r) => r.ref == 'sn-006');
      expect(bags.quantityMilli, 3000);
      expect(bags.unit, 'bag');
    });

    test('a single plain count stores no quantity', () {
      final row = pack.rows.firstWhere((r) => r.ref == 'sn-001');
      expect(row.quantityMilli, isNull);
      expect(row.unit, isNull);
    });

    test('lines of one note and day share a group', () {
      final taxi = pack.rows.firstWhere((r) => r.ref == 'sn-001');
      final metro = pack.rows.firstWhere((r) => r.ref == 'sn-002');
      final haircut = pack.rows.firstWhere((r) => r.ref == 'sn-009');
      expect(taxi.groupKey, metro.groupKey);
      expect(taxi.groupKey, isNot(haircut.groupKey));
    });

    test('carries the catalogue additions', () {
      expect(pack.additions.categories.map((c) => c.key), ['Health']);
      expect(pack.additions.categories.single.labelAr, 'صحة');
      expect(pack.additions.subcategories.map((s) => s.key),
          ['Medicine', 'Laundry', 'FamilySupport']);
      final laundry = pack.additions.subcategories[1];
      expect(laundry.categoryKey, 'Personal Care');
      expect(laundry.labelAr, 'مغسلة');
    });
  });

  group('manual pack', () {
    final pack = _bundled('manual_2026-09.json');

    test('reads every entry and the salary period', () {
      expect(pack.rows, hasLength(7));
      expect(pack.salaries, hasLength(1));
      final salary = pack.salaries.single;
      expect(salary.externalId, 'pack:manual_2026-09.json:sal-2026-09-30');
      expect(salary.datePaid, DateTime(2026, 9, 30));
      expect(salary.amountPiastres, 900000);
      expect(salary.evidence, 'evidence/2026-09-30_Sample-Salary.png');
      expect(salary.note, contains('InstaPay'));
    });

    test('rows of one captureGroup share a group, others stand alone', () {
      final order = pack.rows
          .where((r) => ['man-004', 'man-005', 'man-006'].contains(r.ref))
          .map((r) => r.groupKey)
          .toSet();
      expect(order, hasLength(1));
      final transfer = pack.rows.firstWhere((r) => r.ref == 'man-001');
      final bundle = pack.rows.firstWhere((r) => r.ref == 'man-002');
      expect(transfer.groupKey, isNot(bundle.groupKey));
    });

    test('keeps unit price, barcode, reference, note and evidence', () {
      final row = pack.rows.firstWhere((r) => r.ref == 'man-005');
      expect(row.quantityMilli, 3000);
      expect(row.unitPricePiastres, 4000);
      expect(row.barcode, '2000000000015');
      expect(row.reference, 'Sample Electronics order #1001');
      expect(row.evidence, 'evidence/2026-09-25_Sample-Order-1001_slip.pdf');
      final internet = pack.rows.firstWhere((r) => r.ref == 'man-007');
      expect(internet.note, startsWith('Plan Home Internet sample'));
    });
  });

  group('work tracker pack', () {
    final pack = parseImportPack('work_tracker.json', '''
{"format": "work-tracker-sync/1", "entries": [
 {"externalId": "wt-seeded", "seedEntryId": "entry-001", "packRef": null,
  "date": "2026-09-02", "amountPiastres": 1500, "description": "Taxi",
  "categoryKey": "Transport", "subcategoryKey": "Taxi", "itemId": "item-07",
  "paymentMethod": "Cash", "source": "import", "evidence": null},
 {"externalId": "wt-in-pack", "seedEntryId": null,
  "packRef": "manual_2026-09.json:man-003",
  "date": "2026-09-24", "amountPiastres": 30000, "description": "Gift",
  "categoryKey": "Gifts", "subcategoryKey": "Gifts", "itemId": null,
  "paymentMethod": "Cash", "source": "import", "evidence": null},
 {"externalId": "wt-new", "seedEntryId": null, "packRef": null,
  "date": "2026-09-27", "amountPiastres": 4500, "description": "Lunch",
  "categoryKey": "Food", "subcategoryKey": "Lunch", "itemId": null,
  "paymentMethod": "Cash", "source": "import", "evidence": null}],
 "salaryPeriods": [
 {"externalId": "wt-sal-seeded", "seedSalaryId": "sp-1", "packRef": null,
  "datePaid": "2026-09-01", "amountPiastres": 900000, "note": "period",
  "evidence": null}]}''');

    test('skips rows already seeded or carried by another pack', () {
      expect(pack.rows.map((r) => r.externalId), ['wt-new']);
      expect(pack.skipped, 2 + 1);
    });

    test('imports no salary period that is seeded or in another pack', () {
      expect(pack.salaries, isEmpty);
    });

    test('a salary with neither a seed id nor a pack ref is imported', () {
      final pack = parseImportPack('work_tracker.json', '''
{"format": "work-tracker-sync/1", "entries": [], "salaryPeriods": [
 {"externalId": "wt-sal-2026-10-20", "seedSalaryId": null, "packRef": null,
  "datePaid": "2026-10-20", "amountPiastres": 900000, "note": "period",
  "evidence": null}]}''');
      expect(pack.salaries.single.externalId, 'wt-sal-2026-10-20');
      expect(pack.skipped, 0);
    });
  });

  test('an unknown format is refused', () {
    expect(() => parseImportPack('x.json', '{"format": "other/1"}'),
        throwsFormatException);
    expect(() => parseImportPack('x.json', 'not json'), throwsFormatException);
  });
}
