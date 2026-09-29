import 'models.dart';

abstract class SpendingRepository {
  /// The latest salary period, updating as entries and salaries change.
  /// The same value as the first element of [watchPeriods].
  Stream<PeriodSummary> watchCurrentPeriod();

  /// Every salary period, newest (the current one) first, each with its own
  /// spend, updating as entries and salaries change. With no salary yet it
  /// is one empty current period. Two salaries on the same day make one
  /// period, the later-recorded one's.
  Stream<List<PeriodSummary>> watchPeriods();
  Stream<List<EntryView>> watchEntriesForDay(DateTime day);
  Future<List<QuickPickItem>> topItems(int limit);
  /// Saves one entry dated today and remembers its payment method under
  /// [lastPaymentMethodSettingKey] for the next add.
  Future<void> saveEntry(DraftEntry draft);

  /// Up to [limit] items for the add sheet's recent chips, ranked by
  /// `useCount × exp(−days since last use / 30)` (spec §6.1), each with its
  /// [QuickPickItem.lastAmountPiastres]. Never-used items fill any space
  /// left, in catalogue order.
  Future<List<QuickPickItem>> recentItems(int limit);
  Future<Map<String, int>> spendByCategoryForPeriod();

  /// Spend per category for the days [start] to [end], both inclusive, or
  /// from [start] on when [end] is null. Soft-deleted entries excluded.
  Future<Map<String, int>> spendByCategoryBetween(
      DateTime start, DateTime? end);

  /// Total spent from [start] to [end], both days inclusive, soft-deleted
  /// entries excluded.
  Future<int> spentBetween(DateTime start, DateTime end);
  Future<List<CategoryView>> categories();

  /// Non-archived subcategories under [categoryKey], the second level of
  /// the Category -> Subcategory -> Item structure.
  Future<List<SubcategoryView>> subcategories(String categoryKey);

  Future<List<QuickPickItem>> itemsInCategory(String categoryKey, int limit);

  /// Items tagged with [subcategoryKey], the third level of the add
  /// sheet's filter (الكل -> category -> subcategory -> item).
  Future<List<QuickPickItem>> itemsInSubcategory(
      String subcategoryKey, int limit);

  /// Throws [DuplicateBarcodeException] when [barcode] is already held by
  /// another non-archived item.
  Future<QuickPickItem> createItem({
    required String nameAr,
    required String categoryKey,
    String? subcategoryKey,
    int? defaultAmountPiastres,
    String? barcode,
  });

  /// The non-archived item previously learned for [barcode], or null if
  /// this code has never been scanned before. This is the whole offline
  /// "product database": there is nothing to look a barcode up in beyond
  /// what the user has already taught the app by creating an item for it.
  Future<QuickPickItem?> itemByBarcode(String barcode);

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

  /// Adds a brand-new category to the catalogue. [key] is generated by the
  /// caller (never typed by the user) and is permanent: it is the storage
  /// and export identity for every item and entry that will ever reference
  /// this category, so it must never change after creation.
  Future<CategoryView> createCategory({
    required String key,
    required String labelAr,
    required String iconName,
    String colorKey = 'Other',
  });

  /// Updates a category's own display row — its Arabic label and icon.
  /// [key] is never touched: renaming only ever changes [labelAr], never
  /// the storage identity that items and past entries reference.
  ///
  /// [colorKey], when given, replaces the category's colour; null keeps it.
  Future<void> updateCategory({
    required String key,
    required String labelAr,
    required String iconName,
    String? colorKey,
  });

  /// Archives a category (soft delete): it disappears from
  /// [categories], the category strip and every picker. To avoid leaving
  /// subcategories or items visible under a category the user can no
  /// longer see or select, this cascades to archive every subcategory and
  /// item currently filed under [key] as well. Past `entries` rows are
  /// never touched — they keep the exact category (and subcategory) they
  /// were saved with, forever.
  Future<void> archiveCategory(String key);

  /// Adds a brand-new subcategory under [categoryKey]. [key] is generated
  /// by the caller (never typed by the user) and, like a category's key, is
  /// permanent.
  Future<SubcategoryView> createSubcategory({
    required String key,
    required String categoryKey,
    required String labelAr,
    required String iconName,
  });

  /// Updates a subcategory's own display row — its Arabic label, icon and
  /// (optionally) which category it lives under. [key] is never touched.
  ///
  /// Moving a subcategory to a new [categoryKey] updates only the
  /// catalogue: the subcategory's own row, and any *catalogue* item
  /// currently filed under it (so the catalogue stays internally
  /// consistent — an item's category always matches its own subcategory's
  /// category). It never touches `entries`: every past entry keeps the
  /// exact `categoryKey`/`subcategoryKey` pair it was saved with, so
  /// historical spending is never silently re-categorised by a later
  /// catalogue reorganisation.
  Future<void> updateSubcategory({
    required String key,
    required String categoryKey,
    required String labelAr,
    required String iconName,
  });

  /// Archives a subcategory (soft delete): it disappears from
  /// [subcategories] and every picker. Cascades to archive every item
  /// currently filed under it, for the same reason [archiveCategory]
  /// cascades. Past `entries` rows are never touched.
  Future<void> archiveSubcategory(String key);

  /// Restores a previously archived item: it reappears in [allItems] and
  /// the quick-pick pickers. The inverse of [archiveItem].
  ///
  /// Throws [DuplicateBarcodeException] when another non-archived item has
  /// taken the item's barcode meanwhile: a scan must resolve to one item.
  Future<void> unarchiveItem(String itemId);

  /// Every archived item in the catalogue, for the settings screen's
  /// archived-items view — the only place a soft-deleted item is ever
  /// listed again, so it can be brought back with [unarchiveItem].
  Future<List<QuickPickItem>> archivedItems();

  /// Restores a previously archived category: it reappears in [categories]
  /// and every picker. Mirrors [archiveCategory]'s cascade in reverse — it
  /// also restores every subcategory and item that lives under it, so a
  /// category that was hidden along with its whole subtree comes back
  /// whole rather than leaving its children stranded in the archive. Past
  /// `entries` rows are never touched (there is nothing on them to
  /// restore: they were never archived in the first place).
  ///
  /// An item whose barcode another non-archived item now holds is skipped
  /// and stays archived with its barcode intact, so the cascade never
  /// breaks barcode uniqueness; [unarchiveItem] on it reports the clash.
  Future<void> unarchiveCategory(String key);

  /// Restores a previously archived subcategory: it reappears in
  /// [subcategories] and every picker, and cascades to restore every item
  /// filed under it — mirroring [archiveSubcategory] in reverse. Does
  /// **not** unarchive the subcategory's own category: if the category
  /// itself is still archived, the subcategory simply isn't reachable
  /// through [subcategories] until the category is unarchived too, the
  /// same way a freshly-created subcategory under an archived category
  /// would behave. Past `entries` rows are never touched. Items whose
  /// barcode is now taken stay archived, as in [unarchiveCategory].
  Future<void> unarchiveSubcategory(String key);

  /// Every archived category, for the settings screen's archived view —
  /// the only place an archived category is ever listed again, so it can
  /// be brought back with [unarchiveCategory].
  Future<List<CategoryView>> archivedCategories();

  /// Every archived subcategory (across all categories), for the settings
  /// screen's archived view, so it can be brought back with
  /// [unarchiveSubcategory].
  Future<List<SubcategoryView>> archivedSubcategories();

  // ---- v3: captures, attachments, aliases, settings, recurring bills ----

  /// Saves a whole capture atomically: the capture group, one entry per
  /// line, and the draft's attachments linked to the group. A draft
  /// ([CaptureDraft.isDraft]) with lines throws [ArgumentError]. Either all of
  /// it is written or, if anything fails (an unknown category, an import
  /// identity already present), none of it is and the error is rethrown.
  /// Returns the capture group's id.
  ///
  /// With [CaptureDraft.draftId] the capture finishes that draft group in
  /// place (spec §6.7): the draft leaves Needs review and keeps its id, raw
  /// text and attachments. Throws [StateError] when that id is not a draft.
  ///
  /// Saving lines also does what reviewing teaches (spec §6.7): each linked
  /// item's use count, last use and default price (the price of one) are
  /// updated, each [CaptureLine.aliasToLearn] is learned, and the payment
  /// method is remembered for the next add. A draft or a note teaches
  /// nothing, since nobody has checked it yet.
  ///
  /// A line whose [CaptureLine.reference] is already on a live entry, or on
  /// another line of the same capture, throws [DuplicateReferenceException]
  /// and nothing is saved (spec §6.2).
  Future<String> saveCapture(CaptureDraft draft);

  /// Whether a live (not deleted) entry holds the payment [reference].
  Future<bool> referenceExists(String reference);

  /// Draft captures (not reviewed yet), newest first, with their
  /// attachments, updating as captures are saved or reviewed. The
  /// dashboard's "needs review" section.
  Stream<List<CaptureGroupView>> watchDraftCaptures();

  /// The capture group with its entries (soft-deleted ones excluded) and
  /// its own attachments, or null if there is no such group.
  Future<CaptureGroupView?> captureGroup(String id);

  /// Attachments linked to the entry itself plus those of the capture group
  /// it was saved from, oldest first.
  Future<List<AttachmentView>> attachmentsForEntry(String entryId);

  /// Links [attachment] to an entry, a capture group, or both. Throws
  /// [ArgumentError] when neither is given.
  Future<AttachmentView> addAttachment({
    String? entryId,
    String? captureGroupId,
    required DraftAttachment attachment,
  });

  /// Remembers that [alias] (stored normalised, see `normalizeArabic`)
  /// means [itemId]. Learning an alias again re-points it.
  Future<void> learnAlias(String alias, String itemId);

  /// Every learned alias, normalised alias to item id.
  Future<Map<String, String>> itemAliases();

  /// A stored preference, or null when never set.
  Future<String?> setting(String key);

  /// Stores a preference. Throws [ArgumentError] for a key that looks like
  /// a secret (api key, token, secret, password): those belong in secure
  /// storage and must never reach the database, where exports and backups
  /// would carry them.
  Future<void> setSetting(String key, String value);

  /// Non-archived recurring bills, soonest due first.
  Future<List<RecurringBillView>> recurringBills();

  Future<RecurringBillView> createRecurringBill({
    required String nameAr,
    required int amountPiastres,
    required String categoryKey,
    String? subcategoryKey,
    int everyMonths = 1,
    required DateTime nextDue,
    int remindDaysBefore = 2,
  });

  Future<void> updateRecurringBill(RecurringBillView bill);

  Future<void> archiveRecurringBill(String id);

  /// Every import identity already present on entries and salary periods,
  /// for the importer's duplicate check.
  Future<Set<String>> knownExternalIds();

  // ---- v3: السجل, entry detail, edit and delete ----

  /// Every live (not soft-deleted) entry with the labels a row shows and
  /// the text search reads, updating as entries or attachments change.
  /// Newest day first; within a day, newest first, and the lines of one
  /// capture in the order they were captured.
  Stream<List<TransactionView>> watchTransactions();

  /// The live entry with every field, or null when there is none or it has
  /// been deleted.
  Future<EntryRecord?> entry(String id);

  /// Writes the fields the entry editor changes (date, amount, category,
  /// subcategory, item, description, payment method, quantity, unit, unit
  /// price, reference, note) and stamps `updatedAt`. The source, capture
  /// group and import identity are the entry's history and stay as saved.
  Future<void> updateEntry(EntryRecord entry);

  /// Soft-deletes [ids] (sets `deletedAt`): they drop out of every list and
  /// total, but the rows stay so [restoreEntries] can undo it.
  Future<void> deleteEntries(Iterable<String> ids);

  /// Undoes [deleteEntries] for [ids].
  Future<void> restoreEntries(Iterable<String> ids);

  /// Files [ids] under [categoryKey] (the bulk category change). Their
  /// subcategory is cleared, since a subcategory belongs to one category.
  Future<void> recategorizeEntries(Iterable<String> ids, String categoryKey);

  /// Copies the entry to [date] as a new, standalone entry (no capture
  /// group, no import identity, no attachments) and returns its id: the
  /// entry detail's "تكرار اليوم".
  Future<String> duplicateEntry(String id, DateTime date);
}
