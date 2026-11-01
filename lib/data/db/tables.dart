import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get key => text()();
  TextColumn get labelAr => text()();
  TextColumn get iconName => text()();

  /// One of the colour keys in spec §7.2 (`Drinks` ... `Other`). Added in
  /// v3 and backfilled there, so it is null only between the column being
  /// added and the backfill running; readers fall back to `Other`.
  TextColumn get colorKey => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {key};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get nameAr => text()();
  TextColumn get nameEn => text()();
  TextColumn get categoryKey => text().references(Categories, #key)();
  TextColumn get subcategoryKey =>
      text().nullable().references(Subcategories, #key)();
  IntColumn get defaultAmountPiastres => integer().nullable()();
  TextColumn get barcode => text().nullable()();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  // v4 columns, nullable so every product that already exists keeps
  // behaving as before.

  /// A key of `entryUnitLabels` (`liter`, `kg`, `g`, ...) when the product
  /// is sold loose by that unit, like milk by the litre at the market. Then
  /// [defaultAmountPiastres] is the price of one unit. Null for a product
  /// sold by the piece or pack.
  TextColumn get unit => text().nullable()();

  /// How much of [unit] is usually bought, in milli-units (2000 is two
  /// litres). Only meaningful when [unit] is set.
  IntColumn get defaultQuantityMilli => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'entries_date', columns: {#date})
@TableIndex(name: 'entries_capture_group_id', columns: {#captureGroupId})
@TableIndex(name: 'entries_deleted_at', columns: {#deletedAt})
// Partial, so the many rows with no import identity never collide; an
// import that runs twice cannot insert the same row twice.
@TableIndex.sql('CREATE UNIQUE INDEX entries_external_id ON entries '
    '(external_id) WHERE external_id IS NOT NULL')
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get amountPiastres => integer()();
  TextColumn get categoryKey => text().references(Categories, #key)();
  TextColumn get subcategoryKey =>
      text().nullable().references(Subcategories, #key)();
  TextColumn get itemId => text().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get paymentMethod => text().withDefault(const Constant('Cash'))();

  /// Kept for rows written before v3 only. v3 stores photos as
  /// [Attachments] rows (the migration backfills one per photoPath) and
  /// never writes this column again.
  TextColumn get photoPath => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  // v3 columns. All nullable, so adding them never touches an existing row.

  /// Quantity in milli-units: 1000 is one unit, 1500 is 1.5 كيلو. Null
  /// means one.
  IntColumn get quantityMilli => integer().nullable()();

  /// English unit key (`piece`, `kg`, `g`, `liter`, ...); see `EntryUnit`.
  TextColumn get unit => text().nullable()();
  IntColumn get unitPricePiastres => integer().nullable()();
  TextColumn get captureGroupId =>
      text().nullable().references(CaptureGroups, #id)();

  /// Import identity (an import pack's `ref`), unique when set.
  TextColumn get externalId => text().nullable()();

  /// Payment reference, e.g. an InstaPay transaction number.
  TextColumn get reference => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The second level of the Category -> Subcategory -> Item structure
/// introduced in schema v2. Keys are English (e.g. `Soda`); only labels
/// are shown to the user, in Arabic.
class Subcategories extends Table {
  TextColumn get key => text()();
  TextColumn get categoryKey => text().references(Categories, #key)();
  TextColumn get labelAr => text()();
  TextColumn get iconName => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {key};
}

@TableIndex.sql('CREATE UNIQUE INDEX salary_periods_external_id ON '
    'salary_periods (external_id) WHERE external_id IS NOT NULL')
class SalaryPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get datePaid => text()(); // YYYY-MM-DD
  IntColumn get amountPiastres => integer()();
  TextColumn get evidencePhotoPath => text().nullable()();
  TextColumn get note => text().nullable()();

  /// Import identity, unique when set (v3).
  TextColumn get externalId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One capture event (a voice note, a typed note, a photo, a scan, an
/// import or a manual add). The entries written from it share its id in
/// `entries.captureGroupId`, and its attachments hang off it. Added in v3.
class CaptureGroups extends Table {
  TextColumn get id => text()();

  /// `voice`, `text`, `photo`, `barcode`, `import` or `manual`.
  TextColumn get kind => text()();

  /// `draft` (not reviewed yet), `saved` (entries were written) or `note`
  /// (kept as a standalone note with no entries).
  TextColumn get status => text()();

  /// The transcript or typed text exactly as captured, never altered.
  TextColumn get rawText => text().nullable()();

  /// The rewritten text from تحسين, kept beside [rawText].
  TextColumn get cleanText => text().nullable()();

  /// `local` or `gemini`.
  TextColumn get parsedBy => text().nullable()();
  TextColumn get date => text()(); // YYYY-MM-DD
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A photo, voice recording, text note or file belonging to an entry, a
/// capture group, or both. Added in v3; the migration backfills one photo
/// row per pre-v3 `entries.photoPath`.
@TableIndex(name: 'attachments_entry_id', columns: {#entryId})
@TableIndex(name: 'attachments_capture_group_id', columns: {#captureGroupId})
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().nullable().references(Entries, #id)();
  TextColumn get captureGroupId =>
      text().nullable().references(CaptureGroups, #id)();

  /// `photo`, `voice`, `text` or `file`.
  TextColumn get kind => text()();

  /// Relative to the app documents directory, never absolute: Android can
  /// move that directory on restore. New files go under
  /// `attachments/<yyyy-MM>/<id>.<ext>`; backfilled photos keep their
  /// `photos/...` path.
  TextColumn get path => text().nullable()();

  /// Body of a text note. Spec §5 calls this column `text`; it is `body`
  /// because drift's generated migration-test schema names each column
  /// getter after its SQL name, and a getter called `text` collides with
  /// drift's own `Table.text()` builder.
  TextColumn get body => text().nullable()();
  TextColumn get transcript => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  // An attachment that belongs to nothing could never be shown or cleaned
  // up, so the database refuses it.
  @override
  List<String> get customConstraints =>
      ['CHECK (entry_id IS NOT NULL OR capture_group_id IS NOT NULL)'];
}

/// A spelling the user has linked to a catalogue item in review, stored in
/// normalised form (see `normalizeArabic`), so the parser can match it next
/// time. Added in v3.
@DataClassName('ItemAlias')
class ItemAliases extends Table {
  TextColumn get alias => text()();
  TextColumn get itemId => text().references(Items, #id)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {alias};
}

/// A bill that comes back every [everyMonths] months. Added in v3.
class RecurringBills extends Table {
  TextColumn get id => text()();
  TextColumn get nameAr => text()();
  IntColumn get amountPiastres => integer()();
  TextColumn get categoryKey => text().references(Categories, #key)();
  TextColumn get subcategoryKey =>
      text().nullable().references(Subcategories, #key)();
  IntColumn get everyMonths => integer().withDefault(const Constant(1))();
  TextColumn get nextDue => text()(); // YYYY-MM-DD
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(2))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Plain key/value preferences (online switches, theme, model id, last
/// payment method, the barcode-lookup rate stamp). Never secrets: the
/// Gemini key lives in secure storage only. Added in v3.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
