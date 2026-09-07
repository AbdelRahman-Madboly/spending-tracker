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
}
