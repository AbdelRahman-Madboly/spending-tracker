import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../domain/models.dart';

class PeriodSummaryCard extends StatelessWidget {
  final PeriodSummary summary;

  const PeriodSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final left = summary.leftPiastres;
    final overspent = left < 0;
    final safeDaily = summary.safeDailyPiastres;
    final palette = context.palette;
    final caption = AppText.caption.copyWith(color: palette.textSecondary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // A late salary drives daysRemaining negative; showing "-13 days left"
          // is nonsense, so the count floors at zero.
          Text(
            'باقي ${summary.daysRemaining < 0 ? 0 : summary.daysRemaining} يوم',
            style: caption,
          ),
          const SizedBox(height: AppSpacing.md),
          // The hero figure is the largest thing on screen and nothing upstream
          // bounds its width. scaleDown shrinks an unusually long amount instead
          // of overflowing; ordinary amounts render unchanged.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatPiastres(left),
              maxLines: 1,
              style: AppText.display.copyWith(
                color: overspent ? palette.negative : palette.textPrimary,
              ),
            ),
          ),
          Text('الباقي', style: caption),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('صرفت ', style: caption),
              Text(formatPiastres(summary.spentPiastres), style: AppText.body),
              Text('  من ${formatPiastres(summary.salaryPiastres)}',
                  style: caption),
            ],
          ),
          if (safeDaily != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('تقدر تصرف ${formatPiastres(safeDaily)} في اليوم',
                style: caption),
          ],
        ],
      ),
    );
  }
}
