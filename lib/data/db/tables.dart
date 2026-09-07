import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get key => text()();
  TextColumn get labelAr => text()();
  TextColumn get iconName => text()();
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

  @override
  Set<Column> get primaryKey => {id};
}

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
  TextColumn get photoPath => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

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

class SalaryPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get datePaid => text()(); // YYYY-MM-DD
  IntColumn get amountPiastres => integer()();
  TextColumn get evidencePhotoPath => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
