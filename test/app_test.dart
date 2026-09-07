import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/app.dart';
import 'package:spending_tracker/core/design/tokens.dart';

void main() {
  test(
      'buildAppTheme wires AppColors into the colour scheme so Material 3 '
      'defaults never leak through', () {
    final theme = buildAppTheme();

    expect(theme.colorScheme.primary, AppColors.accent);
    expect(theme.colorScheme.onPrimary, Colors.white);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.onSurface, AppColors.textPrimary);
    expect(theme.colorScheme.error, AppColors.negative);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  testWidgets('app renders right-to-left in Arabic', (tester) async {
    await tester.pumpWidget(const SpendingApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context).languageCode, 'ar');

    // SpendingApp owns a real drift database. Unmount it here (rather than
    // letting the test harness tear the tree down once this callback
    // returns) and pump once more so dispose() can close the database and
    // drift's internal stream-cleanup timer fires before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
