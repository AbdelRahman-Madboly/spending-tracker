import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

import '../../core/arabic_text.dart';
import '../models.dart';
import 'import_pack.dart';

/// Where a row stands against what the database already holds (plan
/// Task 13): nothing is written until the user has seen this and confirmed.
enum ImportRowState {
  /// Not in the database; imported unless the user unticks it.
  fresh,

  /// New, but its source flagged something to check (a guessed category,
  /// a date after midnight). Imported unless unticked; the flags show.
  flagged,

  /// Already in the database, or looks like an entry that is.
  duplicate,

  /// Cannot be written as it is: no amount, or no category the catalogue
  /// knows.
  incomplete,
}

/// One row or salary of a pack with its verdict. Exactly one of [row] and
/// [salary] is set. [row] is the row as it would be written: an item or
/// subcategory the catalogue lacks is already dropped from it.
class ImportReviewItem extends Equatable {
  final ImportRow? row;
  final ImportSalary? salary;
  final ImportRowState state;

  /// Why the row is a duplicate or incomplete, in Arabic, for the list.
  final List<String> problems;

  /// False for a row that would fail or double an existing one: already
  /// imported, a payment reference already recorded, or incomplete. A
  /// row that only looks like an existing entry can still be ticked.
  final bool selectable;

  const ImportReviewItem({
    this.row,
    this.salary,
    required this.state,
    this.problems = const [],
    required this.selectable,
  });

  bool get selectedByDefault =>
      selectable &&
      (state == ImportRowState.fresh || state == ImportRowState.flagged);

  @override
  List<Object?> get props => [row, salary, state, problems, selectable];
}

class ImportReview extends Equatable {
  final ImportPack pack;
  final List<ImportReviewItem> items;

  const ImportReview({required this.pack, required this.items});

  int count(ImportRowState state) =>
      items.where((i) => i.state == state).length;

  @override
  List<Object?> get props => [pack, items];
}

/// What the database holds, as far as the duplicate check needs it.
class ImportContext {
  /// Every `externalId` on entries and salary periods.
  final Set<String> knownExternalIds;

  /// The payment references of the pack's rows that a live entry holds.
  final Set<String> knownReferences;

  /// Every live entry.
  final List<TransactionView> entries;

  /// Every salary payment, as (day paid, amount).
  final List<(DateTime, int)> salaries;

  /// Category keys in the catalogue, archived ones included.
  final Set<String> categoryKeys;

  /// Subcategory key to its category key, archived ones included.
  final Map<String, String> subcategoryCategories;

  /// Item ids in the catalogue, archived ones included.
  final Set<String> itemIds;

  const ImportContext({
    required this.knownExternalIds,
    required this.knownReferences,
    required this.entries,
    required this.salaries,
    required this.categoryKeys,
    required this.subcategoryCategories,
    required this.itemIds,
  });
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Checks every row and salary of [pack] against [context]. A row is a
/// duplicate when its import identity or its payment reference is already
/// recorded, or when a live entry has the same day, amount and name (the
/// name as the row in السجل shows it, compared after `normalizeArabic`).
/// The pack's catalogue additions count as known, since they are created
/// before any row is written.
ImportReview reviewImport(ImportPack pack, ImportContext context) {
  final categories = {
    ...context.categoryKeys,
    for (final c in pack.additions.categories) c.key,
  };
  final subcategories = {
    ...context.subcategoryCategories,
    for (final s in pack.additions.subcategories) s.key: s.categoryKey,
  };
  final existing = <String>{
    for (final e in context.entries)
      '${_day(e.date)}|${e.amountPiastres}|${normalizeArabic(e.name)}',
  };
  final items = <ImportReviewItem>[];
  for (final raw in pack.rows) {
    final category = raw.categoryKey;
    final subcategory = raw.subcategoryKey;
    final item = raw.itemId;
    final row = _withCatalogue(
      raw,
      subcategoryKey:
          subcategory != null &&
              category != null &&
              subcategories[subcategory] == category
          ? subcategory
          : null,
      itemId: item != null && context.itemIds.contains(item) ? item : null,
    );
    final reference = row.reference;
    if (context.knownExternalIds.contains(row.externalId)) {
      items.add(
        ImportReviewItem(
          row: row,
          state: ImportRowState.duplicate,
          problems: const ['اتستورد قبل كده'],
          selectable: false,
        ),
      );
    } else if (reference != null &&
        context.knownReferences.contains(reference)) {
      items.add(
        ImportReviewItem(
          row: row,
          state: ImportRowState.duplicate,
          problems: ['رقم العملية $reference متسجل قبل كده'],
          selectable: false,
        ),
      );
    } else if (row.amountPiastres == null) {
      items.add(
        ImportReviewItem(
          row: row,
          state: ImportRowState.incomplete,
          problems: const ['مفيش مبلغ'],
          selectable: false,
        ),
      );
    } else if (category == null || !categories.contains(category)) {
      items.add(
        ImportReviewItem(
          row: row,
          state: ImportRowState.incomplete,
          problems: [
            category == null ? 'مفيش قسم' : 'القسم $category مش موجود',
          ],
          selectable: false,
        ),
      );
    } else if (existing.contains(
      '${_day(row.date)}|${row.amountPiastres}|'
      '${normalizeArabic(row.description)}',
    )) {
      items.add(
        ImportReviewItem(
          row: row,
          state: ImportRowState.duplicate,
          problems: const ['فيه مصروف بنفس اليوم والمبلغ والاسم'],
          selectable: true,
        ),
      );
    } else {
      items.add(
        ImportReviewItem(
          row: row,
          state: row.flags.isEmpty
              ? ImportRowState.fresh
              : ImportRowState.flagged,
          selectable: true,
        ),
      );
    }
  }
  final paid = {
    for (final (day, amount) in context.salaries) '${_day(day)}|$amount',
  };
  for (final salary in pack.salaries) {
    if (context.knownExternalIds.contains(salary.externalId)) {
      items.add(
        ImportReviewItem(
          salary: salary,
          state: ImportRowState.duplicate,
          problems: const ['اتستورد قبل كده'],
          selectable: false,
        ),
      );
    } else if (paid.contains(
      '${_day(salary.datePaid)}|${salary.amountPiastres}',
    )) {
      items.add(
        ImportReviewItem(
          salary: salary,
          state: ImportRowState.duplicate,
          problems: const ['فيه راتب بنفس اليوم والمبلغ'],
          selectable: true,
        ),
      );
    } else {
      items.add(
        ImportReviewItem(
          salary: salary,
          state: ImportRowState.fresh,
          selectable: true,
        ),
      );
    }
  }
  return ImportReview(pack: pack, items: items);
}

ImportRow _withCatalogue(
  ImportRow r, {
  required String? subcategoryKey,
  required String? itemId,
}) => ImportRow(
  externalId: r.externalId,
  ref: r.ref,
  date: r.date,
  description: r.description,
  groupKey: r.groupKey,
  amountPiastres: r.amountPiastres,
  categoryKey: r.categoryKey,
  subcategoryKey: subcategoryKey,
  itemId: itemId,
  paymentMethod: r.paymentMethod,
  quantityMilli: r.quantityMilli,
  unit: r.unit,
  unitPricePiastres: r.unitPricePiastres,
  reference: r.reference,
  note: r.note,
  barcode: r.barcode,
  rawText: r.rawText,
  flags: r.flags,
  evidence: r.evidence,
);

const _photoExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};

/// The captures [rows] of [pack] are saved as: one `import` capture per
/// [ImportRow.groupKey], in the order the groups first appear, each with
/// its rows as lines and its note's raw text. Every row must be complete
/// (an amount and a category).
///
/// [evidencePaths] maps a row's evidence to where it was copied in app
/// storage; each copied file attaches once to its group, a photo as a
/// `photo` and anything else (the packing slip PDF) as a `file`. Evidence
/// with no copy is left out.
///
/// A payment reference shared by the lines of one order (the order
/// number on each item of a packing slip) is kept on the first line only:
/// the reference records the payment, which was made once, and
/// `saveCapture` refuses one reference on two lines.
List<CaptureDraft> importDrafts(
  ImportPack pack,
  Iterable<ImportRow> rows, {
  Map<String, String> evidencePaths = const {},
}) {
  final groups = <String, List<ImportRow>>{};
  for (final row in rows) {
    (groups[row.groupKey] ??= []).add(row);
  }
  return [
    for (final MapEntry(key: key, value: members) in groups.entries)
      _draft(pack, key, members, evidencePaths),
  ];
}

CaptureDraft _draft(
  ImportPack pack,
  String groupKey,
  List<ImportRow> rows,
  Map<String, String> evidencePaths,
) {
  final references = <String>{};
  final attached = <String>{};
  final attachments = <DraftAttachment>[];
  for (final row in rows) {
    final path = evidencePaths[row.evidence];
    if (path == null || !attached.add(path)) continue;
    final isPhoto = _photoExtensions.contains(p.extension(path).toLowerCase());
    attachments.add(
      DraftAttachment(
        kind: isPhoto ? AttachmentKind.photo : AttachmentKind.file,
        path: path,
      ),
    );
  }
  return CaptureDraft(
    kind: CaptureKind.import,
    date: _day(rows.first.date),
    paymentMethod: rows.first.paymentMethod,
    rawText: pack.rawTextByGroup[groupKey],
    parsedBy: pack.fromNote ? 'local' : null,
    attachments: attachments,
    lines: [
      for (final row in rows)
        CaptureLine(
          amountPiastres: row.amountPiastres!,
          categoryKey: row.categoryKey!,
          subcategoryKey: row.subcategoryKey,
          itemId: row.itemId,
          description: row.description,
          quantityMilli: row.quantityMilli,
          unit: row.unit,
          unitPricePiastres: row.unitPricePiastres,
          externalId: row.externalId,
          reference: row.reference != null && references.add(row.reference!)
              ? row.reference
              : null,
          note: row.note,
          barcode: row.barcode,
        ),
    ],
  );
}
