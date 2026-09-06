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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('باقي ${summary.daysRemaining} يوم', style: AppText.caption),
          const SizedBox(height: AppSpacing.md),
          Text(
            formatPiastres(left),
            style: AppText.hero.copyWith(
              color: overspent ? AppColors.negative : AppColors.textPrimary,
            ),
          ),
          Text('الباقي', style: AppText.caption),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('صرفت ', style: AppText.caption),
              Text(formatPiastres(summary.spentPiastres), style: AppText.body),
              Text('  من ${formatPiastres(summary.salaryPiastres)}',
                  style: AppText.caption),
            ],
          ),
          if (safeDaily != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('تقدر تصرف ${formatPiastres(safeDaily)} في اليوم',
                style: AppText.caption),
          ],
        ],
      ),
    );
  }
}
