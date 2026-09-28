import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/dashboard.dart';
import 'package:spending_tracker/domain/models.dart';

RecurringBillView _bill(String id, DateTime due, {bool archived = false}) =>
    RecurringBillView(
      id: id,
      nameAr: id,
      amountPiastres: 10000,
      categoryKey: 'Bills',
      everyMonths: 1,
      nextDue: due,
      remindDaysBefore: 2,
      archived: archived,
    );

void main() {
  group('PeriodSummary progress', () {
    test('elapsed fraction is the share of the period already behind us', () {
      const summary = PeriodSummary(
        salaryPiastres: 900000,
        spentPiastres: 180000,
        daysRemaining: 20,
        lengthDays: 30,
      );
      expect(summary.daysElapsed, 10);
      expect(summary.elapsedFraction, closeTo(1 / 3, 1e-9));
      expect(summary.spentPercent, 20);
    });

    test('fractions stay within 0..1 on a late salary or an empty salary', () {
      const late = PeriodSummary(
        salaryPiastres: 0,
        spentPiastres: 5000,
        daysRemaining: -4,
        lengthDays: 30,
      );
      expect(late.elapsedFraction, 1);
      // No salary recorded: nothing to measure the spend against.
      expect(late.spentPercent, isNull);
    });

    test('a past period is never current and keeps no days left', () {
      final past = PeriodSummary(
        salaryPiastres: 900000,
        spentPiastres: 910000,
        daysRemaining: 0,
        lengthDays: 30,
        start: DateTime(2026, 8, 4),
        end: DateTime(2026, 9, 3),
        isCurrent: false,
      );
      expect(past.isCurrent, isFalse);
      expect(past.safeDailyPiastres, isNull);
      expect(past.spentPercent, 101);
    });
  });

  group('budgetLevel', () {
    test('is fine under 80%, a warning from 80% and over from 100%', () {
      expect(budgetLevel(79), BudgetLevel.fine);
      expect(budgetLevel(80), BudgetLevel.warning);
      expect(budgetLevel(99), BudgetLevel.warning);
      expect(budgetLevel(100), BudgetLevel.over);
      expect(budgetLevel(null), BudgetLevel.fine);
    });
  });

  group('formatPeriodLabel', () {
    test('names both ends with Arabic months and Latin digits', () {
      expect(formatPeriodLabel(DateTime(2026, 9, 4), DateTime(2026, 10, 3)),
          '4 سبتمبر – 3 أكتوبر');
    });

    test('a period without an end names its start only', () {
      expect(formatPeriodLabel(DateTime(2026, 1, 23), null), 'من 23 يناير');
    });
  });

  group('compareToLastMonth', () {
    test('spending less reads as أقل with a rounded percentage', () {
      final c = compareToLastMonth(8800, 10000)!;
      expect(c.direction, ComparisonDirection.less);
      expect(c.percent, 12);
      expect(c.sentence, 'أقل بـ 12% من الشهر الماضي في نفس اليوم');
    });

    test('spending more reads as أكتر', () {
      final c = compareToLastMonth(15000, 10000)!;
      expect(c.direction, ComparisonDirection.more);
      expect(c.sentence, 'أكتر بـ 50% من الشهر الماضي في نفس اليوم');
    });

    test('the same spend reads as unchanged', () {
      final c = compareToLastMonth(10000, 10000)!;
      expect(c.direction, ComparisonDirection.same);
      expect(c.sentence, 'زي الشهر الماضي في نفس اليوم');
    });

    test('nothing to compare against gives null', () {
      expect(compareToLastMonth(5000, 0), isNull);
    });
  });

  group('upcomingBills', () {
    final today = DateTime(2026, 9, 29);

    test('keeps the soonest three due within ten days, overdue included', () {
      final bills = [
        _bill('later', DateTime(2026, 10, 12)),
        _bill('d5', DateTime(2026, 10, 4)),
        _bill('d0', DateTime(2026, 9, 29)),
        _bill('overdue', DateTime(2026, 9, 27)),
        _bill('d10', DateTime(2026, 10, 9)),
        _bill('gone', DateTime(2026, 9, 30), archived: true),
      ];
      expect(upcomingBills(bills, today).map((b) => b.id),
          ['overdue', 'd0', 'd5']);
    });

    test('is empty when nothing falls due soon', () {
      expect(upcomingBills([_bill('x', DateTime(2026, 11, 1))], today),
          isEmpty);
    });
  });

  group('topCategoryShares', () {
    test('ranks by amount, keeps five and gives each its share of the total',
        () {
      final shares = topCategoryShares({
        'Food': 5000,
        'Drinks': 3000,
        'Bills': 1000,
        'Gifts': 500,
        'Loans': 300,
        'Home': 200,
      });
      expect(shares.map((s) => s.categoryKey),
          ['Food', 'Drinks', 'Bills', 'Gifts', 'Loans']);
      expect(shares.first.amountPiastres, 5000);
      expect(shares.first.percent, 50);
      expect(shares[1].percent, 30);
    });

    test('drops zero rows and is empty for no spending', () {
      expect(topCategoryShares({'Food': 0}), isEmpty);
    });
  });
}
