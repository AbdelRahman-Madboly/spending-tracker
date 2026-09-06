import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';

void main() {
  testWidgets('shows twelve quick pick items and five capture icons',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('شويبس'), findsOneWidget);
    expect(find.byKey(const Key('capture-icons')), findsOneWidget);
  });

  testWidgets('tapping an item submits a complete draft in one tap',
      (tester) async {
    DraftEntry? captured;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: FixtureSpendingRepository(),
            onSubmit: (d) => captured = d,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('شويبس'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.amountPiastres, 4000);
    expect(captured!.categoryKey, 'Food/Social');
    expect(captured!.source, EntrySource.quickPick);
    expect(captured!.isComplete, isTrue);
  });
}
