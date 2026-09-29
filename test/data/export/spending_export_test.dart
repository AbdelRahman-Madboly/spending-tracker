import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/data/export/spending_export.dart';
import 'package:spending_tracker/domain/models.dart';

/// The worksheet XML of an exported workbook, for the assertions below.
String sheetXml(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final sheet = archive.findFile('xl/worksheets/sheet1.xml')!;
  return utf8.decode(sheet.content);
}

/// Every inline string of a row, in column order.
List<String> rowStrings(String xml, int row) {
  final match = RegExp('<row r="$row"[^>]*>(.*?)</row>').firstMatch(xml);
  if (match == null) return const [];
  return RegExp(
    r'<t xml:space="preserve">(.*?)</t>',
  ).allMatches(match.group(1)!).map((m) => m.group(1)!).toList();
}

String? cellValue(String xml, String ref) =>
    RegExp('<c r="$ref"[^>]*><v>([^<]*)</v></c>').firstMatch(xml)?.group(1);

void main() {
  late AppDatabase db;
  late DriftSpendingRepository repo;
  late SpendingExporter exporter;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftSpendingRepository(db);
    exporter = SpendingExporter(repo);
    await repo.saveCapture(
      CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 9, 20),
        paymentMethod: 'InstaPay',
        lines: const [
          CaptureLine(
            amountPiastres: 3050,
            categoryKey: 'Food',
            description: 'طماطم & خيار',
            quantityMilli: 2500,
            unit: 'كيلو',
            unitPricePiastres: 1220,
            reference: 'TX-99',
            note: 'من السوق',
          ),
        ],
      ),
    );
    await repo.saveCapture(
      CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 8, 3),
        lines: const [
          CaptureLine(
            amountPiastres: 1000,
            categoryKey: 'Drinks',
            description: 'شاي',
          ),
        ],
      ),
    );
    await repo.saveCapture(
      CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2025, 12, 31),
        lines: const [
          CaptureLine(
            amountPiastres: 700,
            categoryKey: 'Food',
            description: 'عيش',
          ),
        ],
      ),
    );
  });

  tearDown(() => db.close());

  test('the header row is the historical Spending Log column shape', () async {
    final xml = sheetXml(await exporter.workbook(const ExportScope.all()));
    expect(rowStrings(xml, 1), [
      'Expense ID',
      'Date',
      'Category',
      'Subcategory',
      'Description',
      'Quantity',
      'Unit price',
      'Amount',
      'Payment',
      'Type',
      'Receipt',
      'Notes',
      'Month',
    ]);
  });

  test('everything lists every live entry oldest first', () async {
    final xml = sheetXml(await exporter.workbook(const ExportScope.all()));
    expect(rowStrings(xml, 2), contains('عيش'));
    expect(rowStrings(xml, 3), contains('شاي'));
    expect(rowStrings(xml, 4), contains('طماطم &amp; خيار'));
    expect(rowStrings(xml, 5), isEmpty);
    expect(rowStrings(xml, 2).first, 'EXP-0001');
    expect(rowStrings(xml, 4).first, 'EXP-0003');
  });

  test('a month holds only that month\'s entries', () async {
    final xml = sheetXml(
      await exporter.workbook(const ExportScope.month(2026, 9)),
    );
    expect(rowStrings(xml, 2), contains('طماطم &amp; خيار'));
    expect(rowStrings(xml, 3), isEmpty);
  });

  test('a year holds only that year\'s entries', () async {
    final xml = sheetXml(await exporter.workbook(const ExportScope.year(2025)));
    expect(rowStrings(xml, 2), contains('عيش'));
    expect(rowStrings(xml, 3), isEmpty);
  });

  test(
    'money and quantities are exact pounds and units, dates are serials',
    () async {
      final xml = sheetXml(
        await exporter.workbook(const ExportScope.month(2026, 9)),
      );
      // 2026-09-20 is Excel serial 46285; the month column is its 1st, 46266.
      expect(cellValue(xml, 'B2'), '46285');
      expect(cellValue(xml, 'M2'), '46266');
      expect(cellValue(xml, 'F2'), '2.5');
      expect(cellValue(xml, 'G2'), '12.2');
      expect(cellValue(xml, 'H2'), '30.5');
      final strings = rowStrings(xml, 2);
      expect(strings, containsAll(['Food', 'InstaPay', 'TX-99']));
      expect(
        strings.any((s) => s.contains('من السوق') && s.contains('كيلو')),
        isTrue,
      );
    },
  );

  test('a deleted entry is not exported', () async {
    final rows = await repo.watchTransactions().first;
    await repo.deleteEntries([
      rows.firstWhere((r) => r.description == 'شاي').id,
    ]);
    final xml = sheetXml(await exporter.workbook(const ExportScope.all()));
    expect(xml, isNot(contains('شاي')));
  });

  test(
    'available periods list the months and years that have entries',
    () async {
      final periods = await exporter.availablePeriods();
      expect(periods.months, [
        (year: 2026, month: 9),
        (year: 2026, month: 8),
        (year: 2025, month: 12),
      ]);
      expect(periods.years, [2026, 2025]);
    },
  );

  test('file names name the scope', () {
    expect(const ExportScope.month(2026, 9).fileName, 'masarify-2026-09.xlsx');
    expect(const ExportScope.year(2025).fileName, 'masarify-2025.xlsx');
    expect(const ExportScope.all().fileName, 'masarify-all.xlsx');
  });
}
