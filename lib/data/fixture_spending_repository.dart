import 'dart:async';

import '../domain/models.dart';
import '../domain/spending_repository.dart';

/// Mirrors the ten categories seeded into the real database
/// (see `lib/data/db/database.dart`) so widget tests exercise the same
/// category set the app ships with.
const _categories = [
  CategoryView(key: 'Drinks', labelAr: 'مشروبات', iconName: 'local_drink'),
  CategoryView(key: 'Snacks', labelAr: 'سناكس', iconName: 'cookie'),
  CategoryView(key: 'Food', labelAr: 'أكل', iconName: 'restaurant'),
  CategoryView(
      key: 'Transport', labelAr: 'مواصلات', iconName: 'directions_bus'),
  CategoryView(key: 'Bills', labelAr: 'فواتير', iconName: 'receipt_long'),
  CategoryView(
      key: 'Personal Care', labelAr: 'عناية شخصية', iconName: 'content_cut'),
  CategoryView(key: 'Shopping', labelAr: 'تسوق', iconName: 'shopping_bag'),
  CategoryView(
      key: 'Family/Social', labelAr: 'عائلة وزيارات', iconName: 'groups'),
  CategoryView(key: 'Gifts', labelAr: 'هدايا', iconName: 'card_giftcard'),
  CategoryView(key: 'Loans', labelAr: 'سلف', iconName: 'handshake'),
];

/// Mirrors the subcategory catalogue seeded into the real database (see
/// `lib/data/db/database.dart`'s `_seedSubcategoryRows`), so widget tests
/// exercise the same Category -> Subcategory structure the app ships with.
const _subcategories = [
  SubcategoryView(
      key: 'Soda',
      categoryKey: 'Drinks',
      labelAr: 'صودا',
      iconName: 'local_bar'),
  SubcategoryView(
      key: 'Water',
      categoryKey: 'Drinks',
      labelAr: 'مياه',
      iconName: 'water_drop'),
  SubcategoryView(
      key: 'Milk',
      categoryKey: 'Drinks',
      labelAr: 'لبن',
      iconName: 'local_drink'),
  SubcategoryView(
      key: 'Juice',
      categoryKey: 'Drinks',
      labelAr: 'عصير',
      iconName: 'emoji_food_beverage'),
  SubcategoryView(
      key: 'HotDrinks',
      categoryKey: 'Drinks',
      labelAr: 'مشروبات ساخنة',
      iconName: 'local_cafe'),
  SubcategoryView(
      key: 'Chips', categoryKey: 'Snacks', labelAr: 'شيبسي', iconName: 'tapas'),
  SubcategoryView(
      key: 'Chocolate',
      categoryKey: 'Snacks',
      labelAr: 'شوكولاتة',
      iconName: 'cake'),
  SubcategoryView(
      key: 'Biscuits',
      categoryKey: 'Snacks',
      labelAr: 'بسكوت',
      iconName: 'cookie'),
  SubcategoryView(
      key: 'Sweets',
      categoryKey: 'Snacks',
      labelAr: 'حلويات',
      iconName: 'icecream'),
  SubcategoryView(
      key: 'FastFood',
      categoryKey: 'Snacks',
      labelAr: 'وجبات سريعة',
      iconName: 'fastfood'),
  SubcategoryView(
      key: 'Breakfast',
      categoryKey: 'Food',
      labelAr: 'فطار',
      iconName: 'free_breakfast'),
  SubcategoryView(
      key: 'Lunch',
      categoryKey: 'Food',
      labelAr: 'غدا',
      iconName: 'lunch_dining'),
  SubcategoryView(
      key: 'Dinner',
      categoryKey: 'Food',
      labelAr: 'عشا',
      iconName: 'dinner_dining'),
  SubcategoryView(
      key: 'Groceries',
      categoryKey: 'Food',
      labelAr: 'بقالة',
      iconName: 'local_grocery_store'),
  SubcategoryView(
      key: 'PublicTransport',
      categoryKey: 'Transport',
      labelAr: 'مواصلات عامة',
      iconName: 'directions_bus'),
  SubcategoryView(
      key: 'Taxi',
      categoryKey: 'Transport',
      labelAr: 'تاكسي',
      iconName: 'local_taxi'),
  SubcategoryView(
      key: 'PhoneBill',
      categoryKey: 'Bills',
      labelAr: 'فاتورة موبايل',
      iconName: 'smartphone'),
  SubcategoryView(
      key: 'HomeInternet',
      categoryKey: 'Bills',
      labelAr: 'إنترنت المنزل',
      iconName: 'wifi'),
  SubcategoryView(
      key: 'Haircut',
      categoryKey: 'Personal Care',
      labelAr: 'حلاقة',
      iconName: 'content_cut'),
  SubcategoryView(
      key: 'Cosmetics',
      categoryKey: 'Personal Care',
      labelAr: 'مستحضرات',
      iconName: 'spa'),
  SubcategoryView(
      key: 'Clothes',
      categoryKey: 'Shopping',
      labelAr: 'ملابس',
      iconName: 'checkroom'),
  SubcategoryView(
      key: 'Electronics',
      categoryKey: 'Shopping',
      labelAr: 'إلكترونيات',
      iconName: 'devices'),
  SubcategoryView(
      key: 'OnlineShopping',
      categoryKey: 'Shopping',
      labelAr: 'تسوق أونلاين',
      iconName: 'shopping_cart'),
  SubcategoryView(
      key: 'Trips',
      categoryKey: 'Family/Social',
      labelAr: 'رحلات',
      iconName: 'flight'),
  SubcategoryView(
      key: 'Visits',
      categoryKey: 'Family/Social',
      labelAr: 'زيارات',
      iconName: 'people'),
  SubcategoryView(
      key: 'Gifts',
      categoryKey: 'Gifts',
      labelAr: 'هدايا',
      iconName: 'card_giftcard'),
  SubcategoryView(
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

  final _controller = StreamController<void>.broadcast();
  final _archivedItemIds = <String>{};
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
      );

  @override
  Future<void> updateSalary(int amountPiastres) async {
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

  @override
  Future<List<QuickPickItem>> topItems(int limit) async => _items
      .where((i) => !_archivedItemIds.contains(i.id))
      .take(limit)
      .toList();

  @override
  Future<List<CategoryView>> categories() async => _categories;

  @override
  Future<List<SubcategoryView>> subcategories(String categoryKey) async =>
      _subcategories.where((s) => s.categoryKey == categoryKey).toList();

  @override
  Future<List<QuickPickItem>> itemsInCategory(
          String categoryKey, int limit) async =>
      _items
          .where((i) =>
              i.categoryKey == categoryKey && !_archivedItemIds.contains(i.id))
          .take(limit)
          .toList();

  @override
  Future<QuickPickItem> createItem({
    required String nameAr,
    required String categoryKey,
    int? defaultAmountPiastres,
    String? barcode,
  }) async {
    final item = QuickPickItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nameAr: nameAr,
      categoryKey: categoryKey,
      defaultAmountPiastres: defaultAmountPiastres,
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<void> saveEntry(DraftEntry draft) async {
    final categoryKey = draft.categoryKey ?? 'Food';
    final categoryLabelAr = _categories
        .firstWhere((c) => c.key == categoryKey,
            orElse: () => _categories.first)
        .labelAr;
    _entries.add(EntryView(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      displayName: draft.description ?? '',
      amountPiastres: draft.amountPiastres ?? 0,
      categoryKey: categoryKey,
      categoryLabelAr: categoryLabelAr,
      date: DateTime(2026, 9, _today),
    ));
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
}
