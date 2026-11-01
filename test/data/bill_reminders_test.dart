import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/bill_reminders.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';

class FakeNotifier implements ReminderNotifier {
  final scheduled = <({int id, DateTime at, String title, String body})>[];
  int cancels = 0;
  bool grant = true;
  int permissionRequests = 0;
  bool failSchedule = false;

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled.clear();
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (failSchedule) throw StateError('no plugin');
    scheduled.add((id: id, at: at, title: title, body: body));
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }
}

RecurringBillView bill(String id, DateTime due,
        {int remind = 2, bool archived = false}) =>
    RecurringBillView(
      id: id,
      nameAr: 'فاتورة $id',
      amountPiastres: 30000,
      categoryKey: 'Bills',
      everyMonths: 1,
      nextDue: due,
      remindDaysBefore: remind,
      archived: archived,
    );

void main() {
  test('cancels the old reminders and schedules one per upcoming bill',
      () async {
    final notifier = FakeNotifier();
    final reminders =
        BillReminders(notifier, clock: () => DateTime(2026, 9, 29, 12));
    await reminders.reschedule([
      bill('a', DateTime(2026, 10, 27)),
      bill('b', DateTime(2026, 9, 30)), // reminder already passed
      bill('c', DateTime(2026, 10, 7), archived: true),
      bill('d', DateTime(2026, 10, 5), remind: 0),
    ]);
    expect(notifier.cancels, 1);
    expect(notifier.scheduled.map((s) => s.at),
        [DateTime(2026, 10, 25, 10), DateTime(2026, 10, 5, 10)]);
    final first = notifier.scheduled.first;
    expect(first.title, contains('فاتورة a'));
    expect(first.body, contains('300'));
    expect(first.body, contains('27'));
    expect(notifier.scheduled.map((s) => s.id).toSet(), hasLength(2));
  });

  test('rescheduleFrom reads the live bills from the repository', () async {
    final repo = FixtureSpendingRepository();
    final bill = await repo.createRecurringBill(
      nameAr: 'باقة إنترنت المنزل',
      amountPiastres: 30000,
      categoryKey: 'Bills',
      nextDue: DateTime(2026, 10, 27),
    );
    final notifier = FakeNotifier();
    final reminders =
        BillReminders(notifier, clock: () => DateTime(2026, 9, 29));
    await reminders.rescheduleFrom(repo);
    expect(notifier.scheduled, hasLength(1));

    await repo.archiveRecurringBill(bill.id);
    await reminders.rescheduleFrom(repo);
    expect(notifier.scheduled, isEmpty);
  });

  test('a notifier failure never reaches the caller', () async {
    final notifier = FakeNotifier()..failSchedule = true;
    final reminders =
        BillReminders(notifier, clock: () => DateTime(2026, 9, 29));
    await reminders.reschedule([bill('a', DateTime(2026, 10, 27))]);
  });
}
