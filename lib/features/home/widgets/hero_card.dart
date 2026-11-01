import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../domain/dashboard.dart';
import '../../../domain/models.dart';

/// The dashboard's hero (spec §4.2, §7.3): what is left of the salary
/// period, the budget bar with a "today" tick, what was spent, the safe
/// daily allowance and the days left.
///
/// Everything on it is white or [AppPalette.heroSubtext] on the hero
/// gradient, which is dark in both modes, so it reads the same either way.
/// Overspent, the card turns to the red gradient and the safe daily figure
/// goes: there is no safe amount left to spend.
class HeroCard extends StatelessWidget {
  final PeriodSummary summary;

  const HeroCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final overspent = summary.leftPiastres < 0;
    final safeDaily = summary.safeDailyPiastres;
    final subtext = AppText.label.copyWith(color: palette.heroSubtext);
    final duration = AppMotion.of(context, AppMotion.countUp);
    // A late salary drives daysRemaining negative; "-13 days left" is
    // nonsense, so the count floors at zero.
    final daysLeft = summary.daysRemaining < 0 ? 0 : summary.daysRemaining;

    return Container(
      key: const Key('hero-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: overspent
              ? palette.heroGradientOverspent
              : palette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                  text: summary.isCurrent ? 'باقي $daysLeft يوم' : 'فترة منتهية'),
              const Spacer(),
              if (overspent)
                Icon(AppIcons.warning, color: palette.onHero, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('باقي', style: subtext),
          // The hero figure is the largest thing on screen and nothing
          // upstream bounds its width. scaleDown shrinks an unusually long
          // amount instead of overflowing.
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: summary.leftPiastres),
            duration: duration,
            curve: AppMotion.enter,
            builder: (context, value, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                formatPiastres(value),
                key: const Key('hero-left'),
                maxLines: 1,
                textDirection: TextDirection.ltr,
                style: AppText.display.copyWith(color: context.palette.onHero),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _BudgetBar(summary: summary, duration: duration),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'صرفت',
                  amountPiastres: summary.spentPiastres,
                ),
              ),
              if (safeDaily != null)
                Expanded(
                  child: _Stat(
                    label: 'تقدر تصرف/يوم',
                    amountPiastres: safeDaily,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.ms, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.palette.onHero.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(text, style: AppText.label.copyWith(color: context.palette.onHero)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int amountPiastres;

  const _Stat({required this.label, required this.amountPiastres});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.caption.copyWith(color: context.palette.heroSubtext)),
        Text(
          formatPiastres(amountPiastres),
          textDirection: TextDirection.ltr,
          style: AppText.bodyStrong.copyWith(color: context.palette.onHero),
        ),
      ],
    );
  }
}

/// 8dp, fully rounded, filling from the start side. The fill is positive
/// under 80% of the salary, warning from 80% and negative from 100%; the
/// 2dp tick marks how much of the period has gone by, so a fill past the
/// tick means spending ahead of the calendar. The percentage is always
/// written out as well: the bar alone relies on colour.
class _BudgetBar extends StatelessWidget {
  final PeriodSummary summary;
  final Duration duration;

  const _BudgetBar({required this.summary, required this.duration});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final percent = summary.spentPercent;
    final fill = switch (budgetLevel(percent)) {
      BudgetLevel.fine => palette.positive,
      BudgetLevel.warning => palette.warning,
      BudgetLevel.over => palette.negative,
    };
    final fraction = ((percent ?? 0) / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 14,
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  Container(
                    key: const Key('budget-bar-track'),
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.palette.onHero.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction),
                    duration: duration,
                    curve: AppMotion.enter,
                    builder: (context, value, _) => Container(
                      key: const Key('budget-bar-fill'),
                      height: 8,
                      width: width * value,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                    ),
                  ),
                  if (summary.isCurrent)
                    PositionedDirectional(
                      start: (width * summary.elapsedFraction - 1)
                          .clamp(0.0, width - 2),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        key: const Key('budget-bar-tick'),
                        width: 2,
                        color: context.palette.onHero,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          percent == null ? '–' : '$percent%',
          textDirection: TextDirection.ltr,
          style: AppText.label.copyWith(color: context.palette.onHero),
        ),
      ],
    );
  }
}
