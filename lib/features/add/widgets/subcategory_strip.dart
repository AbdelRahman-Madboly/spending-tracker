import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../domain/models.dart';
import 'category_strip.dart' show SelectableChip;

/// The second chip row: revealed only once a real category (not "الكل") is
/// selected in the category strip above it. Mirrors that strip's shape
/// exactly — a leading "الكل" chip meaning "the whole category, no
/// subcategory filter" plus one chip per subcategory — so depth is
/// available without ever being imposed: the row simply does not exist
/// until the user opts into a category, and the two-tap quick-pick path at
/// the top level never has to make room for it.
class SubcategoryStrip extends StatelessWidget {
  final List<SubcategoryView> subcategories;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  /// The parent category's colour, which its subcategory chips share.
  final String? colorKey;

  const SubcategoryStrip({
    this.colorKey,
    super.key,
    required this.subcategories,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
        child: Row(
          children: [
            SelectableChip(
              key: const Key('subcategory-all'),
              label: 'الكل',
              icon: AppIcons.all,
              selected: selectedKey == null,
              onTap: () => onSelected(null),
            ),
            for (final subcategory in subcategories)
              SelectableChip(
                key: Key('subcategory-${subcategory.key}'),
                label: subcategory.labelAr,
                icon: iconFor(subcategory.iconName),
                colorKey: colorKey,
                selected: selectedKey == subcategory.key,
                onTap: () => onSelected(subcategory.key),
              ),
          ],
        ),
      ),
    );
  }
}
