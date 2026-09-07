import 'dart:async';

import 'package:drift/drift.dart';

import 'db/database.dart';
import '../domain/models.dart';
import '../domain/spending_repository.dart';

/// Real persistence for [SpendingRepository], backed by a drift/SQLite
/// database. The current period runs from the most recent salary payment
/// up to (not including) the next one; when there is no "next" one yet,
/// it runs up to now.
class DriftSpendingRepository implements SpendingRepository {
  DriftSpendingRepository(this._db);

  final AppDatabase _db;

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Stream<PeriodSummary> watchCurrentPeriod() {
    final periodsStream = (_db.select(_db.salaryPeriods)
          ..orderBy([(t) => OrderingTerm.desc(t.datePaid)]))
        .watch();
    // asyncExpand switches to a fresh `entries` stream whenever the salary
    // periods change, but otherwise keeps forwarding entry-table updates
    // straight through — so this reacts to both tables without a second
    // stream-combining dependency.
    return periodsStream.asyncExpand((periods) {
      return _db.select(_db.entries).watch().map((allEntries) {
        return _summaryFor(periods, allEntries);
      });
    });
  }

  PeriodSummary _summaryFor(List<SalaryPeriod> periods, List<Entry> entries) {
    if (periods.isEmpty) {
      return const PeriodSummary(
        salaryPiastres: 0,
        spentPiastres: 0,
        daysRemaining: 0,
      );
    }
    final sorted = [...periods]
      ..sort((a, b) => b.datePaid.compareTo(a.datePaid));
    final current = sorted.first;
    final periodLengthDays = _periodLengthDays(sorted);
    final elapsed =
        DateTime.now().difference(DateTime.parse(current.datePaid)).inDays;
    final daysRemaining = periodLengthDays - elapsed;

    final spent = entries
        .where((e) =>
            e.deletedAt == null && e.date.compareTo(current.datePaid) >= 0)
        .fold(0, (sum, e) => sum + e.amountPiastres);

    return PeriodSummary(
      salaryPiastres: current.amountPiastres,
      spentPiastres: spent,
      daysRemaining: daysRemaining,
    );
  }

  /// Median gap (in days) between the last three salary payments, clamped
  /// to a sane 25-35 day range. Falls back to 30 when there isn't enough
  /// history yet to compute a gap.
  int _periodLengthDays(List<SalaryPeriod> sortedDesc) {
    if (sortedDesc.length < 2) return 30;
    final lastThree = sortedDesc.take(3).toList();
    final gaps = <int>[];
    for (var i = 0; i < lastThree.length - 1; i++) {
      final later = DateTime.parse(lastThree[i].datePaid);
      final earlier = DateTime.parse(lastThree[i + 1].datePaid);
      gaps.add(later.difference(earlier).inDays);
    }
    gaps.sort();
    final mid = gaps.length ~/ 2;
    final median = gaps.length.isOdd
        ? gaps[mid]
        : ((gaps[mid - 1] + gaps[mid]) / 2).round();
    return median.clamp(25, 35);
  }

  @override
  Stream<List<EntryView>> watchEntriesForDay(DateTime day) {
    final dateStr = _formatDate(day);
    final query = _db.select(_db.entries).join([
      innerJoin(_db.categories,
          _db.categories.key.equalsExp(_db.entries.categoryKey)),
      leftOuterJoin(_db.items, _db.items.id.equalsExp(_db.entries.itemId)),
    ])
      ..where(_db.entries.date.equals(dateStr) & _db.entries.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(_db.entries.createdAt)]);

    return query.watch().map((rows) => rows.map((row) {
          final entry = row.readTable(_db.entries);
          final category = row.readTable(_db.categories);
          final item = row.readTableOrNull(_db.items);
          final name = entry.description.isNotEmpty
              ? entry.description
              : (item?.nameAr ?? '');
          return EntryView(
            id: entry.id,
            displayName: name,
            amountPiastres: entry.amountPiastres,
            categoryKey: entry.categoryKey,
            categoryLabelAr: category.labelAr,
            date: DateTime.parse(entry.date),
          );
        }).toList());
  }

  @override
  Future<List<QuickPickItem>> topItems(int limit) async {
    final rows = await (_db.select(_db.items)
          ..where((t) => t.archived.equals(false)))
        .get();
    return _topScored(rows, limit);
  }

  @override
  Future<List<QuickPickItem>> itemsInCategory(
      String categoryKey, int limit) async {
    final rows = await (_db.select(_db.items)
          ..where((t) =>
              t.archived.equals(false) & t.categoryKey.equals(categoryKey)))
        .get();
    return _topScored(rows, limit);
  }

  @override
  Future<List<QuickPickItem>> itemsInSubcategory(
      String subcategoryKey, int limit) async {
    final rows = await (_db.select(_db.items)
          ..where((t) =>
              t.archived.equals(false) &
              t.subcategoryKey.equals(subcategoryKey)))
        .get();
    return _topScored(rows, limit);
  }

  /// Same recency-weighted ranking [topItems] uses, shared by
  /// [itemsInCategory] so "most used" means the same thing everywhere in
  /// the sheet.
  List<QuickPickItem> _topScored(List<Item> rows, int limit) {
    final now = DateTime.now();

    double score(Item item) {
      final lastUsedAt = item.lastUsedAt;
      if (lastUsedAt == null) return 0;
      final daysSinceUse = now.difference(lastUsedAt).inDays;
      final recencyWeight = daysSinceUse < 0 ? 1 : daysSinceUse;
      return item.useCount / (1 + recencyWeight);
    }

    final sorted = [...rows]..sort((a, b) => score(b).compareTo(score(a)));
    return sorted
        .take(limit)
        .map((i) => QuickPickItem(
              id: i.id,
              nameAr: i.nameAr,
              categoryKey: i.categoryKey,
              subcategoryKey: i.subcategoryKey,
              defaultAmountPiastres: i.defaultAmountPiastres,
            ))
        .toList();
  }

  @override
  Future<List<CategoryView>> categories() async {
    final rows = await (_db.select(_db.categories)
          ..where((t) => t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows
        .map((c) => CategoryView(
              key: c.key,
              labelAr: c.labelAr,
              iconName: c.iconName,
            ))
        .toList();
  }

  @override
  Future<List<SubcategoryView>> subcategories(String categoryKey) async {
    final rows = await (_db.select(_db.subcategories)
          ..where((t) =>
              t.categoryKey.equals(categoryKey) & t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows
        .map((s) => SubcategoryView(
              key: s.key,
              categoryKey: s.categoryKey,
              labelAr: s.labelAr,
              iconName: s.iconName,
            ))
        .toList();
  }

  @override
  Future<QuickPickItem> createItem({
    required String nameAr,
    required String categoryKey,
    String? subcategoryKey,
    int? defaultAmountPiastres,
    String? barcode,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.items).insert(ItemsCompanion.insert(
          id: id,
          nameAr: nameAr,
          // The user only supplies an Arabic name; there is no separate
          // English one to capture, so mirror it to satisfy the column.
          nameEn: nameAr,
          categoryKey: categoryKey,
          subcategoryKey: Value(subcategoryKey),
          defaultAmountPiastres: Value(defaultAmountPiastres),
          barcode: Value(barcode),
        ));
    return QuickPickItem(
      id: id,
      nameAr: nameAr,
      categoryKey: categoryKey,
      subcategoryKey: subcategoryKey,
      defaultAmountPiastres: defaultAmountPiastres,
    );
  }

  @override
  Future<void> saveEntry(DraftEntry draft) async {
    final amount = draft.amountPiastres;
    final categoryKey = draft.categoryKey;
    if (amount == null || categoryKey == null) {
      throw ArgumentError('DraftEntry must be complete before it can be saved');
    }

    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();

    await _db.into(_db.entries).insert(EntriesCompanion.insert(
          id: id,
          date: _formatDate(now),
          amountPiastres: amount,
          categoryKey: categoryKey,
          subcategoryKey: Value(draft.subcategoryKey),
          itemId: Value(draft.itemId),
          description: Value(draft.description ?? ''),
          paymentMethod: Value(draft.paymentMethod ?? 'Cash'),
          photoPath: Value(draft.photoPath),
          source: Value(draft.source.name),
          createdAt: now,
          updatedAt: now,
        ));

    final itemId = draft.itemId;
    if (itemId != null) {
      final item = await (_db.select(_db.items)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      if (item != null) {
        await (_db.update(_db.items)..where((t) => t.id.equals(itemId))).write(
          ItemsCompanion(
            useCount: Value(item.useCount + 1),
            lastUsedAt: Value(now),
          ),
        );
      }
    }
  }

  @override
  Future<Map<String, int>> spendByCategoryForPeriod() async {
    final periods = await _db.select(_db.salaryPeriods).get();
    if (periods.isEmpty) return {};
    final sorted = [...periods]
      ..sort((a, b) => b.datePaid.compareTo(a.datePaid));
    final currentStart = sorted.first.datePaid;

    final rows = await (_db.select(_db.entries)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(currentStart) & t.deletedAt.isNull()))
        .get();

    final map = <String, int>{};
    for (final e in rows) {
      map[e.categoryKey] = (map[e.categoryKey] ?? 0) + e.amountPiastres;
    }
    return map;
  }

  @override
  Future<int> spentInMonth(int year, int month) async {
    final prefix = '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}';
    final rows = await (_db.select(_db.entries)
          ..where((t) => t.date.like('$prefix-%') & t.deletedAt.isNull()))
        .get();
    return rows.fold<int>(0, (sum, e) => sum + e.amountPiastres);
  }

  @override
  Future<List<({String yearMonth, int totalPiastres})>> monthlyTotals(
      int lastNMonths) async {
    final now = DateTime.now();
    final totals = <({String yearMonth, int totalPiastres})>[];
    for (var i = lastNMonths - 1; i >= 0; i--) {
      var year = now.year;
      var month = now.month - i;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }
      final total = await spentInMonth(year, month);
      final yearMonth = '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}';
      totals.add((yearMonth: yearMonth, totalPiastres: total));
    }
    return totals;
  }

  @override
  Future<List<({String label, int totalPiastres})>> dailyTotals(
      int lastNDays) async {
    final anchor = _todayAnchor();
    final totals = <({String label, int totalPiastres})>[];
    for (var i = lastNDays - 1; i >= 0; i--) {
      final day = anchor.subtract(Duration(days: i));
      final total = await _spentInRange(day, day);
      totals.add((label: day.day.toString(), totalPiastres: total));
    }
    return totals;
  }

  @override
  Future<List<({String label, int totalPiastres})>> weeklyTotals(
      int lastNWeeks) async {
    final anchor = _todayAnchor();
    final totals = <({String label, int totalPiastres})>[];
    for (var i = lastNWeeks - 1; i >= 0; i--) {
      final weekEnd = anchor.subtract(Duration(days: i * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));
      final total = await _spentInRange(weekStart, weekEnd);
      totals.add((label: weekStart.day.toString(), totalPiastres: total));
    }
    return totals;
  }

  DateTime _todayAnchor() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Sum of non-soft-deleted entries with a date between [start] and [end]
  /// inclusive. Dates are compared as `YYYY-MM-DD` strings, which sort
  /// lexicographically in calendar order — including across month and year
  /// boundaries — so this needs no special-casing for either.
  Future<int> _spentInRange(DateTime start, DateTime end) async {
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);
    final rows = await (_db.select(_db.entries)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startStr) &
              t.date.isSmallerOrEqualValue(endStr) &
              t.deletedAt.isNull()))
        .get();
    return rows.fold<int>(0, (sum, e) => sum + e.amountPiastres);
  }

  @override
  Future<void> updateSalary(int amountPiastres) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.salaryPeriods).insert(SalaryPeriodsCompanion.insert(
          id: id,
          datePaid: _formatDate(DateTime.now()),
          amountPiastres: amountPiastres,
        ));
  }

  @override
  Future<List<QuickPickItem>> allItems() async {
    final rows = await (_db.select(_db.items)
          ..where((t) => t.archived.equals(false)))
        .get();
    return rows
        .map((i) => QuickPickItem(
              id: i.id,
              nameAr: i.nameAr,
              categoryKey: i.categoryKey,
              subcategoryKey: i.subcategoryKey,
              defaultAmountPiastres: i.defaultAmountPiastres,
            ))
        .toList();
  }

  @override
  Future<void> archiveItem(String itemId) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(itemId)))
        .write(const ItemsCompanion(archived: Value(true)));
  }

  @override
  Future<void> updateItem({
    required String itemId,
    required String nameAr,
    required String categoryKey,
    int? defaultAmountPiastres,
  }) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        nameAr: Value(nameAr),
        categoryKey: Value(categoryKey),
        defaultAmountPiastres: Value(defaultAmountPiastres),
      ),
    );
  }

  @override
  Future<CategoryView> createCategory({
    required String key,
    required String labelAr,
    required String iconName,
  }) async {
    final rows = await (_db.select(_db.categories)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .get();
    final nextSortOrder = rows.isEmpty ? 0 : rows.first.sortOrder + 1;
    await _db.into(_db.categories).insert(CategoriesCompanion.insert(
          key: key,
          labelAr: labelAr,
          iconName: iconName,
          sortOrder: Value(nextSortOrder),
        ));
    return CategoryView(key: key, labelAr: labelAr, iconName: iconName);
  }

  @override
  Future<void> updateCategory({
    required String key,
    required String labelAr,
    required String iconName,
  }) async {
    await (_db.update(_db.categories)..where((t) => t.key.equals(key))).write(
      CategoriesCompanion(
        labelAr: Value(labelAr),
        iconName: Value(iconName),
      ),
    );
  }

  @override
  Future<void> archiveCategory(String key) async {
    await _db.transaction(() async {
      await (_db.update(_db.categories)..where((t) => t.key.equals(key)))
          .write(const CategoriesCompanion(archived: Value(true)));
      // Cascade: a subcategory or item left visible under an archived
      // category would be unreachable through any picker (the category
      // itself no longer appears), so hide them too. `entries` is never
      // touched here — it has no `archived` column and keeps whatever
      // category/subcategory it was saved with forever.
      await (_db.update(_db.subcategories)
            ..where((t) => t.categoryKey.equals(key)))
          .write(const SubcategoriesCompanion(archived: Value(true)));
      await (_db.update(_db.items)..where((t) => t.categoryKey.equals(key)))
          .write(const ItemsCompanion(archived: Value(true)));
    });
  }

  @override
  Future<SubcategoryView> createSubcategory({
    required String key,
    required String categoryKey,
    required String labelAr,
    required String iconName,
  }) async {
    final rows = await (_db.select(_db.subcategories)
          ..where((t) => t.categoryKey.equals(categoryKey))
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .get();
    final nextSortOrder = rows.isEmpty ? 0 : rows.first.sortOrder + 1;
    await _db.into(_db.subcategories).insert(SubcategoriesCompanion.insert(
          key: key,
          categoryKey: categoryKey,
          labelAr: labelAr,
          iconName: iconName,
          sortOrder: Value(nextSortOrder),
        ));
    return SubcategoryView(
      key: key,
      categoryKey: categoryKey,
      labelAr: labelAr,
      iconName: iconName,
    );
  }

  @override
  Future<void> updateSubcategory({
    required String key,
    required String categoryKey,
    required String labelAr,
    required String iconName,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.subcategories)..where((t) => t.key.equals(key)))
          .write(SubcategoriesCompanion(
        categoryKey: Value(categoryKey),
        labelAr: Value(labelAr),
        iconName: Value(iconName),
      ));
      // Keep the catalogue internally consistent: any catalogue item filed
      // under this subcategory follows it to the new category. `entries`
      // (past spending history) is never touched — a saved entry keeps the
      // exact categoryKey/subcategoryKey pair it was recorded with,
      // regardless of any later catalogue reorganisation.
      await (_db.update(_db.items)
            ..where((t) => t.subcategoryKey.equals(key)))
          .write(ItemsCompanion(categoryKey: Value(categoryKey)));
    });
  }

  @override
  Future<void> archiveSubcategory(String key) async {
    await _db.transaction(() async {
      await (_db.update(_db.subcategories)..where((t) => t.key.equals(key)))
          .write(const SubcategoriesCompanion(archived: Value(true)));
      await (_db.update(_db.items)
            ..where((t) => t.subcategoryKey.equals(key)))
          .write(const ItemsCompanion(archived: Value(true)));
    });
  }

  @override
  Future<void> unarchiveItem(String itemId) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(itemId)))
        .write(const ItemsCompanion(archived: Value(false)));
  }

  @override
  Future<List<QuickPickItem>> archivedItems() async {
    final rows = await (_db.select(_db.items)
          ..where((t) => t.archived.equals(true)))
        .get();
    return rows
        .map((i) => QuickPickItem(
              id: i.id,
              nameAr: i.nameAr,
              categoryKey: i.categoryKey,
              subcategoryKey: i.subcategoryKey,
              defaultAmountPiastres: i.defaultAmountPiastres,
            ))
        .toList();
  }

  @override
  Future<void> unarchiveCategory(String key) async {
    await _db.transaction(() async {
      await (_db.update(_db.categories)..where((t) => t.key.equals(key)))
          .write(const CategoriesCompanion(archived: Value(false)));
      // Mirror archiveCategory's cascade in reverse: bring back every
      // subcategory and item that lives under this category, so a
      // category that was hidden along with its whole subtree comes back
      // whole. `entries` has no `archived` column and was never touched by
      // the archive in the first place, so there is nothing to restore on
      // it here.
      await (_db.update(_db.subcategories)
            ..where((t) => t.categoryKey.equals(key)))
          .write(const SubcategoriesCompanion(archived: Value(false)));
      await (_db.update(_db.items)..where((t) => t.categoryKey.equals(key)))
          .write(const ItemsCompanion(archived: Value(false)));
    });
  }

  @override
  Future<void> unarchiveSubcategory(String key) async {
    await _db.transaction(() async {
      await (_db.update(_db.subcategories)..where((t) => t.key.equals(key)))
          .write(const SubcategoriesCompanion(archived: Value(false)));
      await (_db.update(_db.items)
            ..where((t) => t.subcategoryKey.equals(key)))
          .write(const ItemsCompanion(archived: Value(false)));
      // Deliberately does NOT touch the subcategory's own category row:
      // unarchiving a subcategory must never cascade upward and resurrect
      // a category the user archived on purpose.
    });
  }

  @override
  Future<List<CategoryView>> archivedCategories() async {
    final rows = await (_db.select(_db.categories)
          ..where((t) => t.archived.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows
        .map((c) => CategoryView(
              key: c.key,
              labelAr: c.labelAr,
              iconName: c.iconName,
            ))
        .toList();
  }

  @override
  Future<List<SubcategoryView>> archivedSubcategories() async {
    final rows = await (_db.select(_db.subcategories)
          ..where((t) => t.archived.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows
        .map((s) => SubcategoryView(
              key: s.key,
              categoryKey: s.categoryKey,
              labelAr: s.labelAr,
              iconName: s.iconName,
            ))
        .toList();
  }
}
