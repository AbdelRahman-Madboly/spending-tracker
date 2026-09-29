import 'dart:async';

import '../core/arabic_text.dart';
import '../domain/bills.dart';
import '../domain/models.dart';
import '../domain/spending_repository.dart';

/// Mirrors the ten categories seeded into the real database
/// (see `lib/data/db/database.dart`) so widget tests exercise the same
/// category set the app ships with.
final _seedCategories = [
  const CategoryView(
      key: 'Drinks',
      labelAr: 'مشروبات',
      iconName: 'local_drink',
      colorKey: 'Drinks'),
  const CategoryView(
      key: 'Snacks',
      labelAr: 'سناكس',
      iconName: 'cookie',
      colorKey: 'Snacks'),
  const CategoryView(
      key: 'Food',
      labelAr: 'أكل',
      iconName: 'restaurant',
      colorKey: 'Food'),
  const CategoryView(
      key: 'Transport',
      labelAr: 'مواصلات',
      iconName: 'directions_bus',
      colorKey: 'Transport'),
  const CategoryView(
      key: 'Bills',
      labelAr: 'فواتير',
      iconName: 'receipt_long',
      colorKey: 'Bills'),
  const CategoryView(
      key: 'Personal Care',
      labelAr: 'عناية شخصية',
      iconName: 'content_cut',
      colorKey: 'Personal Care'),
  const CategoryView(
      key: 'Shopping',
      labelAr: 'تسوق',
      iconName: 'shopping_bag',
      colorKey: 'Shopping'),
  const CategoryView(
      key: 'Family/Social',
      labelAr: 'عائلة وزيارات',
      iconName: 'groups',
      colorKey: 'Family/Social'),
  const CategoryView(
      key: 'Gifts',
      labelAr: 'هدايا',
      iconName: 'card_giftcard',
      colorKey: 'Gifts'),
  const CategoryView(
      key: 'Loans',
      labelAr: 'سلف',
      iconName: 'handshake',
      colorKey: 'Loans'),
];

/// Mirrors the subcategory catalogue seeded into the real database (see
/// `lib/data/db/database.dart`'s `_seedSubcategoryRows`), so widget tests
/// exercise the same Category -> Subcategory structure the app ships with.
final _seedSubcategories = [
  const SubcategoryView(
      key: 'Soda',
      categoryKey: 'Drinks',
      labelAr: 'صودا',
      iconName: 'local_bar'),
  const SubcategoryView(
      key: 'Water',
      categoryKey: 'Drinks',
      labelAr: 'مياه',
      iconName: 'water_drop'),
  const SubcategoryView(
      key: 'Milk',
      categoryKey: 'Drinks',
      labelAr: 'لبن',
      iconName: 'local_drink'),
  const SubcategoryView(
      key: 'Juice',
      categoryKey: 'Drinks',
      labelAr: 'عصير',
      iconName: 'emoji_food_beverage'),
  const SubcategoryView(
      key: 'HotDrinks',
      categoryKey: 'Drinks',
      labelAr: 'مشروبات ساخنة',
      iconName: 'local_cafe'),
  const SubcategoryView(
      key: 'Chips', categoryKey: 'Snacks', labelAr: 'شيبسي', iconName: 'tapas'),
  const SubcategoryView(
      key: 'Chocolate',
      categoryKey: 'Snacks',
      labelAr: 'شوكولاتة',
      iconName: 'cake'),
  const SubcategoryView(
      key: 'Biscuits',
      categoryKey: 'Snacks',
      labelAr: 'بسكوت',
      iconName: 'cookie'),
  const SubcategoryView(
      key: 'Sweets',
      categoryKey: 'Snacks',
      labelAr: 'حلويات',
      iconName: 'icecream'),
  const SubcategoryView(
      key: 'FastFood',
      categoryKey: 'Snacks',
      labelAr: 'وجبات سريعة',
      iconName: 'fastfood'),
  const SubcategoryView(
      key: 'Breakfast',
      categoryKey: 'Food',
      labelAr: 'فطار',
      iconName: 'free_breakfast'),
  const SubcategoryView(
      key: 'Lunch',
      categoryKey: 'Food',
      labelAr: 'غدا',
      iconName: 'lunch_dining'),
  const SubcategoryView(
      key: 'Dinner',
      categoryKey: 'Food',
      labelAr: 'عشا',
      iconName: 'dinner_dining'),
  const SubcategoryView(
      key: 'Groceries',
      categoryKey: 'Food',
      labelAr: 'بقالة',
      iconName: 'local_grocery_store'),
  const SubcategoryView(
      key: 'PublicTransport',
      categoryKey: 'Transport',
      labelAr: 'مواصلات عامة',
      iconName: 'directions_bus'),
  const SubcategoryView(
      key: 'Taxi',
      categoryKey: 'Transport',
      labelAr: 'تاكسي',
      iconName: 'local_taxi'),
  const SubcategoryView(
      key: 'PhoneBill',
      categoryKey: 'Bills',
      labelAr: 'فاتورة موبايل',
      iconName: 'smartphone'),
  const SubcategoryView(
      key: 'HomeInternet',
      categoryKey: 'Bills',
      labelAr: 'إنترنت المنزل',
      iconName: 'wifi'),
  const SubcategoryView(
      key: 'Haircut',
      categoryKey: 'Personal Care',
      labelAr: 'حلاقة',
      iconName: 'content_cut'),
  const SubcategoryView(
      key: 'Cosmetics',
      categoryKey: 'Personal Care',
      labelAr: 'مستحضرات',
      iconName: 'spa'),
  const SubcategoryView(
      key: 'Clothes',
      categoryKey: 'Shopping',
      labelAr: 'ملابس',
      iconName: 'checkroom'),
  const SubcategoryView(
      key: 'Electronics',
      categoryKey: 'Shopping',
      labelAr: 'إلكترونيات',
      iconName: 'devices'),
  const SubcategoryView(
      key: 'OnlineShopping',
      categoryKey: 'Shopping',
      labelAr: 'تسوق أونلاين',
      iconName: 'shopping_cart'),
  const SubcategoryView(
      key: 'Trips',
      categoryKey: 'Family/Social',
      labelAr: 'رحلات',
      iconName: 'flight'),
  const SubcategoryView(
      key: 'Visits',
      categoryKey: 'Family/Social',
      labelAr: 'زيارات',
      iconName: 'people'),
  const SubcategoryView(
      key: 'Gifts',
      categoryKey: 'Gifts',
      labelAr: 'هدايا',
      iconName: 'card_giftcard'),
  const SubcategoryView(
      key: 'Loans',
      categoryKey: 'Loans',
      labelAr: 'سلف',
      iconName: 'handshake'),
];

class FixtureSpendingRepository implements SpendingRepository {
  static const _defaultSalary = 900000;
  static const _today = 6;

  final _entries = <EntryView>[
    EntryView(
      id: '1',
      displayName: 'لبن',
      amountPiastres: 3500,
      categoryKey: 'Food',
      categoryLabelAr: 'أكل',
      date: DateTime(2026, 9, 6),
    ),
    EntryView(
      id: '2',
      displayName: 'إندومي',
      amountPiastres: 1000,
      categoryKey: 'Food',
      categoryLabelAr: 'أكل',
      date: DateTime(2026, 9, 5),
    ),
    EntryView(
      id: '3',
      displayName: 'شويبس',
      amountPiastres: 4000,
      categoryKey: 'Drinks',
      categoryLabelAr: 'مشروبات',
      date: DateTime(2026, 9, 5),
    ),
  ];

  final _items = <QuickPickItem>[
    const QuickPickItem(
        id: 'i1',
        nameAr: 'شويبس',
        categoryKey: 'Drinks',
        subcategoryKey: 'Soda',
        defaultAmountPiastres: 4000),
    const QuickPickItem(
        id: 'i2',
        nameAr: 'إندومي',
        categoryKey: 'Food',
        defaultAmountPiastres: 1000),
    const QuickPickItem(
        id: 'i3',
        nameAr: 'لبن',
        categoryKey: 'Food',
        defaultAmountPiastres: 3500),
    const QuickPickItem(
        id: 'i4',
        nameAr: 'تاكسي',
        categoryKey: 'Transport',
        defaultAmountPiastres: 3500),
    const QuickPickItem(
        id: 'i5',
        nameAr: 'مخبز',
        categoryKey: 'Food',
        defaultAmountPiastres: 2500),
    const QuickPickItem(
        id: 'i6',
        nameAr: 'شيبسي',
        categoryKey: 'Snacks',
        defaultAmountPiastres: 1000),
    const QuickPickItem(
        id: 'i7',
        nameAr: 'فطار',
        categoryKey: 'Food',
        defaultAmountPiastres: 1500),
    const QuickPickItem(
        id: 'i8',
        nameAr: 'مواصلات',
        categoryKey: 'Transport',
        defaultAmountPiastres: 700),
    const QuickPickItem(
        id: 'i9',
        nameAr: 'عصير',
        categoryKey: 'Drinks',
        subcategoryKey: 'Juice',
        defaultAmountPiastres: 2000),
    const QuickPickItem(
        id: 'i10',
        nameAr: 'حلاقة',
        categoryKey: 'Personal Care',
        defaultAmountPiastres: 10000),
    const QuickPickItem(
        id: 'i11',
        nameAr: 'شحن رصيد',
        categoryKey: 'Bills',
        defaultAmountPiastres: 10000),
    const QuickPickItem(
        id: 'i12',
        nameAr: 'شوكولاتة',
        categoryKey: 'Snacks',
        defaultAmountPiastres: 500),
  ];

  // Instance copies of the module-level seed lists: every
  // `FixtureSpendingRepository()` must start from a clean, independent
  // catalogue. Reading/writing the module-level lists directly would leak
  // mutations (a rename, an added category, ...) from one instance into
  // every other instance created afterwards in the same isolate — most
  // visibly across widget tests, each of which constructs its own fixture
  // expecting a pristine catalogue.
  final _categories = List<CategoryView>.of(_seedCategories);
  final _subcategories = List<SubcategoryView>.of(_seedSubcategories);

  final _controller = StreamController<void>.broadcast();
  final _archivedItemIds = <String>{};
  final _archivedCategoryKeys = <String>{};
  final _archivedSubcategoryKeys = <String>{};
  int _salary = _defaultSalary;

  int get _spent => _entries.fold(0, (sum, e) => sum + e.amountPiastres);

  @override
  Stream<PeriodSummary> watchCurrentPeriod() async* {
    yield _summary();
    yield* _controller.stream.map((_) => _summary());
  }

  PeriodSummary _summary() => PeriodSummary(
        salaryPiastres: _salary,
        spentPiastres: _spent,
        daysRemaining: 28,
        lengthDays: 30,
        start: DateTime(2026, 9, 4),
        end: DateTime(2026, 10, 3),
      );

  /// The period before the current one, so the dashboard's period switcher
  /// has somewhere to go. Every fixture entry falls in the current period,
  /// so its spend is whatever was added with a date before 4 September.
  PeriodSummary _previousSummary() {
    final start = DateTime(2026, 8, 4);
    final end = DateTime(2026, 9, 3);
    return PeriodSummary(
      salaryPiastres: _defaultSalary,
      spentPiastres: _spentInRange(start, end),
      daysRemaining: 0,
      lengthDays: 31,
      start: start,
      end: end,
      isCurrent: false,
    );
  }

  @override
  Stream<List<PeriodSummary>> watchPeriods() async* {
    List<PeriodSummary> all() => [_summary(), _previousSummary()];
    yield all();
    yield* _controller.stream.map((_) => all());
  }

  @override
  Future<void> updateSalary(int amountPiastres) async {
    _salary = amountPiastres;
    _controller.add(null);
  }

  /// Import identities of the salaries [addSalaryPeriod] recorded.
  final _salaryExternalIds = <String>{};

  /// The fixture keeps one salary figure, so a recorded salary becomes it,
  /// as the latest salary becomes the current period's in the database.
  @override
  Future<void> addSalaryPeriod({
    required DateTime datePaid,
    required int amountPiastres,
    String? note,
    String? evidencePhotoPath,
    String? externalId,
  }) async {
    if (externalId != null) {
      if ((await knownExternalIds()).contains(externalId)) {
        throw StateError('external id $externalId already exists');
      }
      _salaryExternalIds.add(externalId);
    }
    _salary = amountPiastres;
    _controller.add(null);
  }

  @override
  Future<List<QuickPickItem>> allItems() async =>
      _items.where((i) => !_archivedItemIds.contains(i.id)).toList();

  @override
  Future<void> archiveItem(String itemId) async {
    _archivedItemIds.add(itemId);
    _controller.add(null);
  }

  @override
  Future<void> updateItem({
    required String itemId,
    required String nameAr,
    required String categoryKey,
    int? defaultAmountPiastres,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    _items[index] = QuickPickItem(
      id: itemId,
      nameAr: nameAr,
      categoryKey: categoryKey,
      defaultAmountPiastres: defaultAmountPiastres,
    );
    _controller.add(null);
  }

  @override
  Future<void> updateProduct({
    required String itemId,
    required String nameAr,
    required String categoryKey,
    String? subcategoryKey,
    int? defaultAmountPiastres,
    String? barcode,
  }) async {
    if (barcode != null) {
      final holder = await itemByBarcode(barcode);
      if (holder != null && holder.id != itemId) {
        throw DuplicateBarcodeException(barcode);
      }
    }
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    _items[index] = QuickPickItem(
      id: itemId,
      nameAr: nameAr,
      categoryKey: categoryKey,
      subcategoryKey: subcategoryKey,
      defaultAmountPiastres: defaultAmountPiastres,
      barcode: barcode,
    );
    _controller.add(null);
  }

  @override
  Future<List<ItemPrice>> itemPriceHistory(String itemId) async {
    final records = [
      for (final (i, v) in _entries.indexed)
        if (_recordOf(v) case final r when r.itemId == itemId) (i, r),
    ]..sort((a, b) {
        final byDate = b.$2.date.compareTo(a.$2.date);
        return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
      });
    return [
      for (final (_, r) in records)
        ItemPrice(
          date: DateTime(r.date.year, r.date.month, r.date.day),
          amountPiastres: r.amountPiastres,
          quantityMilli: r.quantityMilli,
          unitPricePiastres: unitPriceOf(
            amountPiastres: r.amountPiastres,
            quantityMilli: r.quantityMilli,
            unitPricePiastres: r.unitPricePiastres,
          ),
        ),
    ];
  }

  @override
  Stream<List<EntryView>> watchEntriesForDay(DateTime day) async* {
    List<EntryView> forDay() => _entries
        .where((e) =>
            e.date.year == day.year &&
            e.date.month == day.month &&
            e.date.day == day.day)
        .toList();
    yield forDay();
    yield* _controller.stream.map((_) => forDay());
  }

  /// Uses per item id, and the amount of each item's latest entry: the
  /// fixture's stand-in for `items.useCount` and the entries table, for
  /// [recentItems].
  final _useCounts = <String, int>{};
  final _lastAmounts = <String, int>{};

  /// The price of one of each item's latest entry, for [itemByBarcode]
  /// (the drift repository works it out from the entry's quantity).
  final _lastUnitPrices = <String, int>{};

  void _recordUse(String? itemId, int amountPiastres,
      {int? quantityMilli, int? unitPricePiastres}) {
    if (itemId == null) return;
    _useCounts[itemId] = (_useCounts[itemId] ?? 0) + 1;
    _lastAmounts[itemId] = amountPiastres;
    _lastUnitPrices[itemId] = unitPriceOf(
      amountPiastres: amountPiastres,
      quantityMilli: quantityMilli,
      unitPricePiastres: unitPricePiastres,
    );
  }

  /// Ranked by use count alone: the fixture has no clock to decay by.
  /// Ties keep catalogue order.
  @override
  Future<List<QuickPickItem>> recentItems(int limit) async {
    final live = _items.where((i) => !_archivedItemIds.contains(i.id)).indexed
        .toList()
      ..sort((a, b) {
        final byUse =
            (_useCounts[b.$2.id] ?? 0).compareTo(_useCounts[a.$2.id] ?? 0);
        return byUse != 0 ? byUse : a.$1.compareTo(b.$1);
      });
    return [
      for (final (_, i) in live.take(limit))
        QuickPickItem(
          id: i.id,
          nameAr: i.nameAr,
          categoryKey: i.categoryKey,
          subcategoryKey: i.subcategoryKey,
          defaultAmountPiastres: i.defaultAmountPiastres,
          barcode: i.barcode,
          lastAmountPiastres: _lastAmounts[i.id],
        ),
    ];
  }

  @override
  Future<List<QuickPickItem>> topItems(int limit) async => _items
      .where((i) => !_archivedItemIds.contains(i.id))
      .take(limit)
      .toList();

  @override
  Future<List<CategoryView>> categories() async => _categories
      .where((c) => !_archivedCategoryKeys.contains(c.key))
      .toList();

  @override
  Future<List<SubcategoryView>> subcategories(String categoryKey) async =>
      _subcategories
          .where((s) =>
              s.categoryKey == categoryKey &&
              !_archivedSubcategoryKeys.contains(s.key))
          .toList();

  @override
  Future<CategoryView> createCategory({
    required String key,
    required String labelAr,
    required String iconName,
    String colorKey = 'Other',
  }) async {
    final category = CategoryView(
        key: key, labelAr: labelAr, iconName: iconName, colorKey: colorKey);
    _categories.add(category);
    _controller.add(null);
    return category;
  }

  @override
  Future<void> updateCategory({
    required String key,
    required String labelAr,
    required String iconName,
    String? colorKey,
  }) async {
    final index = _categories.indexWhere((c) => c.key == key);
    if (index == -1) return;
    _categories[index] = CategoryView(
        key: key,
        labelAr: labelAr,
        iconName: iconName,
        colorKey: colorKey ?? _categories[index].colorKey);
    _controller.add(null);
  }

  @override
  Future<void> archiveCategory(String key) async {
    _archivedCategoryKeys.add(key);
    // Cascade: hide every subcategory and item that lives under this
    // category too, so nothing stays visible under a category the user can
    // no longer see or pick. Past entries are untouched — they aren't
    // stored in these catalogue lists at all.
    for (final sub in _subcategories.where((s) => s.categoryKey == key)) {
      _archivedSubcategoryKeys.add(sub.key);
    }
    for (final item in _items.where((i) => i.categoryKey == key)) {
      _archivedItemIds.add(item.id);
    }
    _controller.add(null);
  }

  @override
  Future<SubcategoryView> createSubcategory({
    required String key,
    required String categoryKey,
    required String labelAr,
    required String iconName,
  }) async {
    final subcategory = SubcategoryView(
      key: key,
      categoryKey: categoryKey,
      labelAr: labelAr,
      iconName: iconName,
    );
    _subcategories.add(subcategory);
    _controller.add(null);
    return subcategory;
  }

  @override
  Future<void> updateSubcategory({
    required String key,
    required String categoryKey,
    required String labelAr,
    required String iconName,
  }) async {
    final index = _subcategories.indexWhere((s) => s.key == key);
    if (index == -1) return;
    _subcategories[index] = SubcategoryView(
      key: key,
      categoryKey: categoryKey,
      labelAr: labelAr,
      iconName: iconName,
    );
    // Moving to a new category keeps the catalogue internally consistent:
    // any catalogue item filed under this subcategory follows it to the
    // new category. Past entries are never touched — they aren't stored in
    // these catalogue lists at all.
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].subcategoryKey == key) {
        _items[i] = QuickPickItem(
          id: _items[i].id,
          nameAr: _items[i].nameAr,
          categoryKey: categoryKey,
          subcategoryKey: _items[i].subcategoryKey,
          defaultAmountPiastres: _items[i].defaultAmountPiastres,
        );
      }
    }
    _controller.add(null);
  }

  @override
  Future<void> archiveSubcategory(String key) async {
    _archivedSubcategoryKeys.add(key);
    for (final item in _items.where((i) => i.subcategoryKey == key)) {
      _archivedItemIds.add(item.id);
    }
    _controller.add(null);
  }

  @override
  Future<void> unarchiveItem(String itemId) async {
    final barcode = _items.where((i) => i.id == itemId).firstOrNull?.barcode;
    if (barcode != null) {
      final holder = await itemByBarcode(barcode);
      if (holder != null && holder.id != itemId) {
        throw DuplicateBarcodeException(barcode);
      }
    }
    _archivedItemIds.remove(itemId);
    _controller.add(null);
  }

  /// Mirrors the drift repository's cascade restore: an item whose barcode
  /// a non-archived item now holds stays archived, untouched, and of two
  /// archived items sharing a barcode the first in id order comes back.
  Future<void> _restoreItemsWhere(bool Function(QuickPickItem) where) async {
    final candidates = _items
        .where((i) => _archivedItemIds.contains(i.id) && where(i))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final item in candidates) {
      final barcode = item.barcode;
      if (barcode != null && await itemByBarcode(barcode) != null) continue;
      _archivedItemIds.remove(item.id);
    }
  }

  @override
  Future<List<QuickPickItem>> archivedItems() async =>
      _items.where((i) => _archivedItemIds.contains(i.id)).toList();

  @override
  Future<void> unarchiveCategory(String key) async {
    _archivedCategoryKeys.remove(key);
    // Mirror archiveCategory's cascade in reverse: bring back every
    // subcategory and item that lives under this category.
    for (final sub in _subcategories.where((s) => s.categoryKey == key)) {
      _archivedSubcategoryKeys.remove(sub.key);
    }
    await _restoreItemsWhere((i) => i.categoryKey == key);
    _controller.add(null);
  }

  @override
  Future<void> unarchiveSubcategory(String key) async {
    _archivedSubcategoryKeys.remove(key);
    await _restoreItemsWhere((i) => i.subcategoryKey == key);
    // Deliberately does NOT touch the subcategory's own category: this
    // must never cascade upward and resurrect a category the user
    // archived on purpose.
    _controller.add(null);
  }

  @override
  Future<List<CategoryView>> archivedCategories() async => _categories
      .where((c) => _archivedCategoryKeys.contains(c.key))
      .toList();

  @override
  Future<List<SubcategoryView>> archivedSubcategories() async =>
      _subcategories
          .where((s) => _archivedSubcategoryKeys.contains(s.key))
          .toList();

  @override
  Future<List<QuickPickItem>> itemsInCategory(
          String categoryKey, int limit) async =>
      _items
          .where((i) =>
              i.categoryKey == categoryKey && !_archivedItemIds.contains(i.id))
          .take(limit)
          .toList();

  @override
  Future<List<QuickPickItem>> itemsInSubcategory(
          String subcategoryKey, int limit) async =>
      _items
          .where((i) =>
              i.subcategoryKey == subcategoryKey &&
              !_archivedItemIds.contains(i.id))
          .take(limit)
          .toList();

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
    final item = QuickPickItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nameAr: nameAr,
      categoryKey: categoryKey,
      subcategoryKey: subcategoryKey,
      defaultAmountPiastres: defaultAmountPiastres,
      barcode: barcode,
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<QuickPickItem?> itemByBarcode(String barcode) async {
    for (final i in _items) {
      if (i.barcode == barcode && !_archivedItemIds.contains(i.id)) {
        return QuickPickItem(
          id: i.id,
          nameAr: i.nameAr,
          categoryKey: i.categoryKey,
          subcategoryKey: i.subcategoryKey,
          defaultAmountPiastres: i.defaultAmountPiastres,
          barcode: i.barcode,
          lastAmountPiastres: _lastUnitPrices[i.id],
        );
      }
    }
    return null;
  }

  /// Mirrors the drift repository's barcode learning in [saveCapture].
  Future<String?> _learnBarcode(CaptureLine line) async {
    final barcode = line.barcode;
    final linked = line.itemId;
    if (barcode == null || barcode.isEmpty) return linked;
    final holder = await itemByBarcode(barcode);
    if (linked != null) {
      final index = _items.indexWhere((i) => i.id == linked);
      if (holder == null && index != -1 && _items[index].barcode == null) {
        final i = _items[index];
        _items[index] = QuickPickItem(
          id: i.id,
          nameAr: i.nameAr,
          categoryKey: i.categoryKey,
          subcategoryKey: i.subcategoryKey,
          defaultAmountPiastres: i.defaultAmountPiastres,
          barcode: barcode,
        );
      }
      return linked;
    }
    if (holder != null) return holder.id;
    final name = line.description.trim();
    if (name.isEmpty) return null;
    final item = await createItem(
      nameAr: name,
      categoryKey: line.categoryKey,
      subcategoryKey: line.subcategoryKey,
      defaultAmountPiastres: capturedUnitPrice(line),
      barcode: barcode,
    );
    return item.id;
  }

  @override
  Future<void> saveEntry(DraftEntry draft) async {
    final categoryKey = draft.categoryKey ?? 'Food';
    final categoryLabelAr = _categories
        .firstWhere((c) => c.key == categoryKey,
            orElse: () => _categories.first)
        .labelAr;
    final id = _newId();
    _entries.add(EntryView(
      id: id,
      displayName: draft.description ?? '',
      amountPiastres: draft.amountPiastres ?? 0,
      categoryKey: categoryKey,
      categoryLabelAr: categoryLabelAr,
      date: DateTime(2026, 9, _today),
    ));
    _records[id] = EntryRecord(
      id: id,
      date: DateTime(2026, 9, _today),
      amountPiastres: draft.amountPiastres ?? 0,
      categoryKey: categoryKey,
      subcategoryKey: draft.subcategoryKey,
      itemId: draft.itemId,
      description: draft.description ?? '',
      paymentMethod: draft.paymentMethod ?? 'Cash',
      source: draft.source,
    );
    _createdAt[id] = DateTime.now();
    final photoPath = draft.photoPath;
    if (photoPath != null) {
      _attachments.add(AttachmentView(
        id: _newId(),
        entryId: id,
        kind: AttachmentKind.photo,
        path: photoPath,
        createdAt: DateTime.now(),
      ));
    }
    _recordUse(draft.itemId, draft.amountPiastres ?? 0);
    _settings[lastPaymentMethodSettingKey] = draft.paymentMethod ?? 'Cash';
    _controller.add(null);
  }

  @override
  Future<Map<String, int>> spendByCategoryForPeriod() async {
    final map = <String, int>{};
    for (final e in _entries) {
      map[e.categoryKey] = (map[e.categoryKey] ?? 0) + e.amountPiastres;
    }
    return map;
  }

  @override
  Future<Map<String, int>> spendByCategoryBetween(
      DateTime start, DateTime? end) async {
    final map = <String, int>{};
    for (final e in _entries) {
      if (e.date.isBefore(start) || (end != null && e.date.isAfter(end))) {
        continue;
      }
      map[e.categoryKey] = (map[e.categoryKey] ?? 0) + e.amountPiastres;
    }
    return map;
  }

  @override
  Future<int> spentBetween(DateTime start, DateTime end) async =>
      _spentInRange(start, end);

  @override
  Future<int> spentInMonth(int year, int month) async {
    return _entries
        .where((e) => e.date.year == year && e.date.month == month)
        .fold<int>(0, (sum, e) => sum + e.amountPiastres);
  }

  /// The fixture's frozen "today" — 2026-09-06, matching every other
  /// hardcoded date in this class — with the time component stripped, so
  /// day/week arithmetic below stays deterministic across test runs
  /// regardless of the real wall-clock date.
  DateTime get _todayAnchor => DateTime(2026, 9, _today);

  @override
  Future<List<({String label, int totalPiastres})>> dailyTotals(
      int lastNDays) async {
    final anchor = _todayAnchor;
    final totals = <({String label, int totalPiastres})>[];
    for (var i = lastNDays - 1; i >= 0; i--) {
      final day = anchor.subtract(Duration(days: i));
      final total = _spentInRange(day, day);
      totals.add((label: day.day.toString(), totalPiastres: total));
    }
    return totals;
  }

  @override
  Future<List<({String label, int totalPiastres})>> weeklyTotals(
      int lastNWeeks) async {
    final anchor = _todayAnchor;
    final totals = <({String label, int totalPiastres})>[];
    for (var i = lastNWeeks - 1; i >= 0; i--) {
      final weekEnd = anchor.subtract(Duration(days: i * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));
      final total = _spentInRange(weekStart, weekEnd);
      totals.add((label: weekStart.day.toString(), totalPiastres: total));
    }
    return totals;
  }

  int _spentInRange(DateTime start, DateTime end) => _entries
      .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
      .fold<int>(0, (sum, e) => sum + e.amountPiastres);

  @override
  Future<List<({String yearMonth, int totalPiastres})>> monthlyTotals(
      int lastNMonths) async {
    // Fixture "today" is fixed at 2026-09-06, matching every other
    // hardcoded date in this class, so widget tests stay deterministic
    // regardless of the real wall-clock date.
    const currentYear = 2026;
    const currentMonth = 9;

    final totals = <({String yearMonth, int totalPiastres})>[];
    for (var i = lastNMonths - 1; i >= 0; i--) {
      var year = currentYear;
      var month = currentMonth - i;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }
      final total = await spentInMonth(year, month);
      final yearMonth =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
      totals.add((yearMonth: yearMonth, totalPiastres: total));
    }
    return totals;
  }

  // ---- v3 ----

  int _idSequence = 0;
  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

  final _groups = <String, CaptureGroupView>{};
  final _records = <String, EntryRecord>{};
  final _attachments = <AttachmentView>[];
  final _aliases = <String, String>{};
  final _settings = <String, String>{};
  final _bills = <RecurringBillView>[];

  @override
  Future<String> saveCapture(CaptureDraft draft) async {
    if (draft.isDraft && draft.lines.isNotEmpty) {
      throw ArgumentError('a draft capture must not carry lines');
    }
    // Validate everything first, then write: the fixture's stand-in for the
    // drift repository's single transaction, so a bad line saves nothing.
    final draftId = draft.draftId;
    final existing = draftId == null ? null : _groups[draftId];
    if (draftId != null && existing?.status != CaptureStatus.draft) {
      throw StateError('$draftId is not a draft capture');
    }
    final known = await knownExternalIds();
    final seenIds = <String>{};
    final seenReferences = <String>{};
    for (final line in draft.lines) {
      final reference = line.reference;
      if (reference != null &&
          (await referenceExists(reference) || !seenReferences.add(reference))) {
        throw DuplicateReferenceException(reference);
      }
    }
    for (final line in draft.lines) {
      if (!_categories.any((c) => c.key == line.categoryKey)) {
        throw ArgumentError.value(line.categoryKey, 'categoryKey');
      }
      final externalId = line.externalId;
      if (externalId != null &&
          (known.contains(externalId) || !seenIds.add(externalId))) {
        throw StateError('external id $externalId already exists');
      }
    }

    final now = DateTime.now();
    final groupId = draftId ?? _newId();
    final day = DateTime(draft.date.year, draft.date.month, draft.date.day);
    final records = <EntryRecord>[];
    for (final line in draft.lines) {
      final itemId = await _learnBarcode(line);
      final record = EntryRecord(
        id: _newId(),
        date: day,
        amountPiastres: line.amountPiastres,
        categoryKey: line.categoryKey,
        subcategoryKey: line.subcategoryKey,
        itemId: itemId,
        description: line.description,
        paymentMethod: draft.paymentMethod,
        source: draft.kind.entrySource,
        quantityMilli: line.quantityMilli,
        unit: line.unit,
        unitPricePiastres: line.unitPricePiastres,
        captureGroupId: groupId,
        externalId: line.externalId,
        reference: line.reference,
        note: line.note,
      );
      records.add(record);
      _records[record.id] = record;
      _createdAt[record.id] = now;
      _recordUse(itemId, line.amountPiastres,
          quantityMilli: line.quantityMilli,
          unitPricePiastres: line.unitPricePiastres);
      _learnPrice(itemId, line);
      final alias = line.aliasToLearn;
      if (alias != null && itemId != null && normalizeArabic(alias).isNotEmpty) {
        _aliases[normalizeArabic(alias)] = itemId;
      }
      _entries.add(EntryView(
        id: record.id,
        displayName: line.description,
        amountPiastres: line.amountPiastres,
        categoryKey: line.categoryKey,
        categoryLabelAr:
            _categories.firstWhere((c) => c.key == line.categoryKey).labelAr,
        date: day,
      ));
    }
    final attachments = [
      for (final a in draft.attachments)
        _attachmentFrom(a, captureGroupId: groupId, now: now),
    ];
    _attachments.addAll(attachments);
    _groups[groupId] = CaptureGroupView(
      id: groupId,
      kind: existing?.kind ?? draft.kind,
      status: draft.status,
      // A finished draft keeps what was captured.
      // A draft keeps what was captured; one captured with no words (a
      // voice note nobody transcribed) takes the text typed at review.
      rawText: existing == null || (existing.rawText ?? '').trim().isEmpty
          ? draft.rawText
          : existing.rawText,
      cleanText: draft.cleanText,
      parsedBy: draft.parsedBy,
      date: day,
      entries: records,
      attachments: [...?existing?.attachments, ...attachments],
    );
    if (draft.status == CaptureStatus.saved) {
      _settings[lastPaymentMethodSettingKey] = draft.paymentMethod;
    }
    _controller.add(null);
    return groupId;
  }

  /// The item's default price becomes the price of one on [line], as the
  /// drift repository's does.
  void _learnPrice(String? itemId, CaptureLine line) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final i = _items[index];
    _items[index] = QuickPickItem(
      id: i.id,
      nameAr: i.nameAr,
      categoryKey: i.categoryKey,
      subcategoryKey: i.subcategoryKey,
      barcode: i.barcode,
      defaultAmountPiastres: capturedUnitPrice(line),
    );
  }

  AttachmentView _attachmentFrom(
    DraftAttachment a, {
    String? entryId,
    String? captureGroupId,
    required DateTime now,
  }) =>
      AttachmentView(
        id: _newId(),
        entryId: entryId,
        captureGroupId: captureGroupId,
        kind: a.kind,
        path: a.path,
        text: a.text,
        transcript: a.transcript,
        durationMs: a.durationMs,
        createdAt: now,
      );

  @override
  Stream<List<CaptureGroupView>> watchDraftCaptures() async* {
    List<CaptureGroupView> drafts() => [
          for (final g in _groups.values.toList().reversed)
            if (g.status == CaptureStatus.draft)
              CaptureGroupView(
                id: g.id,
                kind: g.kind,
                status: g.status,
                rawText: g.rawText,
                cleanText: g.cleanText,
                parsedBy: g.parsedBy,
                date: g.date,
                entries: const [],
                attachments: _attachments
                    .where((a) => a.captureGroupId == g.id)
                    .toList(),
              ),
        ];
    yield drafts();
    yield* _controller.stream.map((_) => drafts());
  }

  @override
  Future<CaptureGroupView?> captureGroup(String id) async {
    final group = _groups[id];
    if (group == null) return null;
    return CaptureGroupView(
      id: group.id,
      kind: group.kind,
      status: group.status,
      rawText: group.rawText,
      cleanText: group.cleanText,
      parsedBy: group.parsedBy,
      date: group.date,
      // From the live records, not the saved snapshot, so an edited or
      // deleted line shows as it is now.
      entries: [
        for (final r in _records.values)
          if (r.captureGroupId == id && !_deleted.contains(r.id)) r,
      ],
      attachments:
          _attachments.where((a) => a.captureGroupId == id).toList(),
    );
  }

  @override
  Future<List<AttachmentView>> attachmentsForEntry(String entryId) async {
    final groupId = _records[entryId]?.captureGroupId;
    return _attachments
        .where((a) =>
            a.entryId == entryId ||
            (groupId != null && a.captureGroupId == groupId))
        .toList();
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
    final view = _attachmentFrom(attachment,
        entryId: entryId, captureGroupId: captureGroupId, now: DateTime.now());
    _attachments.add(view);
    return view;
  }

  @override
  Future<void> learnAlias(String alias, String itemId) async {
    _aliases[normalizeArabic(alias)] = itemId;
  }

  @override
  Future<Map<String, String>> itemAliases() async => Map.of(_aliases);

  @override
  Future<String?> setting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    if (isSecretSettingKey(key)) {
      throw ArgumentError.value(
          key, 'key', 'secrets belong in secure storage, not app_settings');
    }
    _settings[key] = value;
  }

  @override
  Future<List<RecurringBillView>> recurringBills() async =>
      _bills.where((b) => !b.archived).toList()
        ..sort((a, b) => a.nextDue.compareTo(b.nextDue));

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
    final bill = RecurringBillView(
      id: _newId(),
      nameAr: nameAr,
      amountPiastres: amountPiastres,
      categoryKey: categoryKey,
      subcategoryKey: subcategoryKey,
      everyMonths: everyMonths,
      nextDue: DateTime(nextDue.year, nextDue.month, nextDue.day),
      remindDaysBefore: remindDaysBefore,
    );
    _bills.add(bill);
    return bill;
  }

  @override
  Future<void> updateRecurringBill(RecurringBillView bill) async {
    final index = _bills.indexWhere((b) => b.id == bill.id);
    if (index != -1) _bills[index] = bill;
  }

  @override
  Future<void> archiveRecurringBill(String id) async {
    final index = _bills.indexWhere((b) => b.id == id);
    if (index == -1) return;
    final b = _bills[index];
    _bills[index] = RecurringBillView(
      id: b.id,
      nameAr: b.nameAr,
      amountPiastres: b.amountPiastres,
      categoryKey: b.categoryKey,
      subcategoryKey: b.subcategoryKey,
      everyMonths: b.everyMonths,
      nextDue: b.nextDue,
      remindDaysBefore: b.remindDaysBefore,
      archived: true,
    );
  }

  @override
  Future<Set<String>> knownExternalIds() async => {
        for (final r in _records.values)
          if (r.externalId != null) r.externalId!,
        ..._salaryExternalIds,
      };

  // ---- v3: السجل, entry detail, edit and delete ----

  /// When each entry was written. The seeded entries have none and read as
  /// noon on their day.
  final _createdAt = <String, DateTime>{};

  /// Soft-deleted entry ids. Their records stay in [_records] for
  /// [restoreEntries]; their views leave [_entries], which every total
  /// reads.
  final _deleted = <String>{};

  /// The full record behind an entry view. Seeded entries have no record
  /// until first asked for, and get a plain cash, manual one.
  EntryRecord _recordOf(EntryView v) => _records[v.id] ??= EntryRecord(
        id: v.id,
        date: v.date,
        amountPiastres: v.amountPiastres,
        categoryKey: v.categoryKey,
        description: v.displayName,
        paymentMethod: 'Cash',
        source: EntrySource.manual,
      );

  EntryView _viewOf(EntryRecord r) {
    final itemName = _items
        .where((i) => i.id == r.itemId)
        .map((i) => i.nameAr)
        .firstOrNull;
    return EntryView(
      id: r.id,
      displayName:
          r.description.isNotEmpty ? r.description : (itemName ?? ''),
      amountPiastres: r.amountPiastres,
      categoryKey: r.categoryKey,
      categoryLabelAr: _categories
              .where((c) => c.key == r.categoryKey)
              .map((c) => c.labelAr)
              .firstOrNull ??
          r.categoryKey,
      date: r.date,
    );
  }

  /// Replaces the live record (and its view) for [record.id].
  void _replace(EntryRecord record) {
    final index = _entries.indexWhere((e) => e.id == record.id);
    if (index == -1) throw StateError('no live entry ${record.id}');
    _records[record.id] = record;
    _entries[index] = _viewOf(record);
  }

  List<TransactionView> _transactions() {
    final indexed = [
      for (final (i, v) in _entries.indexed)
        (i, _transactionOf(_recordOf(v))),
    ]..sort((a, b) {
        final byDay = b.$2.date.compareTo(a.$2.date);
        if (byDay != 0) return byDay;
        final byTime = b.$2.createdAt.compareTo(a.$2.createdAt);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final (_, t) in indexed) t];
  }

  TransactionView _transactionOf(EntryRecord r) {
    final groupId = r.captureGroupId;
    final attachments = _attachments.where((a) =>
        a.entryId == r.id || (groupId != null && a.captureGroupId == groupId));
    return TransactionView(
      id: r.id,
      date: r.date,
      createdAt: _createdAt[r.id] ??
          DateTime(r.date.year, r.date.month, r.date.day, 12),
      amountPiastres: r.amountPiastres,
      categoryKey: r.categoryKey,
      categoryLabelAr: _viewOf(r).categoryLabelAr,
      subcategoryKey: r.subcategoryKey,
      subcategoryLabelAr: _subcategories
          .where((s) => s.key == r.subcategoryKey)
          .map((s) => s.labelAr)
          .firstOrNull,
      description: r.description,
      itemNameAr: _items
          .where((i) => i.id == r.itemId)
          .map((i) => i.nameAr)
          .firstOrNull,
      note: r.note,
      paymentMethod: r.paymentMethod,
      source: r.source,
      captureGroupId: groupId,
      attachmentKinds: {for (final a in attachments) a.kind},
      attachmentText: [
        for (final a in attachments) ...[?a.text, ?a.transcript],
      ],
    );
  }

  @override
  Stream<List<TransactionView>> watchTransactions() async* {
    yield _transactions();
    yield* _controller.stream.map((_) => _transactions());
  }

  @override
  Future<EntryRecord?> entry(String id) async {
    final view = _entries.where((e) => e.id == id).firstOrNull;
    return view == null ? null : _recordOf(view);
  }

  @override
  Future<void> updateEntry(EntryRecord entry) async {
    final current = await this.entry(entry.id);
    if (current == null) throw StateError('no live entry ${entry.id}');
    if (!_categories.any((c) => c.key == entry.categoryKey)) {
      throw ArgumentError.value(entry.categoryKey, 'categoryKey');
    }
    _replace(EntryRecord(
      id: current.id,
      date: DateTime(entry.date.year, entry.date.month, entry.date.day),
      amountPiastres: entry.amountPiastres,
      categoryKey: entry.categoryKey,
      subcategoryKey: entry.subcategoryKey,
      itemId: entry.itemId,
      description: entry.description,
      paymentMethod: entry.paymentMethod,
      source: current.source,
      quantityMilli: entry.quantityMilli,
      unit: entry.unit,
      unitPricePiastres: entry.unitPricePiastres,
      captureGroupId: current.captureGroupId,
      externalId: current.externalId,
      reference: entry.reference,
      note: entry.note,
    ));
    _controller.add(null);
  }

  @override
  Future<bool> referenceExists(String reference) async => _records.values.any(
      (r) => r.reference == reference && !_deleted.contains(r.id));

  @override
  Future<void> deleteEntries(Iterable<String> ids) async {
    final remove = ids.toSet();
    for (final view in _entries.where((e) => remove.contains(e.id))) {
      _recordOf(view);
      _deleted.add(view.id);
    }
    _entries.removeWhere((e) => remove.contains(e.id));
    _controller.add(null);
  }

  @override
  Future<void> restoreEntries(Iterable<String> ids) async {
    for (final id in ids) {
      final record = _records[id];
      if (record == null || !_deleted.remove(id)) continue;
      _entries.add(_viewOf(record));
    }
    _controller.add(null);
  }

  @override
  Future<void> recategorizeEntries(
      Iterable<String> ids, String categoryKey) async {
    for (final id in ids) {
      final current = await entry(id);
      if (current == null) continue;
      _replace(EntryRecord(
        id: current.id,
        date: current.date,
        amountPiastres: current.amountPiastres,
        categoryKey: categoryKey,
        itemId: current.itemId,
        description: current.description,
        paymentMethod: current.paymentMethod,
        source: current.source,
        quantityMilli: current.quantityMilli,
        unit: current.unit,
        unitPricePiastres: current.unitPricePiastres,
        captureGroupId: current.captureGroupId,
        externalId: current.externalId,
        reference: current.reference,
        note: current.note,
      ));
    }
    _controller.add(null);
  }

  @override
  Future<String> duplicateEntry(String id, DateTime date) async {
    final source = _records[id] ??
        _recordOf(_entries.firstWhere((e) => e.id == id));
    final copy = EntryRecord(
      id: _newId(),
      date: DateTime(date.year, date.month, date.day),
      amountPiastres: source.amountPiastres,
      categoryKey: source.categoryKey,
      subcategoryKey: source.subcategoryKey,
      itemId: source.itemId,
      description: source.description,
      paymentMethod: source.paymentMethod,
      source: source.source,
      quantityMilli: source.quantityMilli,
      unit: source.unit,
      unitPricePiastres: source.unitPricePiastres,
      note: source.note,
    );
    _records[copy.id] = copy;
    _createdAt[copy.id] = DateTime.now();
    _entries.add(_viewOf(copy));
    _recordUse(copy.itemId, copy.amountPiastres,
        quantityMilli: copy.quantityMilli,
        unitPricePiastres: copy.unitPricePiastres);
    _controller.add(null);
    return copy.id;
  }

  @override
  Future<RecurringBillView> payRecurringBill(String id, DateTime paidOn,
      {DateTime? expectedDue}) async {
    final index = _bills.indexWhere((b) => b.id == id && !b.archived);
    if (index == -1) throw StateError('no live recurring bill $id');
    final bill = _bills[index];
    if (expectedDue != null &&
        (expectedDue.year != bill.nextDue.year ||
            expectedDue.month != bill.nextDue.month ||
            expectedDue.day != bill.nextDue.day)) {
      throw StateError('bill $id is no longer due $expectedDue');
    }
    final record = EntryRecord(
      id: _newId(),
      date: DateTime(paidOn.year, paidOn.month, paidOn.day),
      amountPiastres: bill.amountPiastres,
      categoryKey: bill.categoryKey,
      subcategoryKey: bill.subcategoryKey,
      description: bill.nameAr,
      paymentMethod: 'Cash',
      source: EntrySource.manual,
    );
    _records[record.id] = record;
    _createdAt[record.id] = DateTime.now();
    _entries.add(_viewOf(record));
    final paid = RecurringBillView(
      id: bill.id,
      nameAr: bill.nameAr,
      amountPiastres: bill.amountPiastres,
      categoryKey: bill.categoryKey,
      subcategoryKey: bill.subcategoryKey,
      everyMonths: bill.everyMonths,
      nextDue: dueAfterPayment(bill),
      remindDaysBefore: bill.remindDaysBefore,
    );
    _bills[index] = paid;
    _controller.add(null);
    return paid;
  }
}
