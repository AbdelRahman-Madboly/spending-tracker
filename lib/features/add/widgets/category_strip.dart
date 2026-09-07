import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../domain/models.dart';

/// Maps a category's stored `iconName` (an English string, e.g.
/// `local_drink`) to the Material icon shown for it. Falls back to a
/// generic icon for anything unrecognised, so a category never renders
/// with no icon at all.
IconData iconForName(String name) {
  switch (name) {
    case 'local_drink':
      return Icons.local_drink;
    case 'cookie':
      return Icons.cookie;
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'content_cut':
      return Icons.content_cut;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'groups':
      return Icons.groups;
    case 'card_giftcard':
      return Icons.card_giftcard;
    case 'handshake':
      return Icons.handshake;
    default:
      return Icons.category_outlined;
  }
}

/// A horizontally scrolling strip of category chips, with a leading "الكل"
/// (all) chip. `selectedKey == null` means "الكل" is selected — the strip
/// never forces a real category on the user, so the most-used items across
/// every category (and the two-tap path to them) stay the default.
class CategoryStrip extends StatelessWidget {
  final List<CategoryView> categories;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  const CategoryStrip({
    super.key,
    required this.categories,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // A plain Row in a SingleChildScrollView (not ListView.builder) so every
    // chip is always built — there are only eleven of them, and the sheet's
    // own tests need to find a chip regardless of scroll position.
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
        child: Row(
          children: [
            _CategoryChip(
              key: const Key('category-all'),
              label: 'الكل',
              icon: Icons.apps,
              selected: selectedKey == null,
              onTap: () => onSelected(null),
            ),
            for (final category in categories)
              _CategoryChip(
                key: Key('category-${category.key}'),
                label: category.labelAr,
                icon: iconForName(category.iconName),
                selected: selectedKey == category.key,
                onTap: () => onSelected(category.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            // 48dp minimum tap target height, regardless of content.
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppText.body.copyWith(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
