import 'package:equatable/equatable.dart';

import '../core/money.dart';
import '../core/quantity.dart';
import 'models.dart';
import 'parsing/parsed_line.dart';

/// A field of a review line the user can be asked to check (spec §6.7:
/// "`low` fields get a warning outline and an icon").
enum ReviewField { name, quantity, amount, category }

/// Why a review line cannot be saved yet (spec §6.7: "a line with no amount
/// or no category blocks saving until it is fixed or removed").
enum ReviewProblem { missingAmount, missingCategory }

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
  });

  /// The line as the parser read it. Its flags say which fields to check:
  /// no amount or an ambiguous one, no category, and a name corrected by
  /// edit distance, which is a guess even when it is a good one.
  factory ReviewLine.fromParsed(ParsedLine parsed, {required String id}) {
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
      uncertain: {
        if (flags.contains(ParseFlag.fuzzyMatch)) ReviewField.name,
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
      };

  bool get isReady => problems.isEmpty;

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
