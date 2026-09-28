import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/money.dart';

/// Shows this month's and last month's totals side by side, plus the
/// difference between them as a single signed figure.
///
/// The whole point of this card is that an overspend is visible the moment
/// it happens rather than discovered weeks later, so the difference is
/// never left to arithmetic: it is coloured [AppPalette.negative] the
/// instant this month is spending more than last month did, and
/// [AppPalette.positive] when it is spending less.
class MonthComparisonCard extends StatelessWidget {
  final int thisMonthPiastres;
  final int lastMonthPiastres;
  final VoidCallback? onTap;

  const MonthComparisonCard({
    super.key,
    required this.thisMonthPiastres,
    required this.lastMonthPiastres,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final diff = thisMonthPiastres - lastMonthPiastres;
    final Color diffColor;
    if (diff > 0) {
      diffColor = palette.negative;
    } else if (diff < 0) {
      diffColor = palette.positive;
    } else {
      diffColor = palette.textSecondary;
    }
    // formatPiastres already prefixes a negative amount with "-"; a rise
    // needs its own "+" so an increase is never mistaken for a plain
    // number, since the whole point of this card is that it reads at a
    // glance without doing arithmetic.
    final diffText =
        diff > 0 ? '+${formatPiastres(diff)}' : formatPiastres(diff);

    return Material(
      color: palette.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MonthColumn(
                      label: 'الشهر ده',
                      amountPiastres: thisMonthPiastres,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: palette.divider,
                  ),
                  Expanded(
                    child: _MonthColumn(
                      label: 'الشهر اللي فات',
                      amountPiastres: lastMonthPiastres,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                diffText,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(
                  color: diffColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthColumn extends StatelessWidget {
  final String label;
  final int amountPiastres;

  const _MonthColumn({required this.label, required this.amountPiastres});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: AppText.caption
                .copyWith(color: context.palette.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Text(formatPiastres(amountPiastres), style: AppText.title),
      ],
    );
  }
}
