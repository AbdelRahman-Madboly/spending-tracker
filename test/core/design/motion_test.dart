import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/tokens.dart';

void main() {
  test('motion tokens follow spec §7.3', () {
    expect(AppMotion.press, const Duration(milliseconds: 120));
    expect(AppMotion.chip, const Duration(milliseconds: 200));
    expect(AppMotion.sheet, const Duration(milliseconds: 280));
    expect(AppMotion.countUp, const Duration(milliseconds: 400));
    expect(AppMotion.enter, Curves.easeOutCubic);
    expect(AppMotion.exit, Curves.easeInCubic);
  });

  Future<Duration> resolved(WidgetTester tester, bool disable) async {
    late Duration result;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: disable),
      child: Builder(builder: (context) {
        result = AppMotion.of(context, AppMotion.countUp);
        return const SizedBox();
      }),
    ));
    return result;
  }

  testWidgets('keeps the duration when animations are on', (tester) async {
    expect(await resolved(tester, false), AppMotion.countUp);
  });

  testWidgets('drops every duration to zero when animations are off',
      (tester) async {
    expect(await resolved(tester, true), Duration.zero);
  });
}
