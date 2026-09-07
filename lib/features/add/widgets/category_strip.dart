import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../domain/models.dart';

/// Single source of truth mapping an English icon name (as stored in
/// `Categories.iconName`/`Subcategories.iconName`) to the Material icon it
/// renders as. Every category and subcategory seeded into the app, plus a
/// further set of general-purpose icons for categories/subcategories the
/// user adds themselves, lives here — the icon picker dialog offers exactly
/// [curatedIconNames], so [iconForName] is always able to resolve whatever
/// it hands back.
const Map<String, IconData> _iconsByName = {
  'local_drink': Icons.local_drink,
  'cookie': Icons.cookie,
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'receipt_long': Icons.receipt_long,
  'content_cut': Icons.content_cut,
  'shopping_bag': Icons.shopping_bag,
  'groups': Icons.groups,
  'card_giftcard': Icons.card_giftcard,
  'handshake': Icons.handshake,
  // Subcategory icon names (see `_seedSubcategoryRows` in
  // `lib/data/db/database.dart`) — mapped here too since the subcategory
  // chip row and the settings screen reuse this same lookup.
  'local_bar': Icons.local_bar,
  'water_drop': Icons.water_drop,
  'emoji_food_beverage': Icons.emoji_food_beverage,
  'local_cafe': Icons.local_cafe,
  'tapas': Icons.tapas,
  'cake': Icons.cake,
  'icecream': Icons.icecream,
  'fastfood': Icons.fastfood,
  'free_breakfast': Icons.free_breakfast,
  'lunch_dining': Icons.lunch_dining,
  'dinner_dining': Icons.dinner_dining,
  'local_grocery_store': Icons.local_grocery_store,
  'local_taxi': Icons.local_taxi,
  'smartphone': Icons.smartphone,
  'wifi': Icons.wifi,
  'spa': Icons.spa,
  'checkroom': Icons.checkroom,
  'devices': Icons.devices,
  'shopping_cart': Icons.shopping_cart,
  'flight': Icons.flight,
  'people': Icons.people,
  // General-purpose icons offered in the icon picker for categories and
  // subcategories the user creates themselves — not part of any seeded
  // row, but common enough to cover most of what a new category or
  // subcategory would need (e.g. "بيت", "رياضة", "صحة").
  'category_outlined': Icons.category_outlined,
  'home': Icons.home,
  'directions_car': Icons.directions_car,
  'pets': Icons.pets,
  'sports_soccer': Icons.sports_soccer,
  'fitness_center': Icons.fitness_center,
  'medical_services': Icons.medical_services,
  'school': Icons.school,
  'work': Icons.work,
  'savings': Icons.savings,
  'attach_money': Icons.attach_money,
  'celebration': Icons.celebration,
  'child_care': Icons.child_care,
  'movie': Icons.movie,
  'sports_esports': Icons.sports_esports,
  'book': Icons.book,
  'phone_android': Icons.phone_android,
  'local_hospital': Icons.local_hospital,
  'star': Icons.star,
};

/// Every icon name the icon picker dialog offers, in display order.
final List<String> curatedIconNames = _iconsByName.keys.toList();

/// Maps a category's stored `iconName` (an English string, e.g.
/// `local_drink`) to the Material icon shown for it. Falls back to a
/// generic icon for anything unrecognised, so a category never renders
/// with no icon at all.
IconData iconForName(String name) =>
    _iconsByName[name] ?? Icons.category_outlined;

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
              icon: Icons.apps,
              selected: selectedKey == null,
              onTap: () => onSelected(null),
            ),
            for (final category in categories)
              SelectableChip(
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
