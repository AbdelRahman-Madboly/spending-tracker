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

class PeriodSummary extends Equatable {
  final int salaryPiastres;
  final int spentPiastres;
  final int daysRemaining;

  const PeriodSummary({
    required this.salaryPiastres,
    required this.spentPiastres,
    required this.daysRemaining,
  });

  int get leftPiastres => salaryPiastres - spentPiastres;

  /// Null when nothing is left. A negative daily allowance is noise; the red
  /// `left` figure already carries the message.
  int? get safeDailyPiastres {
    if (leftPiastres <= 0 || daysRemaining <= 0) return null;
    return leftPiastres ~/ daysRemaining;
  }

  @override
  List<Object?> get props => [salaryPiastres, spentPiastres, daysRemaining];
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

  const QuickPickItem({
    required this.id,
    required this.nameAr,
    required this.categoryKey,
    this.defaultAmountPiastres,
    this.subcategoryKey,
    this.barcode,
  });

  @override
  List<Object?> get props => [
        id,
        nameAr,
        defaultAmountPiastres,
        categoryKey,
        subcategoryKey,
        barcode,
      ];
}

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
      );

  @override
  List<Object?> get props => [
        amountPiastres,
        itemId,
        description,
        categoryKey,
        subcategoryKey,
        paymentMethod,
        source
      ];
}

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
class DuplicateBarcodeException implements Exception {
  const DuplicateBarcodeException(this.barcode);

  final String barcode;

  @override
  String toString() => 'DuplicateBarcodeException: $barcode';
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
      ];
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

  const CaptureDraft({
    required this.kind,
    required this.date,
    required this.lines,
    this.paymentMethod = 'Cash',
    this.rawText,
    this.cleanText,
    this.parsedBy,
    this.attachments = const [],
  });

  /// A capture with lines is `saved`; one without is kept as a `note`.
  CaptureStatus get status =>
      lines.isEmpty ? CaptureStatus.note : CaptureStatus.saved;

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
