import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/data/bill_reminders.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/bills.dart';
import 'package:spending_tracker/features/settings/recurring_bills_screen.dart';
import 'package:spending_tracker/features/settings/settings_screen.dart';

import '../../data/bill_reminders_test.dart' show FakeNotifier;

void main() {
  final today = DateTime(2026, 9, 29, 12);

  Future<(FixtureSpendingRepository, FakeNotifier)> pump(
    WidgetTester tester, {
    FixtureSpendingRepository? repository,
    bool asked = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final repo = repository ?? FixtureSpendingRepository();
    if (asked) {
      await repo.setSetting(billRemindersPermissionAskedSettingKey, '1');
    }
    final notifier = FakeNotifier();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RecurringBillsScreen(
          repository: repo,
          reminders: BillReminders(notifier, clock: () => today),
          clock: () => today,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (repo, notifier);
  }

  testWidgets('lists live bills with amount and due date', (tester) async {
    final repo = FixtureSpendingRepository();
    await repo.createRecurringBill(
      nameAr: 'فاتورة موبايل',
      amountPiastres: 17000,
      categoryKey: 'Bills',
      nextDue: DateTime(2026, 10, 7),
    );
    await pump(tester, repository: repo);
    expect(find.text('فاتورة موبايل'), findsOneWidget);
    expect(find.textContaining('170'), findsWidgets);
    expect(find.textContaining('الجاية 7 أكتوبر'), findsOneWidget);
  });

  testWidgets('adds a bill through the editor and schedules its reminder',
      (tester) async {
    final (repo, notifier) = await pump(tester);
    await tester.tap(find.byKey(const Key('add-bill')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bill-name')), 'جيم');
    await tester.enterText(find.byKey(const Key('bill-amount')), '300');
    await tester.enterText(find.byKey(const Key('bill-day')), '15');
    await tester.tap(find.byKey(const Key('bill-save')));
    await tester.pumpAndSettle();

    final bills = await repo.recurringBills();
    expect(bills, hasLength(1));
    expect(bills.single.nameAr, 'جيم');
    expect(bills.single.amountPiastres, 30000);
    expect(bills.single.nextDue, DateTime(2026, 10, 15));
    expect(bills.single.remindDaysBefore, 2);
    expect(find.text('جيم'), findsOneWidget);
    expect(notifier.scheduled.single.at, DateTime(2026, 10, 13, 10));
  });

  testWidgets('the editor refuses an empty name or a bad amount',
      (tester) async {
    final (repo, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('add-bill')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bill-amount')), 'abc');
    await tester.tap(find.byKey(const Key('bill-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bill-save')), findsOneWidget);
    expect(await repo.recurringBills(), isEmpty);
  });

  testWidgets('edits a bill in place', (tester) async {
    final repo = FixtureSpendingRepository();
    final bill = await repo.createRecurringBill(
      nameAr: 'فاتورة موبايل',
      amountPiastres: 17000,
      categoryKey: 'Bills',
      nextDue: DateTime(2026, 10, 7),
    );
    await pump(tester, repository: repo);
    await tester.tap(find.byKey(ValueKey('bill-${bill.id}')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('bill-amount')))
            .controller!
            .text,
        '170');
    await tester.enterText(find.byKey(const Key('bill-amount')), '185');
    await tester.tap(find.byKey(const Key('bill-save')));
    await tester.pumpAndSettle();
    final saved = (await repo.recurringBills()).single;
    expect(saved.id, bill.id);
    expect(saved.amountPiastres, 18500);
    expect(saved.nextDue, DateTime(2026, 10, 7));
  });

  testWidgets('دفعت writes the entry today and moves the bill a month on',
      (tester) async {
    final repo = FixtureSpendingRepository();
    final bill = await repo.createRecurringBill(
      nameAr: 'فاتورة موبايل',
      amountPiastres: 17000,
      categoryKey: 'Bills',
      nextDue: DateTime(2026, 10, 7),
    );
    await pump(tester, repository: repo);
    await tester.tap(find.byKey(ValueKey('bill-pay-${bill.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bill-pay-confirm')));
    await tester.pumpAndSettle();

    expect((await repo.recurringBills()).single.nextDue, DateTime(2026, 11, 7));
    final paid = (await repo.watchTransactions().first)
        .where((t) => t.description == 'فاتورة موبايل')
        .single;
    expect(paid.date, DateTime(2026, 9, 29));
    expect(paid.amountPiastres, 17000);
    expect(find.byKey(const Key('bill-paid-snackbar')), findsOneWidget);
  });

  testWidgets('archive hides the bill and تراجع brings it back',
      (tester) async {
    final repo = FixtureSpendingRepository();
    final bill = await repo.createRecurringBill(
      nameAr: 'فاتورة موبايل',
      amountPiastres: 17000,
      categoryKey: 'Bills',
      nextDue: DateTime(2026, 10, 7),
    );
    await pump(tester, repository: repo);
    await tester.tap(find.byKey(ValueKey('bill-archive-${bill.id}')));
    await tester.pumpAndSettle();
    expect(await repo.recurringBills(), isEmpty);
    expect(find.text('فاتورة موبايل'), findsNothing);

    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect((await repo.recurringBills()).single.id, bill.id);
    expect(find.text('فاتورة موبايل'), findsOneWidget);
  });

  testWidgets('suggests a home internet plan; أضف creates it', (tester) async {
    final (repo, _) = await pump(tester);
    const key = homeInternetSuggestionKey;
    expect(find.byKey(const ValueKey('suggestion-$key')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('suggestion-add-$key')));
    await tester.pumpAndSettle();
    final bill = (await repo.recurringBills()).single;
    expect(bill.amountPiastres, 30000);
    expect(bill.subcategoryKey, 'HomeInternet');
    expect(bill.nextDue, DateTime(2026, 10, 27));
    expect(find.byKey(const ValueKey('suggestion-$key')), findsNothing);
  });

  testWidgets('تجاهل remembers the dismissed suggestion', (tester) async {
    final (repo, _) = await pump(tester);
    const key = homeInternetSuggestionKey;
    await tester.tap(find.byKey(const ValueKey('suggestion-dismiss-$key')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suggestion-$key')), findsNothing);
    expect(
        decodeDismissedSuggestions(
            await repo.setting(dismissedBillSuggestionsSettingKey)),
        contains(key));
    expect(await repo.recurringBills(), isEmpty);
  });

  testWidgets('first use explains notifications before asking for them',
      (tester) async {
    final (repo, notifier) = await pump(tester, asked: false);
    expect(find.byKey(const Key('bills-permission-card')), findsOneWidget);
    expect(notifier.permissionRequests, 0);
    await tester.tap(find.byKey(const Key('bills-permission-allow')));
    await tester.pumpAndSettle();
    expect(notifier.permissionRequests, 1);
    expect(find.byKey(const Key('bills-permission-card')), findsNothing);
    expect(await repo.setting(billRemindersPermissionAskedSettingKey),
        isNotNull);
  });

  testWidgets('مش دلوقتي hides the card without asking', (tester) async {
    final (repo, notifier) = await pump(tester, asked: false);
    await tester.tap(find.byKey(const Key('bills-permission-later')));
    await tester.pumpAndSettle();
    expect(notifier.permissionRequests, 0);
    expect(find.byKey(const Key('bills-permission-card')), findsNothing);
    expect(await repo.setting(billRemindersPermissionAskedSettingKey),
        isNotNull);
  });

  testWidgets('Settings opens الفواتير المتكررة', (tester) async {
    tester.view.physicalSize = const Size(1080, 13200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final repo = FixtureSpendingRepository();
    await repo.setSetting(billRemindersPermissionAskedSettingKey, '1');
    final previous = BillReminders.shared;
    BillReminders.shared = BillReminders(FakeNotifier(), clock: () => today);
    addTearDown(() => BillReminders.shared = previous);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SettingsScreen(repository: repo),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-recurring-bills')));
    await tester.pumpAndSettle();
    expect(find.byType(RecurringBillsScreen), findsOneWidget);
    expect(find.byKey(const Key('add-bill')), findsOneWidget);
  });
}
