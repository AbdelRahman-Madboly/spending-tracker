import 'dart:typed_data';

import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import 'xlsx_writer.dart';

/// What an export covers: one calendar month, one year, or everything.
class ExportScope {
  const ExportScope.month(int this.year, int this.month);
  const ExportScope.year(int this.year) : month = null;
  const ExportScope.all() : year = null, month = null;

  final int? year;
  final int? month;

  bool includes(DateTime date) =>
      (year == null || date.year == year) &&
      (month == null || date.month == month);

  String get fileName {
    final y = year;
    final m = month;
    if (y == null) return 'masarify-all.xlsx';
    if (m == null) return 'masarify-$y.xlsx';
    return 'masarify-$y-${m.toString().padLeft(2, '0')}.xlsx';
  }
}

/// The months and years that hold at least one live entry, newest first:
/// the choices the export dialog offers.
class ExportPeriods {
  const ExportPeriods({required this.months, required this.years});

  final List<({int year, int month})> months;
  final List<int> years;
}

/// The historical `Spending Log` sheet's columns, as the work tracker's
/// `Spending_Tracker_OnlyOffice.xlsx` has them, in the same order.
const spendingLogHeaders = [
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
];

const _columnWidths = [14, 14, 21, 21, 42, 10, 15, 15, 15, 12, 28, 36, 14];

/// Builds the xlsx export from the repository's live (not deleted) entries.
class SpendingExporter {
  const SpendingExporter(this._repository);

  final SpendingRepository _repository;

  Future<ExportPeriods> availablePeriods() async {
    final rows = await _repository.watchTransactions().first;
    final months =
        <({int year, int month})>{
          for (final r in rows) (year: r.date.year, month: r.date.month),
        }.toList()..sort(
          (a, b) => (b.year * 12 + b.month).compareTo(a.year * 12 + a.month),
        );
    final years = {for (final m in months) m.year}.toList()
      ..sort((a, b) => b.compareTo(a));
    return ExportPeriods(months: months, years: years);
  }

  Future<Uint8List> workbook(ExportScope scope) async {
    final all = await _repository.watchTransactions().first;
    // The list comes newest first; a log reads oldest first, and within a
    // day in the order the lines were written.
    final rows = all.where((r) => scope.includes(r.date)).toList()
      ..sort((a, b) {
        final byDay = a.date.compareTo(b.date);
        return byDay != 0 ? byDay : a.createdAt.compareTo(b.createdAt);
      });

    final cells = <List<XlsxCell>>[];
    for (var i = 0; i < rows.length; i++) {
      cells.add(await _row(i + 1, rows[i]));
    }
    return buildXlsx(
      sheetName: 'Spending Log',
      headers: spendingLogHeaders,
      rows: cells,
      columnWidths: _columnWidths,
    );
  }

  Future<List<XlsxCell>> _row(int n, TransactionView t) async {
    final record = await _repository.entry(t.id);
    final receipt = <String>[
      if (record?.reference case final ref? when ref.isNotEmpty) ref,
      if (t.attachmentKinds.isNotEmpty)
        for (final a in await _repository.attachmentsForEntry(t.id))
          if (a.path case final path? when path.isNotEmpty) path,
    ];
    final notes = <String>[
      if (t.note case final note? when note.isNotEmpty) note,
      if (record?.unit case final unit? when unit.isNotEmpty) 'الوحدة: $unit',
    ];
    final quantity = record?.quantityMilli;
    final unitPrice = record?.unitPricePiastres;
    return [
      XlsxText('EXP-${n.toString().padLeft(4, '0')}'),
      XlsxDate(t.date),
      XlsxText(t.categoryKey),
      _textOrEmpty(t.subcategoryKey),
      XlsxText(t.name),
      quantity == null
          ? const XlsxEmpty()
          : XlsxNumber(fixedDecimal(quantity, 3)),
      unitPrice == null
          ? const XlsxEmpty()
          : XlsxNumber(fixedDecimal(unitPrice, 2), money: true),
      XlsxNumber(fixedDecimal(t.amountPiastres, 2), money: true),
      XlsxText(t.paymentMethod),
      // The app keeps no need/want/family type; the column stays for shape.
      const XlsxEmpty(),
      _textOrEmpty(receipt.join('; ')),
      _textOrEmpty(notes.join(' · ')),
      XlsxDate(DateTime(t.date.year, t.date.month)),
    ];
  }
}

XlsxCell _textOrEmpty(String? value) =>
    value == null || value.isEmpty ? const XlsxEmpty() : XlsxText(value);

/// [value] scaled down by 10^[places], as exact decimal text with trailing
/// zeros dropped: `fixedDecimal(3050, 2)` is `'30.5'`, `(-5, 2)` `'-0.05'`.
String fixedDecimal(int value, int places) {
  final negative = value < 0;
  final digits = value.abs().toString().padLeft(places + 1, '0');
  final whole = digits.substring(0, digits.length - places);
  final fraction = digits
      .substring(digits.length - places)
      .replaceAll(RegExp(r'0+$'), '');
  return '${negative ? '-' : ''}$whole${fraction.isEmpty ? '' : '.$fraction'}';
}
