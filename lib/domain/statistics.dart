import 'package:equatable/equatable.dart';

import 'dashboard.dart';
import 'models.dart';

/// Pure statistics arithmetic (spec §4.5): calendar months, the selected
/// month's donut, and the month history. Everything is worked out from the
/// live transaction list, so the screen follows every save, edit and delete
/// without a query of its own.

/// A calendar month. Statistics run on calendar months, not salary
/// periods: a month is what the history lists and what السجل opens on.
class YearMonth extends Equatable implements Comparable<YearMonth> {
  final int year;

  /// 1 to 12.
  final int month;

  const YearMonth(this.year, this.month);

  factory YearMonth.of(DateTime moment) => YearMonth(moment.year, moment.month);

  DateTime get firstDay => DateTime(year, month);

  /// Day 0 of the next month is this month's last day.
  DateTime get lastDay => DateTime(year, month + 1, 0);

  YearMonth get previous => YearMonth.of(DateTime(year, month - 1));
  YearMonth get next => YearMonth.of(DateTime(year, month + 1));

  bool contains(DateTime day) => day.year == year && day.month == month;

  /// `سبتمبر 2026`, Latin digits like every number in the app.
  String get label => '${arabicMonthName(month)} $year';

  /// `2026-09`, for keys.
  String get iso => '$year-${month.toString().padLeft(2, '0')}';

  @override
  int compareTo(YearMonth other) =>
      year != other.year ? year - other.year : month - other.month;

  bool operator <(YearMonth other) => compareTo(other) < 0;

  @override
  List<Object?> get props => [year, month];
}

/// Spend per category over [month]'s entries.
Map<String, int> spendByCategoryInMonth(
  Iterable<TransactionView> entries,
  YearMonth month,
) {
  final totals = <String, int>{};
  for (final e in entries) {
    if (!month.contains(e.date)) continue;
    totals[e.categoryKey] = (totals[e.categoryKey] ?? 0) + e.amountPiastres;
  }
  return totals;
}

/// [categoryKey]'s spend in [month] by subcategory: the donut's drill-down.
/// Entries filed under the category alone sum under the `null` key. The
/// label is the one the entries carry, so an archived subcategory still
/// shows its name.
Map<String?, ({String? label, int amountPiastres})> spendBySubcategoryInMonth(
  Iterable<TransactionView> entries,
  YearMonth month,
  String categoryKey,
) {
  final totals = <String?, ({String? label, int amountPiastres})>{};
  for (final e in entries) {
    if (e.categoryKey != categoryKey || !month.contains(e.date)) continue;
    final key = e.subcategoryKey;
    final sum = totals[key]?.amountPiastres ?? 0;
    totals[key] = (
      label: totals[key]?.label ?? e.subcategoryLabelAr,
      amountPiastres: sum + e.amountPiastres,
    );
  }
  return totals;
}

/// One slice of the donut.
class DonutSlice {
  /// The category (or subcategory) key; empty for the merged "أخرى".
  final String key;
  final int amountPiastres;

  /// Whole percent of the month, rounded half up.
  final int percent;

  /// For the "أخرى" slice, the keys merged into it, biggest first.
  final List<String> mergedKeys;

  const DonutSlice({
    required this.key,
    required this.amountPiastres,
    required this.percent,
    this.mergedKeys = const [],
  });

  bool get isOther => mergedKeys.isNotEmpty;
}

/// The donut holds at most this many slices (spec §4.5). More than six
/// thin slices stop being readable as proportions.
const maxDonutSlices = 6;

/// [amounts] as donut slices, biggest first (ties by key, so the order
/// never flickers between rebuilds). Past [maxDonutSlices], the first five
/// stay and the rest merge into one "أخرى" slice, so there are never more
/// than six. Zero amounts are dropped.
List<DonutSlice> donutSlices(Map<String, int> amounts) {
  final rows = amounts.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) {
      final byAmount = b.value.compareTo(a.value);
      return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
    });
  if (rows.isEmpty) return const [];
  final total = rows.fold<int>(0, (sum, e) => sum + e.value);
  int percentOf(int amount) => (amount * 200 + total) ~/ (total * 2);

  final kept = rows.length > maxDonutSlices
      ? rows.take(maxDonutSlices - 1).toList()
      : rows;
  final rest = rows.skip(kept.length).toList();
  final restTotal = rest.fold<int>(0, (sum, e) => sum + e.value);
  return [
    for (final row in kept)
      DonutSlice(
        key: row.key,
        amountPiastres: row.value,
        percent: percentOf(row.value),
      ),
    if (rest.isNotEmpty)
      DonutSlice(
        key: '',
        amountPiastres: restTotal,
        percent: percentOf(restTotal),
        mergedKeys: [for (final r in rest) r.key],
      ),
  ];
}

/// One row of the month history.
class MonthHistoryRow {
  final YearMonth month;
  final int totalPiastres;

  /// Against the calendar month before; null when that month had nothing,
  /// since a change against zero has no meaningful percent.
  final MonthComparison? change;

  /// Up to three biggest categories, biggest first.
  final List<String> topCategoryKeys;

  const MonthHistoryRow({
    required this.month,
    required this.totalPiastres,
    required this.change,
    required this.topCategoryKeys,
  });
}

/// Every month with spending, newest first (spec §4.5).
List<MonthHistoryRow> monthHistory(Iterable<TransactionView> entries) {
  final byMonth = <YearMonth, Map<String, int>>{};
  for (final e in entries) {
    final perCategory = byMonth[YearMonth.of(e.date)] ??= {};
    perCategory[e.categoryKey] =
        (perCategory[e.categoryKey] ?? 0) + e.amountPiastres;
  }
  final totals = {
    for (final MapEntry(key: month, value: perCategory) in byMonth.entries)
      month: perCategory.values.fold<int>(0, (sum, v) => sum + v),
  };
  final months = totals.keys.where((m) => totals[m]! > 0).toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    for (final month in months)
      MonthHistoryRow(
        month: month,
        totalPiastres: totals[month]!,
        change: compareToLastMonth(totals[month]!, totals[month.previous] ?? 0),
        topCategoryKeys: [
          for (final s in donutSlices(byMonth[month]!).take(3))
            if (!s.isOther) s.key,
        ],
      ),
  ];
}
