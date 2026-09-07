import 'models.dart';

abstract class SpendingRepository {
  Stream<PeriodSummary> watchCurrentPeriod();
  Stream<List<EntryView>> watchEntriesForDay(DateTime day);
  Future<List<QuickPickItem>> topItems(int limit);
  Future<void> saveEntry(DraftEntry draft);
  Future<Map<String, int>> spendByCategoryForPeriod();
  Future<List<CategoryView>> categories();
  Future<List<QuickPickItem>> itemsInCategory(String categoryKey, int limit);
  Future<QuickPickItem> createItem({
    required String nameAr,
    required String categoryKey,
    int? defaultAmountPiastres,
    String? barcode,
  });

  /// Total spent in the given calendar month (1-12), excluding soft-deleted
  /// entries.
  Future<int> spentInMonth(int year, int month);

  /// Totals for the last [lastNMonths] calendar months, oldest first,
  /// ending with the current month. `yearMonth` is formatted `YYYY-MM`.
  /// Months with no spending are included with a zero total rather than
  /// omitted, so a gap in a chart never gets mistaken for missing data.
  Future<List<({String yearMonth, int totalPiastres})>> monthlyTotals(
      int lastNMonths);
}
