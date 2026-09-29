import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/app_flavor.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/instapay_identity.dart';
import 'package:spending_tracker/features/home/home_screen.dart';
import 'package:spending_tracker/features/shell/app_shell.dart';

typedef _Salary = ({DateTime datePaid, int amountPiastres});

class _Repo extends FixtureSpendingRepository {
  final salaries = <_Salary>[];

  @override
  Future<void> addSalaryPeriod({
    required DateTime datePaid,
    required int amountPiastres,
    String? note,
    String? evidencePhotoPath,
    String? externalId,
  }) async {
    await super.addSalaryPeriod(
      datePaid: datePaid,
      amountPiastres: amountPiastres,
      note: note,
    );
    salaries.add((datePaid: datePaid, amountPiastres: amountPiastres));
  }
}

DateTime _now() => DateTime(2026, 10, 2, 12);

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  Future<void> pump(WidgetTester tester, {bool offerWelcome = true}) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(
            repository: repo,
            clock: _now,
            offerWelcome: offerWelcome,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asks a new user for the salary, and saves it as paid today', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('welcome-card')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('welcome-salary')), '8,500');
    await tester.enterText(
      find.byKey(const Key('welcome-instapay')),
      'sara.a@instapay',
    );
    await tester.tap(find.byKey(const Key('welcome-save')));
    await tester.pumpAndSettle();

    expect(repo.salaries, [
      (datePaid: DateTime(2026, 10, 2), amountPiastres: 850000),
    ]);
    expect(await repo.setting(instaPayIdentitySettingKey), 'sara.a@instapay');
    expect(await repo.setting(welcomeDoneSettingKey), isNotNull);
    expect(find.byKey(const Key('welcome-card')), findsNothing);
  });

  testWidgets('the pay date can be an earlier day', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('welcome-salary')), '6000');
    await tester.tap(find.byKey(const Key('welcome-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('27'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-save')));
    await tester.pumpAndSettle();

    expect(repo.salaries, [
      (datePaid: DateTime(2026, 9, 27), amountPiastres: 600000),
    ]);
  });

  testWidgets('a salary that is no amount is refused, nothing saved', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('welcome-salary')), 'كتير');
    await tester.tap(find.byKey(const Key('welcome-save')));
    await tester.pumpAndSettle();
    expect(repo.salaries, isEmpty);
    expect(find.byKey(const Key('welcome-card')), findsOneWidget);
    expect(await repo.setting(welcomeDoneSettingKey), isNull);
  });

  testWidgets('skipping saves nothing and never asks again', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('welcome-skip')));
    await tester.pumpAndSettle();
    expect(repo.salaries, isEmpty);
    expect(find.byKey(const Key('welcome-card')), findsNothing);

    await pump(tester);
    expect(find.byKey(const Key('welcome-card')), findsNothing);
  });

  testWidgets('the personal build never shows it', (tester) async {
    await pump(tester, offerWelcome: false);
    expect(find.byKey(const Key('welcome-card')), findsNothing);
  });

  testWidgets('the shared build welcomes on the dashboard', (tester) async {
    AppFlavor.current = AppFlavor.shared;
    addTearDown(() => AppFlavor.current = AppFlavor.personal);
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AppShell(repository: repo, clock: _now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome-card')), findsOneWidget);
  });
}
