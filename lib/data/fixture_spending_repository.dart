import 'dart:async';

import '../domain/models.dart';
import '../domain/spending_repository.dart';

class FixtureSpendingRepository implements SpendingRepository {
  static const _salary = 900000;
  static const _today = 6;

  final _entries = <EntryView>[
    EntryView(
      id: '1',
      displayName: 'لبن',
      amountPiastres: 3500,
      categoryKey: 'Food/Social',
      categoryLabelAr: 'أكل وخروج',
      date: DateTime(2026, 9, 6),
    ),
    EntryView(
      id: '2',
      displayName: 'إندومي',
      amountPiastres: 1000,
      categoryKey: 'Food/Social',
      categoryLabelAr: 'أكل وخروج',
      date: DateTime(2026, 9, 5),
    ),
    EntryView(
      id: '3',
      displayName: 'شويبس',
      amountPiastres: 4000,
      categoryKey: 'Food/Social',
      categoryLabelAr: 'أكل وخروج',
      date: DateTime(2026, 9, 5),
    ),
  ];

  final _controller = StreamController<void>.broadcast();

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
  Future<List<QuickPickItem>> topItems(int limit) async => const [
        QuickPickItem(id: 'i1', nameAr: 'شويبس', categoryKey: 'Food/Social', defaultAmountPiastres: 4000),
        QuickPickItem(id: 'i2', nameAr: 'إندومي', categoryKey: 'Food/Social', defaultAmountPiastres: 1000),
        QuickPickItem(id: 'i3', nameAr: 'لبن', categoryKey: 'Food/Social', defaultAmountPiastres: 3500),
        QuickPickItem(id: 'i4', nameAr: 'تاكسي', categoryKey: 'Transport', defaultAmountPiastres: 3500),
        QuickPickItem(id: 'i5', nameAr: 'مخبز', categoryKey: 'Food/Social', defaultAmountPiastres: 2500),
        QuickPickItem(id: 'i6', nameAr: 'شيبسي', categoryKey: 'Food/Social', defaultAmountPiastres: 1000),
        QuickPickItem(id: 'i7', nameAr: 'فطار', categoryKey: 'Food/Social', defaultAmountPiastres: 1500),
        QuickPickItem(id: 'i8', nameAr: 'مواصلات', categoryKey: 'Transport', defaultAmountPiastres: 700),
        QuickPickItem(id: 'i9', nameAr: 'عصير', categoryKey: 'Food/Social', defaultAmountPiastres: 2000),
        QuickPickItem(id: 'i10', nameAr: 'حلاقة', categoryKey: 'Personal Care', defaultAmountPiastres: 10000),
        QuickPickItem(id: 'i11', nameAr: 'شحن رصيد', categoryKey: 'Bills', defaultAmountPiastres: 10000),
        QuickPickItem(id: 'i12', nameAr: 'شوكولاتة', categoryKey: 'Food/Social', defaultAmountPiastres: 500),
      ].take(limit).toList();

  @override
  Future<void> saveEntry(DraftEntry draft) async {
    _entries.add(EntryView(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      displayName: draft.description ?? '',
      amountPiastres: draft.amountPiastres ?? 0,
      categoryKey: draft.categoryKey ?? 'Food/Social',
      categoryLabelAr: 'أكل وخروج',
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
}
