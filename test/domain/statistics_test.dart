import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/dashboard.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/statistics.dart';

var _id = 0;

TransactionView _t(
  DateTime date,
  int amount,
  String category, {
  String? sub,
  String? subLabel,
  String? label,
}) => TransactionView(
  id: '${_id++}',
  date: date,
  createdAt: date,
  amountPiastres: amount,
  categoryKey: category,
  categoryLabelAr: label ?? category,
  subcategoryKey: sub,
  subcategoryLabelAr: subLabel,
  description: '',
  paymentMethod: 'Cash',
  source: EntrySource.manual,
);

void main() {
  group('YearMonth', () {
    test('steps across a year boundary both ways', () {
      expect(const YearMonth(2026, 1).previous, const YearMonth(2025, 12));
      expect(const YearMonth(2025, 12).next, const YearMonth(2026, 1));
    });

    test('knows its first and last day, February of a leap year too', () {
      expect(const YearMonth(2028, 2).firstDay, DateTime(2028, 2, 1));
      expect(const YearMonth(2028, 2).lastDay, DateTime(2028, 2, 29));
      expect(const YearMonth(2026, 9).lastDay, DateTime(2026, 9, 30));
    });

    test('of() takes the month of any moment in it', () {
      expect(
        YearMonth.of(DateTime(2026, 9, 30, 23, 59)),
        const YearMonth(2026, 9),
      );
    });

    test('contains only days of its own month', () {
      const sep = YearMonth(2026, 9);
      expect(sep.contains(DateTime(2026, 9, 1)), isTrue);
      expect(sep.contains(DateTime(2026, 9, 30, 23)), isTrue);
      expect(sep.contains(DateTime(2026, 10, 1)), isFalse);
      expect(sep.contains(DateTime(2025, 9, 15)), isFalse);
    });

    test('orders by year then month', () {
      expect(const YearMonth(2025, 12) < const YearMonth(2026, 1), isTrue);
      expect(const YearMonth(2026, 2) < const YearMonth(2026, 1), isFalse);
    });

    test('is labelled with the Arabic month name and a Latin year', () {
      expect(const YearMonth(2026, 9).label, 'سبتمبر 2026');
    });
  });

  group('spendByCategoryInMonth', () {
    test('sums each category over the month only', () {
      final entries = [
        _t(DateTime(2026, 9, 1), 1000, 'Food'),
        _t(DateTime(2026, 9, 30), 500, 'Food'),
        _t(DateTime(2026, 9, 12), 700, 'Drinks'),
        _t(DateTime(2026, 8, 31), 9900, 'Food'),
        _t(DateTime(2026, 10, 1), 9900, 'Bills'),
      ];
      expect(spendByCategoryInMonth(entries, const YearMonth(2026, 9)), {
        'Food': 1500,
        'Drinks': 700,
      });
    });
  });

  group('spendBySubcategoryInMonth', () {
    test('sums one category by subcategory, with a null key for entries '
        'filed under the category alone', () {
      final entries = [
        _t(DateTime(2026, 9, 1), 1000, 'Food', sub: 'Lunch', subLabel: 'غدا'),
        _t(DateTime(2026, 9, 2), 400, 'Food', sub: 'Lunch', subLabel: 'غدا'),
        _t(DateTime(2026, 9, 3), 300, 'Food'),
        _t(DateTime(2026, 9, 3), 800, 'Drinks', sub: 'Soda'),
        _t(DateTime(2026, 8, 3), 800, 'Food', sub: 'Lunch'),
      ];
      final subs = spendBySubcategoryInMonth(
        entries,
        const YearMonth(2026, 9),
        'Food',
      );
      expect(subs, {
        'Lunch': (label: 'غدا', amountPiastres: 1400),
        null: (label: null, amountPiastres: 300),
      });
    });
  });

  group('donutSlices', () {
    test('keeps every category when there are six or fewer, biggest first, '
        'each with its whole percent', () {
      final slices = donutSlices({'A': 100, 'B': 300, 'C': 600});
      expect([for (final s in slices) s.key], ['C', 'B', 'A']);
      expect([for (final s in slices) s.percent], [60, 30, 10]);
      expect(slices.any((s) => s.isOther), isFalse);
    });

    test('merges everything past the fifth into one "other" slice so there '
        'are at most six', () {
      final slices = donutSlices({
        'A': 700,
        'B': 600,
        'C': 500,
        'D': 400,
        'E': 300,
        'F': 200,
        'G': 100,
      });
      expect(slices, hasLength(6));
      expect(
        [for (final s in slices.take(5)) s.key],
        ['A', 'B', 'C', 'D', 'E'],
      );
      final other = slices.last;
      expect(other.isOther, isTrue);
      expect(other.amountPiastres, 300);
      expect(other.mergedKeys, ['F', 'G']);
      expect(other.percent, 11); // 300 of 2800, 10.7 rounded
    });

    test('exactly six categories stay six real slices', () {
      final slices = donutSlices({
        'A': 6,
        'B': 5,
        'C': 4,
        'D': 3,
        'E': 2,
        'F': 1,
      });
      expect(slices, hasLength(6));
      expect(slices.any((s) => s.isOther), isFalse);
    });

    test('drops zero amounts and returns nothing for an empty month', () {
      expect(donutSlices({'A': 0}), isEmpty);
      expect(donutSlices({}), isEmpty);
    });

    test('ties keep a stable order by key', () {
      final slices = donutSlices({'B': 100, 'A': 100});
      expect([for (final s in slices) s.key], ['A', 'B']);
    });
  });

  group('monthHistory', () {
    test('lists every month with spending, newest first, with its total and '
        'top three categories', () {
      final entries = [
        _t(DateTime(2026, 9, 1), 1000, 'Food'),
        _t(DateTime(2026, 9, 2), 3000, 'Bills'),
        _t(DateTime(2026, 9, 3), 500, 'Drinks'),
        _t(DateTime(2026, 9, 4), 200, 'Snacks'),
        _t(DateTime(2026, 7, 10), 2000, 'Food'),
      ];
      final history = monthHistory(entries);
      expect(
        [for (final m in history) m.month],
        [const YearMonth(2026, 9), const YearMonth(2026, 7)],
      );
      expect(history.first.totalPiastres, 4700);
      expect(history.first.topCategoryKeys, ['Bills', 'Food', 'Drinks']);
      expect(history.last.topCategoryKeys, ['Food']);
    });

    test('compares each month with the calendar month before it', () {
      final entries = [
        _t(DateTime(2026, 9, 1), 1200, 'Food'),
        _t(DateTime(2026, 8, 1), 1000, 'Food'),
        _t(DateTime(2026, 6, 1), 500, 'Food'),
      ];
      final history = monthHistory(entries);
      final sep = history[0].change!;
      expect(sep.direction, ComparisonDirection.more);
      expect(sep.percent, 20);
      // July had nothing, so August has nothing to compare with.
      expect(history[1].change, isNull);
      expect(history[2].change, isNull);
    });

    test('a month whose entries total zero is left out', () {
      expect(monthHistory([_t(DateTime(2026, 9, 1), 0, 'Food')]), isEmpty);
    });
  });
}
