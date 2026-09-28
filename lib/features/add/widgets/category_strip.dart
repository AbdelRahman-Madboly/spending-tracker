import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../domain/models.dart';

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
            SelectableChip(
              key: const Key('category-all'),
              label: 'الكل',
              icon: AppIcons.all,
              selected: selectedKey == null,
              onTap: () => onSelected(null),
            ),
            for (final category in categories)
              SelectableChip(
                key: Key('category-${category.key}'),
                label: category.labelAr,
                icon: iconFor(category.iconName),
                selected: selectedKey == category.key,
                onTap: () => onSelected(category.key),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single chip in a filter row — used by both [CategoryStrip] and
/// `SubcategoryStrip` so the 48dp minimum tap target and visual style stay
/// identical between the two rows.
class SelectableChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const SelectableChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
      child: Material(
        // surfaceAlt, not surface: the strip sits on the add sheet, which
        // is itself surface.
        color: selected ? palette.primary : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.full),
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
                  // Filled only when selected (spec §7.2).
                  fill: selected ? 1 : 0,
                  color: selected ? palette.onPrimary : palette.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppText.body.copyWith(
                    color: selected ? palette.onPrimary : palette.textPrimary,
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
