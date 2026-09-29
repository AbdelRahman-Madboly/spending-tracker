import 'package:equatable/equatable.dart';

/// How an entry was captured. Stored by [Enum.name] in `entries.source`;
/// `text`, `photo` and `import` are new in v3.
enum EntrySource {
  quickPick,
  barcode,
  ocr,
  imageLabel,
  voice,
  manual,
  text,
  photo,
  import;

  /// The stored value back to an enum; an unknown value (a row written by
  /// a newer build) reads as [manual] rather than failing.
  static EntrySource fromName(String name) =>
      values.firstWhere((s) => s.name == name, orElse: () => manual);
}

/// Unit keys an entry's quantity can be measured in, with their Arabic
/// labels. Keys are what `entries.unit` stores.
const entryUnitLabels = {
  'piece': 'قطعة',
  'kg': 'كيلو',
  'g': 'جرام',
  'liter': 'لتر',
  'bag': 'كيس',
  'box': 'علبة',
  'bottle': 'زجاجة',
  'can': 'كانز',
  'pack': 'باكو',
  'strip': 'شريط',
  'person': 'فرد',
};

/// The kind of capture event a `capture_groups` row records.
enum CaptureKind {
  voice,
  text,
  photo,
  barcode,
  import,
  manual;

  static CaptureKind fromName(String name) =>
      values.firstWhere((k) => k.name == name, orElse: () => manual);

  /// The `entries.source` written for lines saved from this capture.
  EntrySource get entrySource => switch (this) {
        CaptureKind.voice => EntrySource.voice,
        CaptureKind.text => EntrySource.text,
        CaptureKind.photo => EntrySource.photo,
        CaptureKind.barcode => EntrySource.barcode,
        CaptureKind.import => EntrySource.import,
        CaptureKind.manual => EntrySource.manual,
      };
}

/// `draft`: not reviewed yet. `saved`: entries were written. `note`: kept
/// as a standalone note with no entries.
enum CaptureStatus {
  draft,
  saved,
  note;

  static CaptureStatus fromName(String name) =>
      values.firstWhere((s) => s.name == name, orElse: () => draft);
}

enum AttachmentKind {
  photo,
  voice,
  text,
  file;

  static AttachmentKind fromName(String name) =>
      values.firstWhere((k) => k.name == name, orElse: () => file);
}

/// One salary period: the salary it started with, what was spent in it, and
/// where today sits inside it.
class PeriodSummary extends Equatable {
  final int salaryPiastres;
  final int spentPiastres;
  final int daysRemaining;

  /// The period's expected length in days: the gap to the next salary for a
  /// past period, the usual gap between salaries for the current one.
  final int lengthDays;

  /// The day the salary was paid. Null when no salary is recorded yet.
  final DateTime? start;

  /// The period's last day, inclusive. For the current period this is a
  /// projection (start + [lengthDays] − 1), since the next salary has not
  /// come yet.
  final DateTime? end;

  /// False for every period before the latest salary. A past period is
  /// read-only on the dashboard and shows its final result.
  final bool isCurrent;

  const PeriodSummary({
    required this.salaryPiastres,
    required this.spentPiastres,
    required this.daysRemaining,
    this.lengthDays = 30,
    this.start,
    this.end,
    this.isCurrent = true,
  });

  int get leftPiastres => salaryPiastres - spentPiastres;

  /// Null when nothing is left, and for a past period. A negative daily
  /// allowance is noise; the red `left` figure already carries the message.
  int? get safeDailyPiastres {
    if (!isCurrent || leftPiastres <= 0 || daysRemaining <= 0) return null;
    return leftPiastres ~/ daysRemaining;
  }

  int get daysElapsed => lengthDays - daysRemaining;

  /// Where "today" sits in the period, 0..1: the budget bar's today tick.
  /// A late salary (days remaining below zero) pins it at the end.
  double get elapsedFraction =>
      lengthDays <= 0 ? 1 : (daysElapsed / lengthDays).clamp(0.0, 1.0);

  /// Whole percent of the salary spent, rounded down, or null when there
  /// is no salary to measure against. Can pass 100 when overspent.
  int? get spentPercent =>
      salaryPiastres <= 0 ? null : spentPiastres * 100 ~/ salaryPiastres;

  @override
  List<Object?> get props => [
        salaryPiastres,
        spentPiastres,
        daysRemaining,
        lengthDays,
        start,
        end,
        isCurrent,
      ];
}

class EntryView extends Equatable {
  final String id;
  final String displayName;
  final int amountPiastres;
  final String categoryKey;
  final String categoryLabelAr;
  final DateTime date;

  const EntryView({
    required this.id,
    required this.displayName,
    required this.amountPiastres,
    required this.categoryKey,
    required this.categoryLabelAr,
    required this.date,
  });

  @override
  List<Object?> get props =>
      [id, displayName, amountPiastres, categoryKey, date];
}

/// One live entry as السجل lists it (spec §4.3): the fields a row shows
/// and every field search reads, including the text of its attachments.
class TransactionView extends Equatable {
  final String id;
  final DateTime date;

  /// When the row was written: the row's time, and the order of lines
  /// inside a capture group.
  final DateTime createdAt;
  final int amountPiastres;
  final String categoryKey;
  final String categoryLabelAr;
  final String? subcategoryKey;
  final String? subcategoryLabelAr;
  final String description;

  /// The linked catalogue item's name, when the entry has one.
  final String? itemNameAr;
  final String? note;
  final String paymentMethod;
  final EntrySource source;
  final String? captureGroupId;

  /// The kinds of the entry's own attachments and its capture group's.
  final Set<AttachmentKind> attachmentKinds;

  /// Text-note bodies and voice transcripts of those attachments, for
  /// search.
  final List<String> attachmentText;

  const TransactionView({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.amountPiastres,
    required this.categoryKey,
    required this.categoryLabelAr,
    required this.description,
    required this.paymentMethod,
    required this.source,
    this.subcategoryKey,
    this.subcategoryLabelAr,
    this.itemNameAr,
    this.note,
    this.captureGroupId,
    this.attachmentKinds = const {},
    this.attachmentText = const [],
  });

  /// What the row is called: the description, else the item's name, else
  /// the category, so no row is ever blank.
  String get name {
    if (description.isNotEmpty) return description;
    final item = itemNameAr;
    if (item != null && item.isNotEmpty) return item;
    return categoryLabelAr;
  }

  @override
  List<Object?> get props => [
        id,
        date,
        createdAt,
        amountPiastres,
        categoryKey,
        categoryLabelAr,
        subcategoryKey,
        subcategoryLabelAr,
        description,
        itemNameAr,
        note,
        paymentMethod,
        source,
        captureGroupId,
        attachmentKinds,
        attachmentText,
      ];
}

class CategoryView extends Equatable {
  final String key;
  final String labelAr;
  final String iconName;

  /// One of `categoryColorKeys` (spec §7.2). A category the user creates
  /// gets `Other` unless one is chosen.
  final String colorKey;

  const CategoryView({
    required this.key,
    required this.labelAr,
    required this.iconName,
    this.colorKey = 'Other',
  });

  @override
  List<Object?> get props => [key, labelAr, iconName, colorKey];
}

class SubcategoryView extends Equatable {
  final String key;
  final String categoryKey;
  final String labelAr;
  final String iconName;

  const SubcategoryView({
    required this.key,
    required this.categoryKey,
    required this.labelAr,
    required this.iconName,
  });

  @override
  List<Object?> get props => [key, categoryKey, labelAr, iconName];
}

class QuickPickItem extends Equatable {
  final String id;
  final String nameAr;
  final int? defaultAmountPiastres;
  final String categoryKey;

  /// The item's own subcategory in the catalogue, if it has one — null for
  /// the genuine one-offs that were never classified past their category.
  final String? subcategoryKey;

  /// The barcode/QR value this item was learned from, if any — set once,
  /// the first time an unknown code is scanned and the user creates an
  /// item for it. Every later scan of the same code resolves back to this
  /// item via `SpendingRepository.itemByBarcode`.
  final String? barcode;

  /// What the item cost the last time it was logged, when it has been
  /// logged. Only `SpendingRepository.recentItems` and
  /// `SpendingRepository.itemByBarcode` fill it in; the barcode path gives
  /// the price of one, since a scan multiplies it by the count scanned.
  final int? lastAmountPiastres;

  /// A key of [entryUnitLabels] when the product is sold loose by that
  /// unit (milk by the litre, tomatoes by the kilo). Then
  /// [defaultAmountPiastres] and [lastAmountPiastres] are prices of one
  /// unit, and adding it asks how much was bought. Null for a product
  /// sold by the piece or pack, which behaves as it always has.
  final String? unit;

  /// How much of [unit] is usually bought, in milli-units (2000 is two
  /// litres). Only meaningful when [unit] is set.
  final int? defaultQuantityMilli;

  const QuickPickItem({
    required this.id,
    required this.nameAr,
    required this.categoryKey,
    this.defaultAmountPiastres,
    this.subcategoryKey,
    this.barcode,
    this.lastAmountPiastres,
    this.unit,
    this.defaultQuantityMilli,
  });

  bool get isSoldByUnit => unit != null;

  /// The amount a tap on this item fills in: the last price paid, else the
  /// catalogue's default (spec §6.1: prices drift, the last one is the best
  /// guess for the next).
  int? get suggestedAmountPiastres =>
      lastAmountPiastres ?? defaultAmountPiastres;

  @override
  List<Object?> get props => [
        id,
        nameAr,
        defaultAmountPiastres,
        categoryKey,
        subcategoryKey,
        barcode,
        lastAmountPiastres,
        unit,
        defaultQuantityMilli,
      ];
}

/// What [quantityMilli] of something at [unitPricePiastres] a unit costs,
/// rounded to the piastre the way [unitPriceOf] rounds back: two litres at
/// 25 is 50, 0.75 of a kilo at 30 is 22.50.
int totalForQuantity(int unitPricePiastres, int quantityMilli) =>
    (unitPricePiastres * quantityMilli + 500) ~/ 1000;

class DraftEntry extends Equatable {
  final int? amountPiastres;
  final String? itemId;
  final String? description;
  final String? categoryKey;
  final String? subcategoryKey;
  final String? paymentMethod;
  final String? photoPath;
  final String? voiceNotePath;
  final EntrySource source;
  final double confidence;

  /// Set for a product bought loose by a unit: how much (milli-units), of
  /// which unit, at what price per unit. [amountPiastres] is then the
  /// total. Saving makes [unitPricePiastres] the item's price per unit.
  final int? quantityMilli;
  final String? unit;
  final int? unitPricePiastres;

  const DraftEntry({
    this.amountPiastres,
    this.itemId,
    this.description,
    this.categoryKey,
    this.subcategoryKey,
    this.paymentMethod,
    this.photoPath,
    this.voiceNotePath,
    required this.source,
    this.confidence = 1.0,
    this.quantityMilli,
    this.unit,
    this.unitPricePiastres,
  });

  bool get isComplete => amountPiastres != null && categoryKey != null;

  /// Returns a copy with [photoPath] replaced — including replacing it
  /// with null to remove a previously attached photo. Kept separate from
  /// [copyWith], whose `??`-based fields can't express "clear this value".
  DraftEntry withPhotoPath(String? photoPath) => DraftEntry(
        amountPiastres: amountPiastres,
        itemId: itemId,
        description: description,
        categoryKey: categoryKey,
        subcategoryKey: subcategoryKey,
        paymentMethod: paymentMethod,
        photoPath: photoPath,
        voiceNotePath: voiceNotePath,
        source: source,
        confidence: confidence,
        quantityMilli: quantityMilli,
        unit: unit,
        unitPricePiastres: unitPricePiastres,
      );

  DraftEntry copyWith({
    int? amountPiastres,
    String? description,
    String? categoryKey,
    String? subcategoryKey,
    String? paymentMethod,
  }) =>
      DraftEntry(
        amountPiastres: amountPiastres ?? this.amountPiastres,
        itemId: itemId,
        description: description ?? this.description,
        categoryKey: categoryKey ?? this.categoryKey,
        subcategoryKey: subcategoryKey ?? this.subcategoryKey,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        photoPath: photoPath,
        voiceNotePath: voiceNotePath,
        source: source,
        confidence: confidence,
        quantityMilli: quantityMilli,
        unit: unit,
        unitPricePiastres: unitPricePiastres,
      );

  @override
  List<Object?> get props => [
        amountPiastres,
        itemId,
        description,
        categoryKey,
        subcategoryKey,
        paymentMethod,
        source,
        quantityMilli,
        unit,
        unitPricePiastres,
      ];
}

/// The `app_settings` key holding the payment method of the last saved
/// entry, which the add sheet preselects (spec §6.1).
const lastPaymentMethodSettingKey = 'last_payment_method';

/// True for a settings key that names a secret (an API key, token, secret
/// or password). `app_settings` refuses these: secrets live in secure
/// storage only, never in the database, exports or backups.
///
/// A key ending in "key" is refused too, because the natural name for a
/// provider credential is `gemini_key`, with no "api" in it. None of the
/// benign settings (theme, model id, online switches, last payment method,
/// rate stamp) end that way.
bool isSecretSettingKey(String key) {
  final folded = key.toLowerCase().replaceAll(RegExp(r'[_\-\s.]'), '');
  return folded.endsWith('key') ||
      const ['apikey', 'secret', 'token', 'password'].any(folded.contains);
}

/// Thrown by `SpendingRepository.createItem` when another non-archived item
/// already holds the barcode: a scan must resolve to exactly one item.
/// One purchase of an item, for its price history: the day, the price of
/// one (see [unitPriceOf]) and what the entry itself recorded.
class ItemPrice extends Equatable {
  const ItemPrice({
    required this.date,
    required this.unitPricePiastres,
    required this.amountPiastres,
    this.quantityMilli,
  });

  final DateTime date;
  final int unitPricePiastres;
  final int amountPiastres;
  final int? quantityMilli;

  @override
  List<Object?> get props =>
      [date, unitPricePiastres, amountPiastres, quantityMilli];
}

class DuplicateBarcodeException implements Exception {
  const DuplicateBarcodeException(this.barcode);

  final String barcode;

  @override
  String toString() => 'DuplicateBarcodeException: $barcode';
}

/// Thrown by `SpendingRepository.saveCapture` when a line's payment
/// reference is already on a live entry, or on two lines of one capture
/// (spec §6.2: an InstaPay transfer is recorded once).
class DuplicateReferenceException implements Exception {
  const DuplicateReferenceException(this.reference);

  final String reference;

  @override
  String toString() => 'DuplicateReferenceException: $reference';
}

/// One line of a capture, written as one `entries` row.
class CaptureLine extends Equatable {
  final int amountPiastres;
  final String categoryKey;
  final String? subcategoryKey;
  final String? itemId;
  final String description;

  /// Milli-units: 1000 is one unit. Null means one.
  final int? quantityMilli;

  /// A key of [entryUnitLabels].
  final String? unit;
  final int? unitPricePiastres;

  /// Import identity; unique across all entries when set.
  final String? externalId;

  /// Payment reference, e.g. an InstaPay transaction number.
  final String? reference;
  final String? note;

  /// The name as it was captured, when the user linked this line to
  /// [itemId] in review (or accepted a correction by edit distance): saving
  /// learns it as an alias, so the same words match the item next time.
  final String? aliasToLearn;

  /// The barcode this line was scanned from (spec §6.3). Saving teaches it:
  /// a line with no item creates the item that holds the code from then on
  /// (the item already holding it, if one does), and a line linked to an
  /// item with no code of its own gives that item the code. A code already
  /// on another live item never moves.
  final String? barcode;

  const CaptureLine({
    required this.amountPiastres,
    required this.categoryKey,
    this.subcategoryKey,
    this.itemId,
    this.description = '',
    this.quantityMilli,
    this.unit,
    this.unitPricePiastres,
    this.externalId,
    this.reference,
    this.note,
    this.aliasToLearn,
    this.barcode,
  });

  @override
  List<Object?> get props => [
        amountPiastres,
        categoryKey,
        subcategoryKey,
        itemId,
        description,
        quantityMilli,
        unit,
        unitPricePiastres,
        externalId,
        reference,
        note,
        aliasToLearn,
        barcode,
      ];
}

/// The price of one of [line]: its unit price when it has one, else its
/// amount over its quantity, rounded to the piastre. Saving a capture makes
/// this the linked item's default price, so "two for 30" suggests 15 next
/// time, not 30.
int capturedUnitPrice(CaptureLine line) => unitPriceOf(
      amountPiastres: line.amountPiastres,
      quantityMilli: line.quantityMilli,
      unitPricePiastres: line.unitPricePiastres,
    );

/// The price of one of a line or entry of [amountPiastres] for
/// [quantityMilli]: [unitPricePiastres] when it was recorded, else the
/// amount over the quantity, rounded to the piastre.
int unitPriceOf({
  required int amountPiastres,
  int? quantityMilli,
  int? unitPricePiastres,
}) {
  if (unitPricePiastres != null) return unitPricePiastres;
  final quantity = quantityMilli;
  if (quantity == null || quantity <= 0 || quantity == 1000) {
    return amountPiastres;
  }
  return (amountPiastres * 1000 + quantity ~/ 2) ~/ quantity;
}

/// An attachment not saved yet. [path] is relative to the app documents
/// directory.
class DraftAttachment extends Equatable {
  final AttachmentKind kind;
  final String? path;
  final String? text;
  final String? transcript;
  final int? durationMs;

  const DraftAttachment({
    required this.kind,
    this.path,
    this.text,
    this.transcript,
    this.durationMs,
  });

  @override
  List<Object?> get props => [kind, path, text, transcript, durationMs];
}

/// Everything one capture produced, saved in one go by
/// `SpendingRepository.saveCapture`: the group row, one entry per line
/// (sharing [date] and [paymentMethod]), and [attachments] linked to the
/// group.
class CaptureDraft extends Equatable {
  final CaptureKind kind;
  final DateTime date;
  final String paymentMethod;
  final String? rawText;
  final String? cleanText;
  final String? parsedBy;
  final List<CaptureLine> lines;
  final List<DraftAttachment> attachments;

  /// Keep the capture for review later ("بعدين") instead of saving it. A
  /// draft stores its raw text and attachments only: it must carry no
  /// lines, because a line is an entry and an entry counts toward every
  /// total before anyone has checked it. Review re-reads the raw text.
  final bool isDraft;

  /// The draft capture group this review finishes, when the review was
  /// opened from Needs review. Saving then writes into that group instead
  /// of a new one: its status, lines and [attachments] (which are the ones
  /// added during review; the draft's own stay linked). Its raw text is
  /// what was captured and is kept as it is.
  final String? draftId;

  const CaptureDraft({
    required this.kind,
    required this.date,
    required this.lines,
    this.paymentMethod = 'Cash',
    this.rawText,
    this.cleanText,
    this.parsedBy,
    this.attachments = const [],
    this.isDraft = false,
    this.draftId,
  });

  /// A draft is `draft`; otherwise a capture with lines is `saved` and one
  /// without is kept as a `note`.
  CaptureStatus get status => isDraft
      ? CaptureStatus.draft
      : lines.isEmpty
          ? CaptureStatus.note
          : CaptureStatus.saved;

  @override
  List<Object?> get props => [
        kind,
        date,
        paymentMethod,
        rawText,
        cleanText,
        parsedBy,
        lines,
        attachments,
        isDraft,
        draftId,
      ];
}

class AttachmentView extends Equatable {
  final String id;
  final String? entryId;
  final String? captureGroupId;
  final AttachmentKind kind;
  final String? path;
  final String? text;
  final String? transcript;
  final int? durationMs;
  final DateTime createdAt;

  const AttachmentView({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.entryId,
    this.captureGroupId,
    this.path,
    this.text,
    this.transcript,
    this.durationMs,
  });

  @override
  List<Object?> get props => [
        id,
        entryId,
        captureGroupId,
        kind,
        path,
        text,
        transcript,
        durationMs,
        createdAt,
      ];
}

/// A saved entry with every v3 field, for the review and detail screens.
class EntryRecord extends Equatable {
  final String id;
  final DateTime date;
  final int amountPiastres;
  final String categoryKey;
  final String? subcategoryKey;
  final String? itemId;
  final String description;
  final String paymentMethod;
  final EntrySource source;
  final int? quantityMilli;
  final String? unit;
  final int? unitPricePiastres;
  final String? captureGroupId;
  final String? externalId;
  final String? reference;
  final String? note;

  const EntryRecord({
    required this.id,
    required this.date,
    required this.amountPiastres,
    required this.categoryKey,
    required this.description,
    required this.paymentMethod,
    required this.source,
    this.subcategoryKey,
    this.itemId,
    this.quantityMilli,
    this.unit,
    this.unitPricePiastres,
    this.captureGroupId,
    this.externalId,
    this.reference,
    this.note,
  });

  @override
  List<Object?> get props => [
        id,
        date,
        amountPiastres,
        categoryKey,
        subcategoryKey,
        itemId,
        description,
        paymentMethod,
        source,
        quantityMilli,
        unit,
        unitPricePiastres,
        captureGroupId,
        externalId,
        reference,
        note,
      ];
}

class CaptureGroupView extends Equatable {
  final String id;
  final CaptureKind kind;
  final CaptureStatus status;
  final String? rawText;
  final String? cleanText;
  final String? parsedBy;
  final DateTime date;
  final List<EntryRecord> entries;
  final List<AttachmentView> attachments;

  const CaptureGroupView({
    required this.id,
    required this.kind,
    required this.status,
    required this.date,
    required this.entries,
    required this.attachments,
    this.rawText,
    this.cleanText,
    this.parsedBy,
  });

  @override
  List<Object?> get props => [
        id,
        kind,
        status,
        rawText,
        cleanText,
        parsedBy,
        date,
        entries,
        attachments,
      ];
}

class RecurringBillView extends Equatable {
  final String id;
  final String nameAr;
  final int amountPiastres;
  final String categoryKey;
  final String? subcategoryKey;
  final int everyMonths;
  final DateTime nextDue;
  final int remindDaysBefore;
  final bool archived;

  const RecurringBillView({
    required this.id,
    required this.nameAr,
    required this.amountPiastres,
    required this.categoryKey,
    required this.everyMonths,
    required this.nextDue,
    required this.remindDaysBefore,
    this.subcategoryKey,
    this.archived = false,
  });

  @override
  List<Object?> get props => [
        id,
        nameAr,
        amountPiastres,
        categoryKey,
        subcategoryKey,
        everyMonths,
        nextDue,
        remindDaysBefore,
        archived,
      ];
}
