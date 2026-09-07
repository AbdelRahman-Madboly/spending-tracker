import 'models.dart';

abstract class SpendingRepository {
  Stream<PeriodSummary> watchCurrentPeriod();
  Stream<List<EntryView>> watchEntriesForDay(DateTime day);
  Future<List<QuickPickItem>> topItems(int limit);
  Future<void> saveEntry(DraftEntry draft);
  Future<Map<String, int>> spendByCategoryForPeriod();
  Future<List<CategoryView>> categories();

  /// Non-archived subcategories under [categoryKey], the second level of
  /// the Category -> Subcategory -> Item structure.
  Future<List<SubcategoryView>> subcategories(String categoryKey);

  Future<List<QuickPickItem>> itemsInCategory(String categoryKey, int limit);

  /// Items tagged with [subcategoryKey], the third level of the add
  /// sheet's filter (الكل -> category -> subcategory -> item).
  Future<List<QuickPickItem>> itemsInSubcategory(
      String subcategoryKey, int limit);

  Future<QuickPickItem> createItem({
    required String nameAr,
    required String categoryKey,
    String? subcategoryKey,
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

  /// Totals for the last [lastNDays] calendar days, oldest first, ending
  /// today. Excludes soft-deleted entries. Days with no spending are
  /// included with a zero total rather than omitted, so a gap in a chart
  /// never gets mistaken for missing data. `label` is the day-of-month
  /// number as a Latin-digit string.
  Future<List<({String label, int totalPiastres})>> dailyTotals(int lastNDays);

  /// Totals for the last [lastNWeeks] non-overlapping 7-day windows, oldest
  /// first, ending with the 7-day window that includes today. Excludes
  /// soft-deleted entries. Weeks with no spending are included with a zero
  /// total rather than omitted. `label` is the week's start date's
  /// day-of-month number as a Latin-digit string.
  Future<List<({String label, int totalPiastres})>> weeklyTotals(
      int lastNWeeks);

  /// Records a raise or correction as a NEW `salary_periods` row dated
  /// today, rather than mutating an existing one — salary history is real
  /// data and must never be rewritten.
  Future<void> updateSalary(int amountPiastres);

  /// Every non-archived item in the catalogue, for the settings screen.
  /// Unlike [topItems]/[itemsInCategory], this is neither truncated nor
  /// reordered by usage — it lists the whole catalogue as-is.
  Future<List<QuickPickItem>> allItems();

  /// Archives an item (soft delete): it disappears from the quick-pick
  /// grid and from [allItems], but existing entries that reference it are
  /// left untouched.
  Future<void> archiveItem(String itemId);

  /// Updates an item's own catalogue row — its Arabic name, category and
  /// default price. Never touches any past entry: entries store their own
  /// snapshot amount and category at save time, independent of the item's
  /// current values.
  Future<void> updateItem({
    required String itemId,
    required String nameAr,
    required String categoryKey,
    int? defaultAmountPiastres,
  });
}
