import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/category_colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../domain/models.dart';

/// A transaction row (spec §4.3): the category circle on the start side,
/// the name over a caption in the middle, the amount on the end side.
class EntryRow extends StatelessWidget {
  final EntryView entry;

  /// The entry's category, for its icon and colour. Null (an archived or
  /// unknown category) draws the neutral `Other` ink.
  final CategoryView? category;
  final VoidCallback? onTap;

  const EntryRow({super.key, required this.entry, this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colorKey = category?.colorKey ?? 'Other';
    final name =
        entry.displayName.isNotEmpty ? entry.displayName : entry.categoryLabelAr;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.categoryInkFill(colorKey),
                shape: BoxShape.circle,
              ),
              child: Icon(iconFor(category?.iconName ?? ''),
                  size: 20, color: palette.categoryInk(colorKey)),
            ),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body),
                  Text(
                    entry.categoryLabelAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.caption.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatPiastres(entry.amountPiastres),
              textDirection: TextDirection.ltr,
              style: AppText.bodyStrong,
            ),
          ],
        ),
      ),
    );
  }
}
