import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/tokens.dart';

void main() {
  test('spacing scale ascends on a 4pt grid', () {
    expect(AppSpacing.xs, 4.0);
    expect(AppSpacing.sm, 8.0);
    expect(AppSpacing.md, 16.0);
    expect(AppSpacing.lg, 24.0);
    expect(AppSpacing.xl, 32.0);
  });

  test('hero text is the largest style and uses tabular figures', () {
    expect(AppText.hero.fontSize, greaterThan(AppText.title.fontSize!));
    expect(AppText.hero.fontFeatures,
        contains(const FontFeature.tabularFigures()));
  });

  test('negative and positive colours are distinguishable', () {
    expect(AppColors.negative, isNot(AppColors.positive));
  });
}
