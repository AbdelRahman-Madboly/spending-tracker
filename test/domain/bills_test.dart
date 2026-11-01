import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/bills.dart';
import 'package:spending_tracker/domain/models.dart';

RecurringBillView bill({
  String id = 'b1',
  String name = 'فاتورة موبايل',
  int amount = 10000,
  String category = 'Bills',
  String? sub = 'PhoneBill',
  int every = 1,
  required DateTime due,
  int remind = 2,
}) =>
    RecurringBillView(
      id: id,
      nameAr: name,
      amountPiastres: amount,
      categoryKey: category,
      subcategoryKey: sub,
      everyMonths: every,
      nextDue: due,
      remindDaysBefore: remind,
    );

TransactionView tx(
  String id,
  DateTime date,
  int amount, {
  String description = '',
  String? item,
  String category = 'Bills',
  String? sub,
}) =>
    TransactionView(
      id: id,
      date: date,
      createdAt: date,
      amountPiastres: amount,
      categoryKey: category,
      categoryLabelAr: 'فواتير',
      subcategoryKey: sub,
      description: description,
      itemNameAr: item,
      paymentMethod: 'Cash',
      source: EntrySource.manual,
    );

void main() {
  group('dueAfterPayment', () {
    test('moves the due date on by everyMonths', () {
      expect(dueAfterPayment(bill(due: DateTime(2026, 10, 27))),
          DateTime(2026, 11, 27));
      expect(dueAfterPayment(bill(due: DateTime(2026, 11, 15), every: 3)),
          DateTime(2027, 2, 15));
    });

    test('clamps to a shorter month', () {
      expect(dueAfterPayment(bill(due: DateTime(2027, 1, 31))),
          DateTime(2027, 2, 28));
    });
  });

  group('nextDueOnDay', () {
    test('this month while the day is ahead or today, else next month', () {
      expect(nextDueOnDay(15, DateTime(2026, 9, 10)), DateTime(2026, 9, 15));
      expect(nextDueOnDay(15, DateTime(2026, 9, 15, 23)), DateTime(2026, 9, 15));
      expect(nextDueOnDay(15, DateTime(2026, 9, 16)), DateTime(2026, 10, 15));
    });

    test('clamps to a shorter month', () {
      expect(nextDueOnDay(31, DateTime(2026, 9, 29)), DateTime(2026, 9, 30));
      expect(nextDueOnDay(31, DateTime(2027, 1, 31, 9)), DateTime(2027, 1, 31));
      expect(nextDueOnDay(30, DateTime(2027, 2, 1)), DateTime(2027, 2, 28));
    });
  });

  group('reminderTime', () {
    test('is remindDaysBefore the due date at 10 in the morning', () {
      expect(
        reminderTime(bill(due: DateTime(2026, 10, 27), remind: 2),
            DateTime(2026, 9, 29, 12)),
        DateTime(2026, 10, 25, 10),
      );
    });

    test('with 0 days it is on the due day itself', () {
      expect(
        reminderTime(bill(due: DateTime(2026, 10, 27), remind: 0),
            DateTime(2026, 9, 29)),
        DateTime(2026, 10, 27, 10),
      );
    });

    test('is null once that moment has passed', () {
      expect(
        reminderTime(bill(due: DateTime(2026, 10, 1), remind: 2),
            DateTime(2026, 9, 29, 10, 1)),
        isNull,
      );
    });
  });

  group('suggestBills', () {
    final today = DateTime(2026, 9, 29);

    test('same item and amount in two consecutive months is suggested', () {
      final suggestions = suggestBills(
        history: [
          tx('1', DateTime(2026, 7, 7), 17000,
              description: 'فاتورة موبايل', sub: 'PhoneBill'),
          tx('2', DateTime(2026, 8, 7), 17000,
              description: 'فاتورة موبايل', sub: 'PhoneBill'),
        ],
        bills: const [],
        today: today,
        includeSeeds: false,
      );
      expect(suggestions, hasLength(1));
      final s = suggestions.single;
      expect(s.nameAr, 'فاتورة موبايل');
      expect(s.amountPiastres, 17000);
      expect(s.categoryKey, 'Bills');
      expect(s.subcategoryKey, 'PhoneBill');
      // Monthly from the latest payment, the first date not before today.
      expect(s.nextDue, DateTime(2026, 10, 7));
    });

    test('a linked item name wins over the description', () {
      final suggestions = suggestBills(
        history: [
          tx('1', DateTime(2026, 7, 3), 5000, item: 'باقة اتصالات'),
          tx('2', DateTime(2026, 8, 4), 5000,
              item: 'باقة اتصالات', description: 'شحن'),
        ],
        bills: const [],
        today: today,
        includeSeeds: false,
      );
      expect(suggestions.single.nameAr, 'باقة اتصالات');
    });

    test('months that are not consecutive, or amounts that differ, are not',
        () {
      final suggestions = suggestBills(
        history: [
          tx('1', DateTime(2026, 5, 7), 17000, description: 'فاتورة موبايل'),
          tx('2', DateTime(2026, 7, 7), 17000, description: 'فاتورة موبايل'),
          tx('3', DateTime(2026, 7, 9), 2000, description: 'عيش'),
          tx('4', DateTime(2026, 8, 9), 2500, description: 'عيش'),
          tx('5', DateTime(2026, 8, 9), 900, description: ''),
          tx('6', DateTime(2026, 9, 9), 900, description: ''),
        ],
        bills: const [],
        today: today,
        includeSeeds: false,
      );
      expect(suggestions, isEmpty);
    });

    test('two payments in the same month alone are not a monthly bill', () {
      final suggestions = suggestBills(
        history: [
          tx('1', DateTime(2026, 9, 1), 3000, description: 'قهوة'),
          tx('2', DateTime(2026, 9, 20), 3000, description: 'قهوة'),
        ],
        bills: const [],
        today: today,
        includeSeeds: false,
      );
      expect(suggestions, isEmpty);
    });

    test('Dec to Jan counts as consecutive', () {
      final suggestions = suggestBills(
        history: [
          tx('1', DateTime(2025, 12, 5), 3000, description: 'جيم'),
          tx('2', DateTime(2026, 1, 5), 3000, description: 'جيم'),
        ],
        bills: const [],
        today: DateTime(2026, 1, 20),
        includeSeeds: false,
      );
      expect(suggestions.single.nextDue, DateTime(2026, 2, 5));
    });

    test('a bill that already exists by name is not suggested again', () {
      final suggestions = suggestBills(
        history: [
          tx('1', DateTime(2026, 7, 7), 17000, description: 'فاتوره موبايل'),
          tx('2', DateTime(2026, 8, 7), 17000, description: 'فاتوره موبايل'),
        ],
        bills: [bill(name: 'فاتورة موبايل', amount: 20000, due: today)],
        today: today,
        includeSeeds: false,
      );
      expect(suggestions, isEmpty);
    });

    test('a dismissed suggestion stays away', () {
      final history = [
        tx('1', DateTime(2026, 7, 7), 17000, description: 'فاتورة موبايل'),
        tx('2', DateTime(2026, 8, 7), 17000, description: 'فاتورة موبايل'),
      ];
      final first = suggestBills(
          history: history, bills: const [], today: today, includeSeeds: false);
      expect(
        suggestBills(
          history: history,
          bills: const [],
          today: today,
          dismissed: {first.single.key},
          includeSeeds: false,
        ),
        isEmpty,
      );
    });

    test('offers a home internet plan, 300 EGP due on the 27th', () {
      final suggestions =
          suggestBills(history: const [], bills: const [], today: today);
      final plan =
          suggestions.singleWhere((s) => s.key == homeInternetSuggestionKey);
      expect(plan.nameAr, contains('باقة'));
      expect(plan.amountPiastres, 30000);
      expect(plan.categoryKey, 'Bills');
      expect(plan.subcategoryKey, 'HomeInternet');
      expect(plan.nextDue, DateTime(2026, 10, 27));
    });

    test('the home internet seed is due this month while the 27th is still ahead',
        () {
      final plan = suggestBills(
              history: const [], bills: const [], today: DateTime(2026, 10, 3))
          .singleWhere((s) => s.key == homeInternetSuggestionKey);
      expect(plan.nextDue, DateTime(2026, 10, 27));
    });

    test('the home internet seed hides once a home internet bill exists or dismissed',
        () {
      expect(
        suggestBills(
          history: const [],
          bills: [
            bill(name: 'النت', sub: 'HomeInternet', due: DateTime(2026, 10, 27))
          ],
          today: today,
        ).where((s) => s.key == homeInternetSuggestionKey),
        isEmpty,
      );
      expect(
        suggestBills(
          history: const [],
          bills: const [],
          today: today,
          dismissed: {homeInternetSuggestionKey},
        ),
        isEmpty,
      );
    });

    test('history that already finds home internet replaces the seed', () {
      final suggestions = suggestBills(
        history: [
          tx('1', DateTime(2026, 8, 26), 30000,
              description: 'نت البيت', sub: 'HomeInternet'),
          tx('2', DateTime(2026, 9, 26), 30000,
              description: 'نت البيت', sub: 'HomeInternet'),
        ],
        bills: const [],
        today: today,
      );
      expect(suggestions.map((s) => s.nameAr), ['نت البيت']);
    });
  });

  group('dismissed suggestion storage', () {
    test('round-trips through its setting value', () {
      final keys = {'a|1', 'ب|2'};
      expect(decodeDismissedSuggestions(encodeDismissedSuggestions(keys)),
          keys);
    });

    test('a missing or broken value reads as none', () {
      expect(decodeDismissedSuggestions(null), isEmpty);
      expect(decodeDismissedSuggestions('not json'), isEmpty);
    });
  });
}
