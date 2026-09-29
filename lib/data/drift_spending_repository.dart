import 'dart:async';
import 'dart:math' show exp;

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
  Stream<PeriodSummary> watchCurrentPeriod() =>
      watchPeriods().map((periods) => periods.first);

  @override
  Stream<List<PeriodSummary>> watchPeriods() {
    final periodsStream = _db.select(_db.salaryPeriods).watch();
    // asyncExpand switches to a fresh `entries` stream whenever the salary
    // periods change, but otherwise keeps forwarding entry-table updates
    // straight through — so this reacts to both tables without a second
    // stream-combining dependency.
    return periodsStream.asyncExpand((periods) {
      return _db.select(_db.entries).watch().map((allEntries) {
        return _periodsFor(periods, allEntries);
      });
    });
  }

  /// Whole calendar days from [from] to [to] (`YYYY-MM-DD` strings),
  /// counted in UTC so a daylight-saving change never shaves a day off.
  static int _daysBetween(String from, String to) {
    DateTime utc(String s) {
      final d = DateTime.parse(s);
      return DateTime.utc(d.year, d.month, d.day);
    }

    return utc(to).difference(utc(from)).inDays;
  }

  List<PeriodSummary> _periodsFor(
      List<SalaryPeriod> periods, List<Entry> entries) {
    if (periods.isEmpty) {
      return const [
        PeriodSummary(salaryPiastres: 0, spentPiastres: 0, daysRemaining: 0),
      ];
    }
    // Newest first; on the same day the later-recorded row (ids are
    // time-based) wins and the other is dropped, so a same-day correction
    // never leaves a zero-day period behind.
    final sorted = [...periods]
      ..sort((a, b) {
        final byDate = b.datePaid.compareTo(a.datePaid);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    final distinct = <SalaryPeriod>[];
    for (final p in sorted) {
      if (distinct.isEmpty || distinct.last.datePaid != p.datePaid) {
        distinct.add(p);
      }
    }
    final live = entries.where((e) => e.deletedAt == null).toList();
    int spentFrom(String start, String? endExclusive) => live
        .where((e) =>
            e.date.compareTo(start) >= 0 &&
            (endExclusive == null || e.date.compareTo(endExclusive) < 0))
        .fold(0, (sum, e) => sum + e.amountPiastres);

    final result = <PeriodSummary>[];
    for (var i = 0; i < distinct.length; i++) {
      final period = distinct[i];
      final start = DateTime.parse(period.datePaid);
      if (i == 0) {
        final length = _periodLengthDays(distinct);
        final elapsed = DateTime.now().difference(start).inDays;
        result.add(PeriodSummary(
          salaryPiastres: period.amountPiastres,
          spentPiastres: spentFrom(period.datePaid, null),
          daysRemaining: length - elapsed,
          lengthDays: length,
          start: start,
          end: DateTime(start.year, start.month, start.day + length - 1),
        ));
      } else {
        final nextStart = distinct[i - 1].datePaid;
        final next = DateTime.parse(nextStart);
        result.add(PeriodSummary(
          salaryPiastres: period.amountPiastres,
          spentPiastres: spentFrom(period.datePaid, nextStart),
          daysRemaining: 0,
          lengthDays: _daysBetween(period.datePaid, nextStart),
          start: start,
          end: DateTime(next.year, next.month, next.day - 1),
          isCurrent: false,
        ));
      }
    }
    return result;
  }

  /// Median gap (in days) between the last three salary payments, clamped
  /// to a sane 25-35 day range. Falls back to 30 when there isn't enough
  /// history yet to compute a gap.
  int _periodLengthDays(List<SalaryPeriod> sortedDesc) {
    if (sortedDesc.length < 2) return 30;
    final lastThree = sortedDesc.take(3).toList();
    final gaps = <int>[];
    for (var i = 0; i < lastThree.length - 1; i++) {
      gaps.add(_daysBetween(lastThree[i + 1].datePaid, lastThree[i].datePaid));
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
  Future<List<QuickPickItem>> recentItems(int limit) async {
    final rows = await (_db.select(_db.items)
          ..where((t) => t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.rowId)]))
        .get();
    final now = DateTime.now();
    double score(Item item) {
      final lastUsedAt = item.lastUsedAt;
      if (lastUsedAt == null) return 0;
      final days = now.difference(lastUsedAt).inHours / 24;
      return item.useCount * exp(-(days < 0 ? 0 : days) / 30);
    }

    // Index as the tie-break: List.sort is not stable, and never-used items
    // (all scoring 0) should keep catalogue order.
    final ranked = rows.indexed.toList()
      ..sort((a, b) {
        final byScore = score(b.$2).compareTo(score(a.$2));
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    final top = ranked.take(limit).map((r) => r.$2).toList();
    if (top.isEmpty) return const [];

    final lastEntries = await (_db.select(_db.entries)
          ..where((t) =>
              t.itemId.isIn(top.map((i) => i.id)) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.rowId),
          ]))
        .get();
    final lastAmount = <String, int>{};
    for (final e in lastEntries) {
      lastAmount.putIfAbsent(e.itemId!, () => e.amountPiastres);
    }
    return [
      for (final i in top)
        QuickPickItem(
          id: i.id,
          nameAr: i.nameAr,
          categoryKey: i.categoryKey,
          subcategoryKey: i.subcategoryKey,
          defaultAmountPiastres: i.defaultAmountPiastres,
          barcode: i.barcode,
          lastAmountPiastres: lastAmount[i.id],
        ),
    ];
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
      await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
              key: lastPaymentMethodSettingKey,
              value: draft.paymentMethod ?? 'Cash'));
    });
  }

  /// Counts one more use of [itemId]. [unitPricePiastres], when given,
  /// becomes the item's default price: prices drift, the latest is the best
  /// guess for the next.
  Future<void> _bumpItemUse(String? itemId, DateTime now,
      {int? unitPricePiastres}) async {
    if (itemId == null) return;
    final item = await (_db.select(_db.items)
          ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) return;
    await (_db.update(_db.items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        useCount: Value(item.useCount + 1),
        lastUsedAt: Value(now),
        defaultAmountPiastres: unitPricePiastres == null
            ? const Value.absent()
            : Value(unitPricePiastres),
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
  Future<Map<String, int>> spendByCategoryBetween(
      DateTime start, DateTime? end) async {
    final startStr = _formatDate(start);
    final endStr = end == null ? null : _formatDate(end);
    final rows = await (_db.select(_db.entries)
          ..where((t) {
            final from =
                t.date.isBiggerOrEqualValue(startStr) & t.deletedAt.isNull();
            return endStr == null
                ? from
                : from & t.date.isSmallerOrEqualValue(endStr);
          }))
        .get();
    final map = <String, int>{};
    for (final e in rows) {
      map[e.categoryKey] = (map[e.categoryKey] ?? 0) + e.amountPiastres;
    }
    return map;
  }

  @override
  Future<int> spentBetween(DateTime start, DateTime end) =>
      _spentInRange(start, end);

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
    if (draft.isDraft && draft.lines.isNotEmpty) {
      throw ArgumentError('a draft capture must not carry lines');
    }
    final now = DateTime.now();
    final draftId = draft.draftId;
    final groupId = draftId ?? _newId();
    final date = _formatDate(draft.date);
    // One transaction: a failure on any line (a foreign key, the unique
    // external id) rolls back the group, the earlier lines and the
    // attachments with it, so a capture is never half-saved.
    await _db.transaction(() async {
      final seenReferences = <String>{};
      for (final line in draft.lines) {
        final reference = line.reference;
        if (reference != null &&
            (await referenceExists(reference) ||
                !seenReferences.add(reference))) {
          throw DuplicateReferenceException(reference);
        }
      }
      if (draftId == null) {
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
      } else {
        // Only a draft can be finished: a saved capture already has its
        // entries, and writing more under it would double them.
        final updated = await (_db.update(_db.captureGroups)
              ..where((t) =>
                  t.id.equals(draftId) &
                  t.status.equals(CaptureStatus.draft.name)))
            .write(CaptureGroupsCompanion(
          status: Value(draft.status.name),
          cleanText: Value(draft.cleanText),
          parsedBy: Value(draft.parsedBy),
          date: Value(date),
          updatedAt: Value(now),
        ));
        if (updated == 0) throw StateError('$draftId is not a draft capture');
        // The raw text is what was captured and stays; a draft captured
        // with no words (a voice note nobody transcribed) takes the text
        // typed at review instead.
        final typed = draft.rawText;
        if (typed != null && typed.trim().isNotEmpty) {
          await (_db.update(_db.captureGroups)
                ..where((t) =>
                    t.id.equals(draftId) &
                    (t.rawText.isNull() | t.rawText.trim().equals(''))))
              .write(CaptureGroupsCompanion(rawText: Value(typed)));
        }
      }
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
        await _bumpItemUse(line.itemId, now,
            unitPricePiastres: capturedUnitPrice(line));
        final alias = line.aliasToLearn;
        final itemId = line.itemId;
        if (alias != null && itemId != null && normalizeArabic(alias).isNotEmpty) {
          await learnAlias(alias, itemId);
        }
      }
      for (final attachment in draft.attachments) {
        await _insertAttachment(
            captureGroupId: groupId, attachment: attachment, now: now);
      }
      if (draft.status == CaptureStatus.saved) {
        await _db.into(_db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(
                key: lastPaymentMethodSettingKey, value: draft.paymentMethod));
      }
    });
    return groupId;
  }

  @override
  Stream<List<CaptureGroupView>> watchDraftCaptures() {
    final drafts = (_db.select(_db.captureGroups)
          ..where((t) => t.status.equals(CaptureStatus.draft.name))
          // createdAt is stored in whole seconds: rowid orders two drafts
          // captured within the same second.
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.rowId),
          ]))
        .watch();
    return drafts.asyncMap((groups) async {
      final ids = groups.map((g) => g.id).toList();
      final attachments = ids.isEmpty
          ? const <Attachment>[]
          : await (_db.select(_db.attachments)
                ..where((t) => t.captureGroupId.isIn(ids))
                ..orderBy([(t) => OrderingTerm.asc(t.rowId)]))
              .get();
      return [
        for (final g in groups)
          CaptureGroupView(
            id: g.id,
            kind: CaptureKind.fromName(g.kind),
            status: CaptureStatus.fromName(g.status),
            rawText: g.rawText,
            cleanText: g.cleanText,
            parsedBy: g.parsedBy,
            date: DateTime.parse(g.date),
            entries: const [],
            attachments: [
              for (final a in attachments)
                if (a.captureGroupId == g.id) _attachmentView(a),
            ],
          ),
      ];
    });
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
  Future<bool> referenceExists(String reference) async {
    final row = await (_db.select(_db.entries)
          ..where((t) => t.reference.equals(reference) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row != null;
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

  // ---- v3: السجل, entry detail, edit and delete ----

  @override
  Stream<List<TransactionView>> watchTransactions() {
    // Same shape as [watchPeriods]: a fresh entries query whenever the
    // attachments change, otherwise entry updates flow straight through,
    // so a note added in the detail sheet shows in the row's glyphs.
    return _db.select(_db.attachments).watch().asyncExpand((attachments) {
      final byEntry = <String, List<Attachment>>{};
      final byGroup = <String, List<Attachment>>{};
      for (final a in attachments) {
        if (a.entryId case final id?) (byEntry[id] ??= []).add(a);
        if (a.captureGroupId case final id?) (byGroup[id] ??= []).add(a);
      }
      final query = _db.select(_db.entries).join([
        leftOuterJoin(_db.categories,
            _db.categories.key.equalsExp(_db.entries.categoryKey)),
        leftOuterJoin(_db.subcategories,
            _db.subcategories.key.equalsExp(_db.entries.subcategoryKey)),
        leftOuterJoin(_db.items, _db.items.id.equalsExp(_db.entries.itemId)),
      ])
        ..where(_db.entries.deletedAt.isNull())
        // Lines of one capture share createdAt; rowid keeps them in the
        // order they were captured.
        ..orderBy([
          OrderingTerm.desc(_db.entries.date),
          OrderingTerm.desc(_db.entries.createdAt),
          OrderingTerm.asc(_db.entries.rowId),
        ]);
      return query.watch().map((rows) => [
            for (final row in rows)
              _transactionView(
                row.readTable(_db.entries),
                row.readTableOrNull(_db.categories),
                row.readTableOrNull(_db.subcategories),
                row.readTableOrNull(_db.items),
                [
                  ...?byEntry[row.readTable(_db.entries).id],
                  ...?byGroup[row.readTable(_db.entries).captureGroupId],
                ],
              ),
          ]);
    });
  }

  static TransactionView _transactionView(
    Entry e,
    Category? category,
    Subcategory? subcategory,
    Item? item,
    List<Attachment> attachments,
  ) =>
      TransactionView(
        id: e.id,
        date: DateTime.parse(e.date),
        createdAt: e.createdAt,
        amountPiastres: e.amountPiastres,
        categoryKey: e.categoryKey,
        categoryLabelAr: category?.labelAr ?? e.categoryKey,
        subcategoryKey: e.subcategoryKey,
        subcategoryLabelAr: subcategory?.labelAr,
        description: e.description,
        itemNameAr: item?.nameAr,
        note: e.note,
        paymentMethod: e.paymentMethod,
        source: EntrySource.fromName(e.source),
        captureGroupId: e.captureGroupId,
        attachmentKinds: {
          for (final a in attachments) AttachmentKind.fromName(a.kind),
        },
        attachmentText: [
          for (final a in attachments) ...[?a.body, ?a.transcript],
        ],
      );

  @override
  Future<EntryRecord?> entry(String id) async {
    final row = await (_db.select(_db.entries)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _entryRecord(row);
  }

  @override
  Future<void> updateEntry(EntryRecord entry) async {
    final written = await (_db.update(_db.entries)
          ..where((t) => t.id.equals(entry.id) & t.deletedAt.isNull()))
        .write(EntriesCompanion(
      date: Value(_formatDate(entry.date)),
      amountPiastres: Value(entry.amountPiastres),
      categoryKey: Value(entry.categoryKey),
      subcategoryKey: Value(entry.subcategoryKey),
      itemId: Value(entry.itemId),
      description: Value(entry.description),
      paymentMethod: Value(entry.paymentMethod),
      quantityMilli: Value(entry.quantityMilli),
      unit: Value(entry.unit),
      unitPricePiastres: Value(entry.unitPricePiastres),
      reference: Value(entry.reference),
      note: Value(entry.note),
      updatedAt: Value(DateTime.now()),
    ));
    if (written == 0) throw StateError('no live entry ${entry.id}');
  }

  @override
  Future<void> deleteEntries(Iterable<String> ids) async {
    final now = DateTime.now();
    await (_db.update(_db.entries)
          ..where((t) => t.id.isIn(ids) & t.deletedAt.isNull()))
        .write(EntriesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  @override
  Future<void> restoreEntries(Iterable<String> ids) async {
    await (_db.update(_db.entries)..where((t) => t.id.isIn(ids))).write(
        EntriesCompanion(
            deletedAt: const Value(null), updatedAt: Value(DateTime.now())));
  }

  @override
  Future<void> recategorizeEntries(
      Iterable<String> ids, String categoryKey) async {
    await (_db.update(_db.entries)
          ..where((t) => t.id.isIn(ids) & t.deletedAt.isNull()))
        .write(EntriesCompanion(
      categoryKey: Value(categoryKey),
      subcategoryKey: const Value(null),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<String> duplicateEntry(String id, DateTime date) async {
    final source = await (_db.select(_db.entries)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    final now = DateTime.now();
    final newId = _newId();
    await _db.into(_db.entries).insert(EntriesCompanion.insert(
          id: newId,
          date: _formatDate(date),
          amountPiastres: source.amountPiastres,
          categoryKey: source.categoryKey,
          subcategoryKey: Value(source.subcategoryKey),
          itemId: Value(source.itemId),
          description: Value(source.description),
          paymentMethod: Value(source.paymentMethod),
          source: Value(source.source),
          note: Value(source.note),
          quantityMilli: Value(source.quantityMilli),
          unit: Value(source.unit),
          unitPricePiastres: Value(source.unitPricePiastres),
          createdAt: now,
          updatedAt: now,
        ));
    await _bumpItemUse(source.itemId, now);
    return newId;
  }
}
