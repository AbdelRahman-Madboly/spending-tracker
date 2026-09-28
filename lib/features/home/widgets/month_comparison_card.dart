import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../domain/dashboard.dart';

/// One sentence comparing this month so far with last month up to the same
/// day, with an arrow: down and positive when spending less, up and
/// negative when spending more. Tapping it opens statistics.
class MonthComparisonCard extends StatelessWidget {
  final MonthComparison comparison;
  final VoidCallback? onTap;

  const MonthComparisonCard({super.key, required this.comparison, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, colour) = switch (comparison.direction) {
      ComparisonDirection.less => (AppIcons.trendDown, palette.positive),
      ComparisonDirection.more => (AppIcons.trendUp, palette.negative),
      ComparisonDirection.same => (AppIcons.trendFlat, palette.textSecondary),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: palette.cardShadow,
      ),
      child: Material(
        key: const Key('month-comparison'),
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: palette.cardBorder,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon, color: colour),
                  const SizedBox(width: AppSpacing.ms),
                  Expanded(
                    child: Text(comparison.sentence, style: AppText.bodyStrong),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
