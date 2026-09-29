import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/spending_repository.dart';

/// Paying a recurring bill, against both repositories.
void main() {
  for (final (name, create) in <(String, Future<SpendingRepository> Function())>[
    (
      'drift',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        return DriftSpendingRepository(db);
      }
    ),
    ('fixture', () async => FixtureSpendingRepository()),
  ]) {
    group('$name payRecurringBill', () {
      late SpendingRepository repo;
      setUp(() async => repo = await create());

      test('writes the entry on the paid day and moves nextDue on', () async {
        final bill = await repo.createRecurringBill(
          nameAr: 'باقة إنترنت المنزل',
          amountPiastres: 30000,
          categoryKey: 'Bills',
          subcategoryKey: 'HomeInternet',
          nextDue: DateTime(2026, 10, 27),
        );
        final paid = await repo.payRecurringBill(bill.id, DateTime(2026, 10, 26));

        expect(paid.nextDue, DateTime(2026, 11, 27));
        expect((await repo.recurringBills()).single.nextDue,
            DateTime(2026, 11, 27));

        final entries = (await repo.watchTransactions().first)
            .where((t) => t.description == 'باقة إنترنت المنزل')
            .toList();
        expect(entries, hasLength(1));
        final entry = (await repo.entry(entries.single.id))!;
        expect(entry.date, DateTime(2026, 10, 26));
        expect(entry.amountPiastres, 30000);
        expect(entry.categoryKey, 'Bills');
        expect(entry.subcategoryKey, 'HomeInternet');
        expect(await repo.spentBetween(
            DateTime(2026, 10, 26), DateTime(2026, 10, 26)), 30000);
      });

      test('every few months moves by everyMonths', () async {
        final bill = await repo.createRecurringBill(
          nameAr: 'تأمين',
          amountPiastres: 90000,
          categoryKey: 'Bills',
          everyMonths: 3,
          nextDue: DateTime(2026, 11, 15),
        );
        final paid = await repo.payRecurringBill(bill.id, DateTime(2026, 11, 15));
        expect(paid.nextDue, DateTime(2027, 2, 15));
      });

      test('paying twice pays two due dates in turn', () async {
        final bill = await repo.createRecurringBill(
          nameAr: 'فاتورة موبايل',
          amountPiastres: 17000,
          categoryKey: 'Bills',
          nextDue: DateTime(2026, 10, 7),
        );
        await repo.payRecurringBill(bill.id, DateTime(2026, 10, 7));
        await repo.payRecurringBill(bill.id, DateTime(2026, 10, 8));
        final entries = (await repo.watchTransactions().first)
            .where((t) => t.description == 'فاتورة موبايل');
        expect(entries, hasLength(2));
        expect((await repo.recurringBills()).single.nextDue,
            DateTime(2026, 12, 7));
      });

      test('a stale due date (a double tap) is refused and writes nothing',
          () async {
        final bill = await repo.createRecurringBill(
          nameAr: 'فاتورة موبايل',
          amountPiastres: 17000,
          categoryKey: 'Bills',
          nextDue: DateTime(2026, 10, 7),
        );
        await repo.payRecurringBill(bill.id, DateTime(2026, 10, 7),
            expectedDue: bill.nextDue);
        await expectLater(
            repo.payRecurringBill(bill.id, DateTime(2026, 10, 7),
                expectedDue: bill.nextDue),
            throwsStateError);
        final entries = (await repo.watchTransactions().first)
            .where((t) => t.description == 'فاتورة موبايل');
        expect(entries, hasLength(1));
        expect((await repo.recurringBills()).single.nextDue,
            DateTime(2026, 11, 7));
      });

      test('an archived or unknown bill cannot be paid', () async {
        final bill = await repo.createRecurringBill(
          nameAr: 'قديمة',
          amountPiastres: 100,
          categoryKey: 'Bills',
          nextDue: DateTime(2026, 10, 1),
        );
        await repo.archiveRecurringBill(bill.id);
        await expectLater(
            repo.payRecurringBill(bill.id, DateTime(2026, 10, 1)),
            throwsStateError);
        await expectLater(repo.payRecurringBill('nope', DateTime(2026, 10, 1)),
            throwsStateError);
      });
    });
  }
}
