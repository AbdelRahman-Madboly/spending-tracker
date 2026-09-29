import 'package:equatable/equatable.dart';

import '../core/money.dart';
import '../core/quantity.dart';
import 'models.dart';
import 'parsing/parsed_line.dart';
import 'photo_reading.dart';

/// A field of a review line the user can be asked to check (spec §6.7:
/// "`low` fields get a warning outline and an icon").
enum ReviewField { name, quantity, amount, category }

/// Why a review line cannot be saved yet (spec §6.7: "a line with no amount
/// or no category blocks saving until it is fixed or removed").
///
/// A scanned product the app does not know yet also needs a name: saving
/// creates the item that learns its barcode, and an item needs a name.
enum ReviewProblem { missingAmount, missingCategory, missingName }

/// One line of the review sheet as it stands: what the parser read, then
/// whatever the user changed. Immutable; each edit returns a new line.
///
/// Money is integer piastres and quantity integer milli-units, as
/// everywhere else.
class ReviewLine extends Equatable {
  /// Stable for the life of the sheet, so a line keeps its card (and its
  /// swipe) while the lines around it come and go.
  final String id;
  final String name;

  /// The name as it was captured, before any edit: what an alias learns
  /// when the user links the line to an item. Null for a line added in
  /// review, which has no captured words.
  final String? capturedName;
  final String? itemId;

  /// True once the user picked [itemId] in review. Only such a link teaches
  /// an alias: a link the parser made already matched.
  final bool linkedInReview;
  final String? categoryKey;
  final String? subcategoryKey;
  final int quantityMilli;

  /// A key of [entryUnitLabels], or null for a plain count.
  final String? unit;
  final int? amountPiastres;
  final int? unitPricePiastres;

  /// Fields the parser was unsure of and the user has not touched since.
  final Set<ReviewField> uncertain;

  /// The payment reference the capture carried (an InstaPay transaction
  /// read off a screenshot, spec §6.2). Not editable: it is what makes a
  /// second copy of the same transfer refusable.
  final String? reference;

  /// The barcode the line was scanned from (spec §6.3). Not editable, and
  /// kept through every edit: saving teaches it to the line's item, or to
  /// the item it creates.
  final String? barcode;

  /// Set on an InstaPay transfer that names the user as the one paid
  /// ([TransferDirection.received]) or may (uncertain): the review offers
  /// it as a salary. Null on every other line. Kept through every edit.
  final TransferDirection? transfer;

  /// The photo the line was read from, the evidence a salary keeps.
  final String? photoPath;

  const ReviewLine({
    required this.id,
    required this.name,
    this.capturedName,
    this.itemId,
    this.linkedInReview = false,
    this.categoryKey,
    this.subcategoryKey,
    this.quantityMilli = 1000,
    this.unit,
    this.amountPiastres,
    this.unitPricePiastres,
    this.uncertain = const {},
    this.reference,
    this.barcode,
    this.transfer,
    this.photoPath,
  });

  /// The line as the parser read it. Its flags say which fields to check:
  /// no amount or an ambiguous one, no category, and a name corrected by
  /// edit distance, which is a guess even when it is a good one.
  factory ReviewLine.fromParsed(ParsedLine parsed,
      {required String id, String? photoPath}) {
    final flags = parsed.flags;
    return ReviewLine(
      id: id,
      name: parsed.name,
      capturedName: parsed.name,
      itemId: parsed.itemId,
      categoryKey: parsed.categoryKey,
      subcategoryKey: parsed.subcategoryKey,
      quantityMilli: parsed.quantityMilli,
      unit: parsed.unit,
      amountPiastres: parsed.amountPiastres,
      unitPricePiastres: parsed.unitPricePiastres,
      reference: parsed.reference,
      barcode: parsed.barcode,
      transfer: flags.contains(ParseFlag.incoming)
          ? TransferDirection.received
          : flags.contains(ParseFlag.maybeIncoming)
              ? TransferDirection.uncertain
              : null,
      photoPath: photoPath,
      uncertain: {
        if (flags.contains(ParseFlag.fuzzyMatch) ||
            flags.contains(ParseFlag.maybeIncoming) ||
            _unknownProduct(parsed.barcode, parsed.itemId))
          ReviewField.name,
        if (flags.contains(ParseFlag.ambiguousAmount)) ReviewField.quantity,
        if (flags.contains(ParseFlag.noAmount) ||
            flags.contains(ParseFlag.ambiguousAmount))
          ReviewField.amount,
        if (flags.contains(ParseFlag.noCategory)) ReviewField.category,
      },
    );
  }

  /// An empty line ("+ سطر"): nothing filled, so it blocks saving until it
  /// gets an amount and a category or is removed.
  factory ReviewLine.blank(String id) => ReviewLine(id: id, name: '');

  Set<ReviewProblem> get problems => {
        if ((amountPiastres ?? 0) <= 0) ReviewProblem.missingAmount,
        if (categoryKey == null) ReviewProblem.missingCategory,
        if (_unknownProduct(barcode, itemId) && name.trim().isEmpty)
          ReviewProblem.missingName,
      };

  /// A scanned code no item holds yet: its name is typed or looked up, so
  /// it is always worth a look.
  static bool _unknownProduct(String? barcode, String? itemId) =>
      barcode != null && itemId == null;

  bool get isReady => problems.isEmpty;

  /// A salary is only an amount and a day: no category to file it under.
  bool get canBeSalary => (amountPiastres ?? 0) > 0;

  ReviewLine _copy({
    String? name,
    Object? itemId = _keep,
    bool? linkedInReview,
    Object? categoryKey = _keep,
    Object? subcategoryKey = _keep,
    int? quantityMilli,
    Object? unit = _keep,
    Object? amountPiastres = _keep,
    Object? unitPricePiastres = _keep,
    Set<ReviewField>? uncertain,
  }) =>
      ReviewLine(
        id: id,
        name: name ?? this.name,
        capturedName: capturedName,
        itemId: identical(itemId, _keep) ? this.itemId : itemId as String?,
        linkedInReview: linkedInReview ?? this.linkedInReview, // gitleaks:allow
        categoryKey: identical(categoryKey, _keep)
            ? this.categoryKey
            : categoryKey as String?,
        subcategoryKey: identical(subcategoryKey, _keep)
            ? this.subcategoryKey
            : subcategoryKey as String?,
        quantityMilli: quantityMilli ?? this.quantityMilli,
        unit: identical(unit, _keep) ? this.unit : unit as String?,
        amountPiastres: identical(amountPiastres, _keep)
            ? this.amountPiastres
            : amountPiastres as int?,
        unitPricePiastres: identical(unitPricePiastres, _keep)
            ? this.unitPricePiastres
            : unitPricePiastres as int?,
        uncertain: uncertain ?? this.uncertain,
        reference: reference,
        barcode: barcode,
        transfer: transfer,
        photoPath: photoPath,
      );

  Set<ReviewField> _settled(ReviewField field) =>
      {...uncertain}..remove(field);

  ReviewLine withName(String name) =>
      _copy(name: name, uncertain: _settled(ReviewField.name));

  /// A typed amount is the line total: a unit price no longer holds.
  ReviewLine withAmount(int? amountPiastres) => _copy(
        amountPiastres: amountPiastres,
        unitPricePiastres: null,
        uncertain: _settled(ReviewField.amount),
      );

  /// With a unit price the amount follows the quantity (1.5 كيلو at 20 is
  /// 30); without one the amount stays as the total the user saw.
  ReviewLine withQuantity(int quantityMilli) {
    final unitPrice = unitPricePiastres;
    return _copy(
      quantityMilli: quantityMilli,
      amountPiastres: unitPrice == null
          ? _keep
          : (unitPrice * quantityMilli + 500) ~/ 1000,
      uncertain: _settled(ReviewField.quantity),
    );
  }

  ReviewLine withUnit(String? unit) => _copy(unit: unit);

  /// A different category clears the subcategory and the item, which both
  /// belong to the old one.
  ReviewLine withCategory(String? categoryKey) {
    if (categoryKey == this.categoryKey) return this;
    return _copy(
      categoryKey: categoryKey,
      subcategoryKey: null,
      itemId: null,
      linkedInReview: false,
      uncertain: _settled(ReviewField.category),
    );
  }

  /// A different subcategory unlinks the item: linking an item already set
  /// the item's own subcategory, so any other one is not where it is filed.
  ReviewLine withSubcategory(String? subcategoryKey) {
    if (subcategoryKey == this.subcategoryKey) return this;
    return _copy(
      subcategoryKey: subcategoryKey,
      itemId: null,
      linkedInReview: false,
    );
  }

  /// The line carrying [reference]: a transfer's reference read again off
  /// the photo of a draft whose lines came back from its text.
  ReviewLine withReference(String reference) => ReviewLine(
        id: id,
        name: name,
        capturedName: capturedName,
        itemId: itemId,
        linkedInReview: linkedInReview,
        categoryKey: categoryKey,
        subcategoryKey: subcategoryKey,
        quantityMilli: quantityMilli,
        unit: unit,
        amountPiastres: amountPiastres,
        unitPricePiastres: unitPricePiastres,
        uncertain: uncertain,
        reference: reference,
        barcode: barcode,
        transfer: transfer,
        photoPath: photoPath,
      );

  /// Links [item]: the line takes its name, category and subcategory, and
  /// the doubts about name and category are settled.
  ReviewLine withItem(QuickPickItem item) {
    return _copy(
      name: item.nameAr,
      itemId: item.id,
      linkedInReview: true,
      categoryKey: item.categoryKey,
      subcategoryKey: item.subcategoryKey,
      uncertain: {...uncertain}
        ..remove(ReviewField.name)
        ..remove(ReviewField.category),
    );
  }

  /// The entry this line saves as, or null while it has a problem.
  CaptureLine? toCaptureLineOrNull() {
    final amount = amountPiastres;
    final category = categoryKey;
    if (!isReady || amount == null || category == null) return null;
    final captured = capturedName?.trim() ?? '';
    return CaptureLine(
      amountPiastres: amount,
      categoryKey: category,
      subcategoryKey: subcategoryKey,
      itemId: itemId,
      description: name.trim(),
      // One plain unit is what "no quantity" already means.
      quantityMilli: quantityMilli == 1000 && unit == null ? null : quantityMilli,
      unit: unit,
      unitPricePiastres: unitPricePiastres,
      reference: reference,
      barcode: barcode,
      aliasToLearn:
          linkedInReview && itemId != null && captured.isNotEmpty ? captured : null,
    );
  }

  CaptureLine toCaptureLine() =>
      toCaptureLineOrNull() ?? (throw StateError('line $id is not ready'));

  @override
  List<Object?> get props => [
        id,
        name,
        capturedName,
        itemId,
        linkedInReview,
        categoryKey,
        subcategoryKey,
        quantityMilli,
        unit,
        amountPiastres,
        unitPricePiastres,
        uncertain,
        reference,
        barcode,
        transfer,
        photoPath,
      ];
}

const Object _keep = Object();

/// What the lines add up to so far; lines without an amount count nothing.
int reviewTotal(Iterable<ReviewLine> lines) =>
    lines.fold(0, (sum, l) => sum + (l.amountPiastres ?? 0));

/// Whether حفظ can run: at least one line, and none with a problem.
bool canSaveReview(List<ReviewLine> lines) =>
    lines.isNotEmpty && lines.every((l) => l.isReady);

/// The lines written as a note the parser reads back to the same lines,
/// one per row ("طماطم 2 كيلو ب 30"). A capture kept for later stores only
/// its raw text (a draft carries no lines, see [CaptureDraft.isDraft]), so
/// a capture that arrived as lines with no text of its own (a barcode
/// scan) keeps them this way instead of losing them.
String reviewDraftText(Iterable<ReviewLine> lines) => [
      for (final l in lines)
        [
          l.name.trim(),
          if (l.quantityMilli != 1000 || l.unit != null)
            formatQuantityMilli(l.quantityMilli),
          if (l.unit != null) entryUnitLabels[l.unit] ?? '',
          if (l.amountPiastres != null)
            'ب ${formatPiastres(l.amountPiastres!).replaceAll(',', '')}',
        ].where((part) => part.isNotEmpty).join(' '),
    ].where((row) => row.isNotEmpty).join('\n');

/// Gives [lines] the references [read] off the capture's photos again.
///
/// A draft keeps text, not lines, so a photo draft edited before it was
/// kept comes back from its text without the transfer's reference (spec
/// §6.2), and with it the refusal of a second copy of the same transfer.
/// Each reference goes to the first line without one that has the amount
/// the photo showed; when the amount was edited too, a single reference
/// left over goes to a single line left over. A reference no line takes is
/// dropped rather than guessed onto an unrelated line.
List<ReviewLine> withReadReferences(
    List<ReviewLine> lines, Iterable<ParsedLine> read) {
  final result = [...lines];
  final pending = <String>[];
  for (final r in read) {
    final reference = r.reference;
    if (reference == null || result.any((l) => l.reference == reference)) {
      continue;
    }
    final i = result.indexWhere((l) =>
        l.reference == null &&
        r.amountPiastres != null &&
        l.amountPiastres == r.amountPiastres);
    if (i < 0) {
      pending.add(reference);
    } else {
      result[i] = result[i].withReference(reference);
    }
  }
  final free = [
    for (final (i, l) in result.indexed)
      if (l.reference == null) i,
  ];
  if (pending.length == 1 && free.length == 1) {
    result[free.single] = result[free.single].withReference(pending.single);
  }
  return result;
}
