import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/category_colors.dart';
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
                colorKey: category.colorKey,
                selected: selectedKey == category.key,
                onTap: () => onSelected(category.key),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single chip in a filter row (spec §7.3), used by both [CategoryStrip]
/// and `SubcategoryStrip` so the two rows look and behave the same.
///
/// The chip itself is 36dp tall inside a 48dp tap area. Selected, it takes
/// its category's ink: a 16% fill, a 1.5dp border and a check in place of
/// its icon. The border is always drawn (transparent when unselected) so
/// selecting a chip never nudges its neighbours. With no [colorKey] (the
/// "الكل" chips) the primary colour stands in for the ink.
class SelectableChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? colorKey;

  const SelectableChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.colorKey,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = colorKey == null
        ? palette.primary
        : palette.categoryInk(colorKey!);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.full),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.chip),
                curve: AppMotion.enter,
                height: 36,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.ms,
                ),
                decoration: BoxDecoration(
                  // surfaceAlt, not surface: the strip sits on the add
                  // sheet, which is itself surface.
                  color: selected
                      ? ink.withValues(alpha: 0.16)
                      : palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(
                    color: selected ? ink : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? AppIcons.check : icon,
                      size: 16,
                      color: selected ? ink : palette.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: AppText.label.copyWith(
                        color: palette.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
