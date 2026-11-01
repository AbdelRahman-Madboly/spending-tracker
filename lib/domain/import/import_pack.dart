import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../models.dart';

/// One spend an import would write as one `entries` row (spec §5, plan
/// Task 13). Pure data: whether it is new, a duplicate or needs a look is
/// decided later, against the database, by `reviewImport`.
class ImportRow extends Equatable {
  /// The import identity written to `entries.externalId`. Importing the
  /// same row twice finds it here and adds nothing.
  final String externalId;

  /// The row's name in its source (`sn-001`, a work-tracker id, a line
  /// number), for display.
  final String ref;
  final DateTime date;

  /// Null only for a line read from a note that gave no price.
  final int? amountPiastres;

  /// Null only for a line read from a note that matched no category.
  final String? categoryKey;
  final String? subcategoryKey;
  final String? itemId;
  final String description;
  final String paymentMethod;

  /// Milli-units; null means one.
  final int? quantityMilli;

  /// A key of [entryUnitLabels].
  final String? unit;
  final int? unitPricePiastres;
  final String? reference;
  final String? note;
  final String? barcode;

  /// The text the row was read from, as written.
  final String? rawText;

  /// Why the row deserves a look, as the source wrote it: a pack's flag
  /// strings (`date_after_midnight: ...`), or the parser's for a note.
  final List<String> flags;

  /// An evidence file, relative to the pack's folder
  /// (`evidence/...jpeg`), copied into app storage as an attachment.
  final String? evidence;

  /// Rows with the same key are saved as one capture group: the lines of
  /// one note on one day, or one order (a pack's `captureGroup`).
  final String groupKey;

  const ImportRow({
    required this.externalId,
    required this.ref,
    required this.date,
    required this.description,
    required this.groupKey,
    this.amountPiastres,
    this.categoryKey,
    this.subcategoryKey,
    this.itemId,
    this.paymentMethod = 'Cash',
    this.quantityMilli,
    this.unit,
    this.unitPricePiastres,
    this.reference,
    this.note,
    this.barcode,
    this.rawText,
    this.flags = const [],
    this.evidence,
  });

  @override
  List<Object?> get props => [
    externalId,
    ref,
    date,
    amountPiastres,
    categoryKey,
    subcategoryKey,
    itemId,
    description,
    paymentMethod,
    quantityMilli,
    unit,
    unitPricePiastres,
    reference,
    note,
    barcode,
    rawText,
    flags,
    evidence,
    groupKey,
  ];
}

/// One salary payment an import would write as a `salary_periods` row.
class ImportSalary extends Equatable {
  final String externalId;
  final String ref;
  final DateTime datePaid;
  final int amountPiastres;
  final String? note;

  /// As [ImportRow.evidence]; kept as the period's evidence photo.
  final String? evidence;

  const ImportSalary({
    required this.externalId,
    required this.ref,
    required this.datePaid,
    required this.amountPiastres,
    this.note,
    this.evidence,
  });

  @override
  List<Object?> get props => [
    externalId,
    ref,
    datePaid,
    amountPiastres,
    note,
    evidence,
  ];
}

class CategoryAddition extends Equatable {
  final String key;
  final String labelAr;
  final String iconName;
  final String colorKey;

  const CategoryAddition({
    required this.key,
    required this.labelAr,
    required this.iconName,
    this.colorKey = 'Other',
  });

  @override
  List<Object?> get props => [key, labelAr, iconName, colorKey];
}

class SubcategoryAddition extends Equatable {
  final String key;
  final String categoryKey;
  final String labelAr;
  final String iconName;

  const SubcategoryAddition({
    required this.key,
    required this.categoryKey,
    required this.labelAr,
    required this.iconName,
  });

  @override
  List<Object?> get props => [key, categoryKey, labelAr, iconName];
}

/// Categories and subcategories a pack's rows use that the shipped
/// catalogue lacks. They are created, by key, before any row is written.
class CatalogueAdditions extends Equatable {
  final List<CategoryAddition> categories;
  final List<SubcategoryAddition> subcategories;

  const CatalogueAdditions({
    this.categories = const [],
    this.subcategories = const [],
  });

  static const none = CatalogueAdditions();

  @override
  List<Object?> get props => [categories, subcategories];
}

/// Reads an evidence file named relative to its pack's folder
/// (`evidence/...jpeg`); null when the pack came without it.
typedef EvidenceReader = Future<List<int>?> Function(String path);

/// Everything one import source holds, read but not yet checked.
class ImportPack extends Equatable {
  /// The file the pack came from (`samsung_notes_2026-09.json`,
  /// `Notes_260913_224548.sdocx`), part of every pack row's identity.
  final String fileName;
  final List<ImportRow> rows;
  final List<ImportSalary> salaries;
  final CatalogueAdditions additions;

  /// Rows the source itself says not to import: a pack row marked `skip`,
  /// or a work-tracker row already seeded or carried by another pack.
  final int skipped;

  /// The group's raw text by [ImportRow.groupKey], kept on the capture
  /// group as captured (the note's lines).
  final Map<String, String> rawTextByGroup;

  /// True when the rows were read by the local parser from a note, not
  /// from a prepared pack.
  final bool fromNote;

  /// Where this pack's own evidence is read from (a zip pack's files);
  /// null for a pack whose evidence the importer finds (the bundled
  /// assets).
  final EvidenceReader? readEvidence;

  const ImportPack({
    required this.fileName,
    required this.rows,
    this.salaries = const [],
    this.additions = CatalogueAdditions.none,
    this.skipped = 0,
    this.rawTextByGroup = const {},
    this.fromNote = false,
    this.readEvidence,
  });

  /// This pack, with its evidence read by [reader].
  ImportPack withEvidence(EvidenceReader reader) => ImportPack(
    fileName: fileName,
    rows: rows,
    salaries: salaries,
    additions: additions,
    skipped: skipped,
    rawTextByGroup: rawTextByGroup,
    fromNote: fromNote,
    readEvidence: reader,
  );

  @override
  List<Object?> get props => [
    fileName,
    rows,
    salaries,
    additions,
    skipped,
    rawTextByGroup,
    fromNote,
  ];
}

/// Reads a JSON import pack by its `format`: Samsung notes
/// (`samsung-notes-import/1`), the manual pack (`manual-import/1`) or the
/// work-tracker sync (`work-tracker-sync/1`). Throws [FormatException] for
/// anything else.
///
/// Pack rows are identified as `pack:<file>:<ref>`; work-tracker rows keep
/// the `externalId` the sync tool gave them. Work-tracker rows with a
/// `seedEntryId` are in the database from the first launch already, and
/// rows with a `packRef` arrive through that pack, so both are skipped;
/// a salary is imported only when it has neither a `seedSalaryId` nor a
/// `packRef`.
ImportPack parseImportPack(String fileName, String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const FormatException('not a JSON import pack');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('not a JSON import pack');
  }
  final format = decoded['format'];
  return switch (format) {
    'samsung-notes-import/1' ||
    'manual-import/1' => _parsePreparedPack(fileName, decoded),
    'work-tracker-sync/1' => _parseWorkTracker(fileName, decoded),
    _ => throw FormatException('unknown import format: $format'),
  };
}

List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) =>
    ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();

DateTime _date(String ymd) {
  final parts = ymd.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final _unitKeyByLabel = {
  for (final e in entryUnitLabels.entries) e.value: e.key,
};

/// A pack's `quantity` and Arabic `unit` as milli-units and a unit key. A
/// plain count of one stores nothing, like a manual add.
(int?, String?) _quantity(Object? quantity, Object? unitLabel) {
  final unit = unitLabel is String
      ? (_unitKeyByLabel[unitLabel] ??
            (entryUnitLabels.containsKey(unitLabel) ? unitLabel : null))
      : null;
  final q = quantity is num ? quantity : 1;
  if (q == 1 && unit == null) return (null, null);
  return ((q * 1000).round(), unit);
}

CatalogueAdditions _additions(Map<String, dynamic> json) {
  final raw = json['catalogueAdditions'];
  if (raw is! Map<String, dynamic>) return CatalogueAdditions.none;
  return CatalogueAdditions(
    categories: [
      for (final c in _list(raw, 'categories'))
        CategoryAddition(
          key: c['key'] as String,
          labelAr: c['labelAr'] as String,
          iconName: (c['iconName'] as String?) ?? 'category',
          colorKey: (c['colorKey'] as String?) ?? 'Other',
        ),
    ],
    subcategories: [
      for (final s in _list(raw, 'subcategories'))
        SubcategoryAddition(
          key: s['key'] as String,
          categoryKey: s['categoryKey'] as String,
          labelAr: s['labelAr'] as String,
          iconName: (s['iconName'] as String?) ?? 'category',
        ),
    ],
  );
}

List<String> _flags(Map<String, dynamic> row) =>
    ((row['flags'] as List?) ?? const []).cast<String>();

ImportPack _parsePreparedPack(String fileName, Map<String, dynamic> json) {
  final rows = <ImportRow>[];
  final rawText = <String, List<String>>{};
  var skipped = 0;
  for (final r in _list(json, 'entries')) {
    if (r['skip'] == true) {
      skipped++;
      continue;
    }
    final ref = r['ref'] as String;
    final date = _date(r['date'] as String);
    final payment = (r['paymentMethod'] as String?) ?? 'Cash';
    // One Samsung note is one capture; so is one order in the manual pack.
    // The date and payment method are part of the key because a capture
    // group has one of each.
    final sourceNote = r['sourceNote'] as String?;
    final order = r['captureGroup'] as String?;
    final base = sourceNote != null
        ? 'note:$sourceNote'
        : order != null
        ? 'group:$order'
        : 'row:$ref';
    final groupKey = '$base|${_ymd(date)}|$payment';
    final (quantityMilli, unit) = _quantity(r['quantity'], r['unit']);
    final text = r['rawText'] as String?;
    if (sourceNote != null && text != null) {
      (rawText[groupKey] ??= []).add(text);
    }
    rows.add(
      ImportRow(
        externalId: 'pack:$fileName:$ref',
        ref: ref,
        date: date,
        amountPiastres: r['amountPiastres'] as int,
        categoryKey: r['categoryKey'] as String,
        subcategoryKey: r['subcategoryKey'] as String?,
        itemId: r['itemId'] as String?,
        description: (r['description'] as String?) ?? '',
        paymentMethod: payment,
        quantityMilli: quantityMilli,
        unit: unit,
        unitPricePiastres: r['unitPricePiastres'] as int?,
        reference: r['reference'] as String?,
        note: r['note'] as String?,
        barcode: r['barcode'] as String?,
        rawText: text,
        flags: _flags(r),
        evidence: r['evidencePhotoPath'] as String?,
        groupKey: groupKey,
      ),
    );
  }
  final salaries = [
    for (final s in _list(json, 'salaryPeriods'))
      ImportSalary(
        externalId: 'pack:$fileName:${s['ref']}',
        ref: s['ref'] as String,
        datePaid: _date(s['datePaid'] as String),
        amountPiastres: s['amountPiastres'] as int,
        note: s['note'] as String?,
        evidence: s['evidencePhotoPath'] as String?,
      ),
  ];
  return ImportPack(
    fileName: fileName,
    rows: rows,
    salaries: salaries,
    additions: _additions(json),
    skipped: skipped,
    rawTextByGroup: {
      for (final e in rawText.entries) e.key: e.value.join('\n'),
    },
  );
}

ImportPack _parseWorkTracker(String fileName, Map<String, dynamic> json) {
  final rows = <ImportRow>[];
  var skipped = 0;
  for (final r in _list(json, 'entries')) {
    if (r['seedEntryId'] != null || r['packRef'] != null) {
      skipped++;
      continue;
    }
    final externalId = r['externalId'] as String;
    rows.add(
      ImportRow(
        externalId: externalId,
        ref: externalId,
        date: _date(r['date'] as String),
        amountPiastres: r['amountPiastres'] as int,
        categoryKey: r['categoryKey'] as String,
        subcategoryKey: r['subcategoryKey'] as String?,
        itemId: r['itemId'] as String?,
        description: (r['description'] as String?) ?? '',
        paymentMethod: (r['paymentMethod'] as String?) ?? 'Cash',
        // The tracker's evidence paths point into its own receipts folder,
        // which the app does not have, so none is carried over.
        groupKey: 'row:$externalId',
      ),
    );
  }
  final salaries = <ImportSalary>[];
  for (final s in _list(json, 'salaryPeriods')) {
    if (s['seedSalaryId'] != null || s['packRef'] != null) {
      skipped++;
      continue;
    }
    final externalId = s['externalId'] as String;
    salaries.add(
      ImportSalary(
        externalId: externalId,
        ref: externalId,
        datePaid: _date(s['datePaid'] as String),
        amountPiastres: s['amountPiastres'] as int,
        note: s['note'] as String?,
      ),
    );
  }
  return ImportPack(
    fileName: fileName,
    rows: rows,
    salaries: salaries,
    skipped: skipped,
  );
}
