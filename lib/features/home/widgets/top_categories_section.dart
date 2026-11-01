import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/category_colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../domain/dashboard.dart';
import '../../../domain/models.dart';
import 'section_card.dart';

/// The five biggest categories of the selected period as horizontal bars
/// in each category's own colour, with the amount and the share written
/// out, so colour is never the only thing telling them apart.
class TopCategoriesSection extends StatelessWidget {
  final List<CategoryShare> shares;
  final Map<String, CategoryView> categories;
  final VoidCallback onSeeAll;

  const TopCategoriesSection({
    super.key,
    required this.shares,
    required this.categories,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SectionCard(
      key: const Key('top-categories-section'),
      title: 'أكتر الأقسام',
      seeAllKey: const Key('top-categories-see-all'),
      onSeeAll: onSeeAll,
      child: shares.isEmpty
          ? const EmptyState(
              icon: AppIcons.stats,
              headline: 'لسه مفيش صرف',
              caption: 'الأقسام هتظهر هنا أول ما تسجّل مصروف',
            )
          : Column(
              children: [
                for (final share in shares)
                  _ShareRow(
                    share: share,
                    category: categories[share.categoryKey],
                    palette: palette,
                  ),
              ],
            ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final CategoryShare share;
  final CategoryView? category;
  final AppPalette palette;

  const _ShareRow({
    required this.share,
    required this.category,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final colorKey = category?.colorKey ?? 'Other';
    final ink = palette.categoryInk(colorKey);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(iconFor(category?.iconName ?? ''), size: 20, color: ink),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(category?.labelAr ?? share.categoryKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body),
              ),
              Text(
                formatPiastres(share.amountPiastres),
                textDirection: TextDirection.ltr,
                style: AppText.bodyStrong,
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 44,
                child: Text(
                  '${share.percent}%',
                  textAlign: TextAlign.end,
                  textDirection: TextDirection.ltr,
                  style:
                      AppText.label.copyWith(color: palette.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              value: share.percent / 100,
              minHeight: 8,
              color: ink,
              backgroundColor: palette.surfaceAlt,
            ),
          ),
        ],
      ),
    );
  }
}
