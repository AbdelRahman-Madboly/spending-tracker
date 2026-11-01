import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';

/// One dashboard section: a level-1 card with a title row and an optional
/// "عرض الكل" action on the end side.
class SectionCard extends StatelessWidget {
  final String title;

  /// Shown next to the title, such as the needs-review count badge.
  final Widget? badge;

  /// Key of the "عرض الكل" button, which only exists when [onSeeAll] does.
  final Key? seeAllKey;
  final VoidCallback? onSeeAll;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.badge,
    this.seeAllKey,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.fromBorderSide(palette.cardBorder),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                // Flexible, so a long title on a narrow phone ellipsizes
                // rather than pushing عرض الكل off the card.
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title),
                ),
                if (badge != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  badge!,
                ],
                const Spacer(),
                if (onSeeAll != null)
                  TextButton(
                    key: seeAllKey,
                    onPressed: onSeeAll,
                    child: const Text('عرض الكل'),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A small primary pill holding a count.
class CountBadge extends StatelessWidget {
  final int count;

  const CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: palette.onPrimary),
      ),
    );
  }
}
