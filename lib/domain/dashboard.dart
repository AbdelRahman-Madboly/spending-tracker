import 'models.dart';

/// Pure dashboard arithmetic (spec §4.2), kept out of the widgets so every
/// rule the home screen shows is tested without pumping a frame.

/// The budget bar's colour band (spec §7.3).
enum BudgetLevel { fine, warning, over }

/// Positive under 80% of the salary, warning from 80%, negative from 100%.
/// No salary yet ([spentPercent] null) counts as fine: there is nothing to
/// be over.
BudgetLevel budgetLevel(int? spentPercent) {
  if (spentPercent == null || spentPercent < 80) return BudgetLevel.fine;
  if (spentPercent < 100) return BudgetLevel.warning;
  return BudgetLevel.over;
}

const _arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// The Arabic month name, 1 = يناير. Written out here rather than through
/// intl's `ar` locale, which would switch the day numbers to Eastern Arabic
/// digits; every number in the app is Latin.
String arabicMonthName(int month) => _arabicMonths[month - 1];

String _dayMonth(DateTime d) => '${d.day} ${arabicMonthName(d.month)}';

/// `4 سبتمبر – 3 أكتوبر`: the salary period header.
String formatPeriodLabel(DateTime start, DateTime? end) =>
    end == null ? 'من ${_dayMonth(start)}' : '${_dayMonth(start)} – ${_dayMonth(end)}';

enum ComparisonDirection { less, more, same }

/// The month comparison line: this month so far against last month up to
/// the same day.
class MonthComparison {
  final ComparisonDirection direction;

  /// The size of the difference as a whole percent of last month.
  final int percent;

  const MonthComparison(this.direction, this.percent);

  String get sentence => switch (direction) {
        ComparisonDirection.less =>
          'أقل بـ $percent% من الشهر الماضي في نفس اليوم',
        ComparisonDirection.more =>
          'أكتر بـ $percent% من الشهر الماضي في نفس اليوم',
        ComparisonDirection.same => 'زي الشهر الماضي في نفس اليوم',
      };
}

/// Compares two same-day spends. Null when last month had nothing to
/// compare against, since any percentage of zero is meaningless.
MonthComparison? compareToLastMonth(int thisPiastres, int lastPiastres) {
  if (lastPiastres <= 0) return null;
  final diff = thisPiastres - lastPiastres;
  // Rounded half up, in integers.
  final percent = (diff.abs() * 200 + lastPiastres) ~/ (lastPiastres * 2);
  if (percent == 0) return const MonthComparison(ComparisonDirection.same, 0);
  return MonthComparison(
    diff < 0 ? ComparisonDirection.less : ComparisonDirection.more,
    percent,
  );
}

/// The next [limit] non-archived bills due within [withinDays] of [today],
/// soonest first. An overdue bill stays in the list: it is the one that most
/// needs paying.
List<RecurringBillView> upcomingBills(
  List<RecurringBillView> bills,
  DateTime today, {
  int withinDays = 10,
  int limit = 3,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final horizon = day.add(Duration(days: withinDays));
  final due = bills
      .where((b) => !b.archived && !b.nextDue.isAfter(horizon))
      .toList()
    ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  return due.take(limit).toList();
}

/// One row of the dashboard's top categories.
class CategoryShare {
  final String categoryKey;
  final int amountPiastres;

  /// Whole percent of the total, rounded half up.
  final int percent;

  const CategoryShare(this.categoryKey, this.amountPiastres, this.percent);
}

/// The [limit] biggest categories with their share of the whole spend
/// (every category, not only the ones shown).
List<CategoryShare> topCategoryShares(Map<String, int> byCategory,
    {int limit = 5}) {
  final rows = byCategory.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = rows.fold<int>(0, (sum, e) => sum + e.value);
  return [
    for (final row in rows.take(limit))
      CategoryShare(
          row.key, row.value, (row.value * 200 + total) ~/ (total * 2)),
  ];
}
