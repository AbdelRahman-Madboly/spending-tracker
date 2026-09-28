import 'dart:async';

import 'package:drift/drift.dart';

import 'db/database.dart';
import '../core/arabic_text.dart';
import '../domain/models.dart';
import '../domain/spending_repository.dart';

/// Real persistence for [SpendingRepository], backed by a drift/SQLite
/// database. The current period runs from the most recent salary payment
/// up to (not including) the next one; when there is no "next" one yet,
/// it runs up to now.
class DriftSpendingRepository implements SpendingRepository {
  DriftSpendingRepository(this._db);

  final AppDatabase _db;

  static int _idSequence = 0;

  /// A time-based id with a per-process counter, so ids generated in the
  /// same microsecond (several lines of one capture) never collide.
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

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
              barcode: i.barcode,
            ))
        .toList();
  }

  @override
  Future<List<CategoryView>> categories() async {
    final rows = await (_db.select(_db.categories)
          ..where((t) => t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_categoryView).toList();
  }

  static CategoryView _categoryView(Category c) => CategoryView(
        key: c.key,
        labelAr: c.labelAr,
        iconName: c.iconName,
        colorKey: c.colorKey ?? 'Other',
      );

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
    if (barcode != null && await itemByBarcode(barcode) != null) {
      throw DuplicateBarcodeException(barcode);
    }
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
      barcode: barcode,
    );
  }

  @override
  Future<QuickPickItem?> itemByBarcode(String barcode) async {
    final row = await (_db.select(_db.items)
          ..where((t) =>
              t.archived.equals(false) & t.barcode.equals(barcode))
          // Every write path keeps a barcode on one live item, but a pair
          // written before that rule existed must still resolve to an item
          // rather than throw out of a scan: take the first in id order.
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return QuickPickItem(
      id: row.id,
      nameAr: row.nameAr,
      categoryKey: row.categoryKey,
      subcategoryKey: row.subcategoryKey,
      defaultAmountPiastres: row.defaultAmountPiastres,
      barcode: row.barcode,
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

    await _db.transaction(() async {
      await _db.into(_db.entries).insert(EntriesCompanion.insert(
            id: id,
            date: _formatDate(now),
            amountPiastres: amount,
            categoryKey: categoryKey,
            subcategoryKey: Value(draft.subcategoryKey),
            itemId: Value(draft.itemId),
            description: Value(draft.description ?? ''),
            paymentMethod: Value(draft.paymentMethod ?? 'Cash'),
            source: Value(draft.source.name),
            createdAt: now,
            updatedAt: now,
          ));
      // Since v3 a photo is an attachment row; entries.photoPath is only
      // read for rows written before v3 (and was backfilled then).
      final photoPath = draft.photoPath;
      if (photoPath != null) {
        await _insertAttachment(
          entryId: id,
          attachment:
              DraftAttachment(kind: AttachmentKind.photo, path: photoPath),
          now: now,
        );
      }
      await _bumpItemUse(draft.itemId, now);
    });
  }

  Future<void> _bumpItemUse(String? itemId, DateTime now) async {
    if (itemId == null) return;
    final item = await (_db.select(_db.items)
          ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) return;
    await (_db.update(_db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        useCount: Value(item.useCount + 1),
        lastUsedAt: Value(now),
      ),
    );
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
              barcode: i.barcode,
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
    String colorKey = 'Other',
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
          colorKey: Value(colorKey),
          sortOrder: Value(nextSortOrder),
        ));
    return CategoryView(
        key: key, labelAr: labelAr, iconName: iconName, colorKey: colorKey);
  }

  @override
  Future<void> updateCategory({
    required String key,
    required String labelAr,
    required String iconName,
    String? colorKey,
  }) async {
    await (_db.update(_db.categories)..where((t) => t.key.equals(key))).write(
      CategoriesCompanion(
        labelAr: Value(labelAr),
        iconName: Value(iconName),
        colorKey: colorKey == null ? const Value.absent() : Value(colorKey),
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
    await _db.transaction(() async {
      final row = await (_db.select(_db.items)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      final barcode = row?.barcode;
      if (barcode != null) {
        final holder = await itemByBarcode(barcode);
        if (holder != null && holder.id != itemId) {
          throw DuplicateBarcodeException(barcode);
        }
      }
      await (_db.update(_db.items)..where((t) => t.id.equals(itemId)))
          .write(const ItemsCompanion(archived: Value(false)));
    });
  }

  /// Un-archives the archived items [where] selects, for the category and
  /// subcategory cascades.
  ///
  /// A barcode must stay on one non-archived item, and while an item sat in
  /// the archive the user may have taught its barcode to a new one. Such an
  /// item is skipped and stays archived with its barcode intact: the
  /// cascade restores everything else, nothing is rewritten, and an
  /// explicit [unarchiveItem] on it later reports the clash. When two
  /// archived items share a barcode, the first in id order comes back.
  Future<void> _restoreItemsWhere(
      Expression<bool> Function($ItemsTable t) where) async {
    await (_db.update(_db.items)
          ..where(
              (t) => t.archived.equals(true) & t.barcode.isNull() & where(t)))
        .write(const ItemsCompanion(archived: Value(false)));
    final withBarcode = await (_db.select(_db.items)
          ..where(
              (t) => t.archived.equals(true) & t.barcode.isNotNull() & where(t))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    for (final row in withBarcode) {
      if (await itemByBarcode(row.barcode!) != null) continue;
      await (_db.update(_db.items)..where((t) => t.id.equals(row.id)))
          .write(const ItemsCompanion(archived: Value(false)));
    }
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
              barcode: i.barcode,
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
      await _restoreItemsWhere((t) => t.categoryKey.equals(key));
    });
  }

  @override
  Future<void> unarchiveSubcategory(String key) async {
    await _db.transaction(() async {
      await (_db.update(_db.subcategories)..where((t) => t.key.equals(key)))
          .write(const SubcategoriesCompanion(archived: Value(false)));
      await _restoreItemsWhere((t) => t.subcategoryKey.equals(key));
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
    return rows.map(_categoryView).toList();
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

  // ---- v3 ----

  @override
  Future<String> saveCapture(CaptureDraft draft) async {
    final now = DateTime.now();
    final groupId = _newId();
    final date = _formatDate(draft.date);
    // One transaction: a failure on any line (a foreign key, the unique
    // external id) rolls back the group, the earlier lines and the
    // attachments with it, so a capture is never half-saved.
    await _db.transaction(() async {
      await _db.into(_db.captureGroups).insert(CaptureGroupsCompanion.insert(
            id: groupId,
            kind: draft.kind.name,
            status: draft.status.name,
            rawText: Value(draft.rawText),
            cleanText: Value(draft.cleanText),
            parsedBy: Value(draft.parsedBy),
            date: date,
            createdAt: now,
            updatedAt: now,
          ));
      for (final line in draft.lines) {
        await _db.into(_db.entries).insert(EntriesCompanion.insert(
              id: _newId(),
              date: date,
              amountPiastres: line.amountPiastres,
              categoryKey: line.categoryKey,
              subcategoryKey: Value(line.subcategoryKey),
              itemId: Value(line.itemId),
              description: Value(line.description),
              paymentMethod: Value(draft.paymentMethod),
              source: Value(draft.kind.entrySource.name),
              note: Value(line.note),
              quantityMilli: Value(line.quantityMilli),
              unit: Value(line.unit),
              unitPricePiastres: Value(line.unitPricePiastres),
              captureGroupId: Value(groupId),
              externalId: Value(line.externalId),
              reference: Value(line.reference),
              createdAt: now,
              updatedAt: now,
            ));
        await _bumpItemUse(line.itemId, now);
      }
      for (final attachment in draft.attachments) {
        await _insertAttachment(
            captureGroupId: groupId, attachment: attachment, now: now);
      }
    });
    return groupId;
  }

  @override
  Future<CaptureGroupView?> captureGroup(String id) async {
    final group = await (_db.select(_db.captureGroups)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (group == null) return null;
    // saveCapture stamps every line (and attachment) of a capture with the
    // same createdAt, and SQLite promises no order among ties, so rowid,
    // the insertion sequence, breaks them: lines come back in the order
    // they were captured. createdAt still leads, for a line added later.
    final entries = await (_db.select(_db.entries)
          ..where((t) => t.captureGroupId.equals(id) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.rowId),
          ]))
        .get();
    final attachments = await (_db.select(_db.attachments)
          ..where((t) => t.captureGroupId.equals(id))
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.rowId),
          ]))
        .get();
    return CaptureGroupView(
      id: group.id,
      kind: CaptureKind.fromName(group.kind),
      status: CaptureStatus.fromName(group.status),
      rawText: group.rawText,
      cleanText: group.cleanText,
      parsedBy: group.parsedBy,
      date: DateTime.parse(group.date),
      entries: entries.map(_entryRecord).toList(),
      attachments: attachments.map(_attachmentView).toList(),
    );
  }

  static EntryRecord _entryRecord(Entry e) => EntryRecord(
        id: e.id,
        date: DateTime.parse(e.date),
        amountPiastres: e.amountPiastres,
        categoryKey: e.categoryKey,
        subcategoryKey: e.subcategoryKey,
        itemId: e.itemId,
        description: e.description,
        paymentMethod: e.paymentMethod,
        source: EntrySource.fromName(e.source),
        quantityMilli: e.quantityMilli,
        unit: e.unit,
        unitPricePiastres: e.unitPricePiastres,
        captureGroupId: e.captureGroupId,
        externalId: e.externalId,
        reference: e.reference,
        note: e.note,
      );

  static AttachmentView _attachmentView(Attachment a) => AttachmentView(
        id: a.id,
        entryId: a.entryId,
        captureGroupId: a.captureGroupId,
        kind: AttachmentKind.fromName(a.kind),
        path: a.path,
        text: a.body,
        transcript: a.transcript,
        durationMs: a.durationMs,
        createdAt: a.createdAt,
      );

  @override
  Future<List<AttachmentView>> attachmentsForEntry(String entryId) async {
    final entry = await (_db.select(_db.entries)
          ..where((t) => t.id.equals(entryId)))
        .getSingleOrNull();
    if (entry == null) return const [];
    final groupId = entry.captureGroupId;
    final rows = await (_db.select(_db.attachments)
          ..where((t) => groupId == null
              ? t.entryId.equals(entryId)
              : t.entryId.equals(entryId) | t.captureGroupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_attachmentView).toList();
  }

  @override
  Future<AttachmentView> addAttachment({
    String? entryId,
    String? captureGroupId,
    required DraftAttachment attachment,
  }) async {
    if (entryId == null && captureGroupId == null) {
      throw ArgumentError('an attachment needs an entry or a capture group');
    }
    return _insertAttachment(
      entryId: entryId,
      captureGroupId: captureGroupId,
      attachment: attachment,
      now: DateTime.now(),
    );
  }

  Future<AttachmentView> _insertAttachment({
    String? entryId,
    String? captureGroupId,
    required DraftAttachment attachment,
    required DateTime now,
  }) async {
    final row = AttachmentsCompanion.insert(
      id: _newId(),
      entryId: Value(entryId),
      captureGroupId: Value(captureGroupId),
      kind: attachment.kind.name,
      path: Value(attachment.path),
      body: Value(attachment.text),
      transcript: Value(attachment.transcript),
      durationMs: Value(attachment.durationMs),
      createdAt: now,
    );
    final saved = await _db.into(_db.attachments).insertReturning(row);
    return _attachmentView(saved);
  }

  @override
  Future<void> learnAlias(String alias, String itemId) async {
    await _db.into(_db.itemAliases).insertOnConflictUpdate(
          ItemAliasesCompanion.insert(
            alias: normalizeArabic(alias),
            itemId: itemId,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<Map<String, String>> itemAliases() async {
    final rows = await _db.select(_db.itemAliases).get();
    return {for (final r in rows) r.alias: r.itemId};
  }

  @override
  Future<String?> setting(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    if (isSecretSettingKey(key)) {
      throw ArgumentError.value(
          key, 'key', 'secrets belong in secure storage, not app_settings');
    }
    await _db.into(_db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value));
  }

  static RecurringBillView _billView(RecurringBill b) => RecurringBillView(
        id: b.id,
        nameAr: b.nameAr,
        amountPiastres: b.amountPiastres,
        categoryKey: b.categoryKey,
        subcategoryKey: b.subcategoryKey,
        everyMonths: b.everyMonths,
        nextDue: DateTime.parse(b.nextDue),
        remindDaysBefore: b.remindDaysBefore,
        archived: b.archived,
      );

  @override
  Future<List<RecurringBillView>> recurringBills() async {
    final rows = await (_db.select(_db.recurringBills)
          ..where((t) => t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.nextDue)]))
        .get();
    return rows.map(_billView).toList();
  }

  @override
  Future<RecurringBillView> createRecurringBill({
    required String nameAr,
    required int amountPiastres,
    required String categoryKey,
    String? subcategoryKey,
    int everyMonths = 1,
    required DateTime nextDue,
    int remindDaysBefore = 2,
  }) async {
    final row = await _db.into(_db.recurringBills).insertReturning(
          RecurringBillsCompanion.insert(
            id: _newId(),
            nameAr: nameAr,
            amountPiastres: amountPiastres,
            categoryKey: categoryKey,
            subcategoryKey: Value(subcategoryKey),
            everyMonths: Value(everyMonths),
            nextDue: _formatDate(nextDue),
            remindDaysBefore: Value(remindDaysBefore),
          ),
        );
    return _billView(row);
  }

  @override
  Future<void> updateRecurringBill(RecurringBillView bill) async {
    await (_db.update(_db.recurringBills)..where((t) => t.id.equals(bill.id)))
        .write(RecurringBillsCompanion(
      nameAr: Value(bill.nameAr),
      amountPiastres: Value(bill.amountPiastres),
      categoryKey: Value(bill.categoryKey),
      subcategoryKey: Value(bill.subcategoryKey),
      everyMonths: Value(bill.everyMonths),
      nextDue: Value(_formatDate(bill.nextDue)),
      remindDaysBefore: Value(bill.remindDaysBefore),
      archived: Value(bill.archived),
    ));
  }

  @override
  Future<void> archiveRecurringBill(String id) async {
    await (_db.update(_db.recurringBills)..where((t) => t.id.equals(id)))
        .write(const RecurringBillsCompanion(archived: Value(true)));
  }

  @override
  Future<Set<String>> knownExternalIds() async {
    final entryIds = await (_db.selectOnly(_db.entries)
          ..addColumns([_db.entries.externalId])
          ..where(_db.entries.externalId.isNotNull()))
        .map((r) => r.read(_db.entries.externalId)!)
        .get();
    final salaryIds = await (_db.selectOnly(_db.salaryPeriods)
          ..addColumns([_db.salaryPeriods.externalId])
          ..where(_db.salaryPeriods.externalId.isNotNull()))
        .map((r) => r.read(_db.salaryPeriods.externalId)!)
        .get();
    return {...entryIds, ...salaryIds};
  }
}
