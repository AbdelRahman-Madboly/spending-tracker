import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';

/// Regression test for a first-launch bug: the home screen briefly showed
/// "0 يوم" / a zero balance / "صرفت 0 من 0" on a fresh install, recovering
/// only after a full app restart. The cause was seeding the real data as a
/// fire-and-forget call made *after* AppDatabase was constructed, racing
/// independently against whichever query the UI issued first.
///
/// The fix moves seeding into AppDatabase's own `onCreate`, so it is part
/// of *opening* the database — drift guarantees no query (a one-shot
/// `Future` or a `.watch()` stream's first emission) can run until that
/// finishes. This test proves it by subscribing to all three
/// repository surfaces the app depends on (the period summary stream, the
/// day-entries stream, and the one-shot topItems query used by the add
/// sheet) immediately, exactly as `app.dart` does, with an artificially
/// slow seed loader standing in for the real asynchronous asset read. A
/// test that awaits seeding before subscribing would not catch this — the
/// whole point is the subscribe-before-seed-completes ordering.
void main() {
  const seedJson = '''
  {
    "items": [
      {
        "id": "item-01",
        "nameAr": "تجربة",
        "nameEn": "test item",
        "categoryKey": "Food",
        "defaultAmountPiastres": 1000,
        "barcode": null,
        "useCount": 3,
        "lastUsedAt": "2026-08-01T00:00:00.000",
        "archived": false
      }
    ],
    "entries": [
      {
        "id": "entry-001",
        "date": "2026-08-01",
        "amountPiastres": 1000,
        "categoryKey": "Food",
        "itemId": "item-01",
        "description": "test entry",
        "paymentMethod": "Cash",
        "photoPath": null,
        "source": "manual",
        "note": null,
        "createdAt": "2026-08-01T00:00:00.000",
        "updatedAt": "2026-08-01T00:00:00.000",
        "deletedAt": null
      }
    ],
    "salaryPeriods": [
      {
        "id": "sp-1",
        "datePaid": "2026-08-02",
        "amountPiastres": 900000,
        "evidencePhotoPath": null,
        "note": null
      }
    ]
  }
  ''';

  test(
      'watchCurrentPeriod, watchEntriesForDay and topItems all reflect the '
      'seed on their very first result, even when subscribed before a slow '
      'seed load finishes', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      // Stands in for the real rootBundle.loadString('assets/seed/...')
      // asset read, which is genuinely asynchronous. If seeding were still
      // a separate fire-and-forget call racing against the queries below
      // (the pre-fix design), this delay would make the race obvious;
      // with seeding inside onCreate, drift makes every query below wait
      // for this to finish before it can run at all.
      seedJsonLoader: () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return seedJson;
      },
    );
    addTearDown(db.close);
    final repo = DriftSpendingRepository(db);

    // Subscribe to everything immediately — no manual "wait for seeding"
    // step, exactly like the widgets in app.dart / home_screen.dart do.
    final results = await Future.wait([
      repo.watchCurrentPeriod().first,
      repo.watchEntriesForDay(DateTime(2026, 8, 1)).first,
      repo.topItems(12),
    ]);

    final summary = results[0] as PeriodSummary;
    final dayEntries = results[1] as List<EntryView>;
    final quickPicks = results[2] as List<QuickPickItem>;

    expect(
      summary.salaryPiastres,
      900000,
      reason: 'the first period-summary emission read a zero salary — the '
          'exact bug this test guards against',
    );
    expect(
      dayEntries,
      isNotEmpty,
      reason: 'watchEntriesForDay returned empty on its first emission',
    );
    expect(
      quickPicks,
      isNotEmpty,
      reason: 'topItems (used by the add sheet) returned an empty grid on '
          'its first call',
    );
  });
}
