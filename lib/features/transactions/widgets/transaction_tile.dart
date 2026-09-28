import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/category_colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../domain/models.dart';
import '../../../domain/transactions.dart';

/// A row of السجل (spec §4.3), 64dp: the category circle on the start
/// side; the name over a caption of subcategory · time and the attachment
/// glyphs in the middle; the amount on the end side. While selected, the
/// circle becomes a check and the row takes the primary container colour.
class TransactionTile extends StatelessWidget {
  final TransactionView entry;

  /// For the circle's icon and colour; null draws the neutral `Other` ink.
  final CategoryView? category;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionTile({
    super.key,
    required this.entry,
    this.category,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = [
      if (entry.subcategoryLabelAr case final sub? when sub.isNotEmpty) sub,
      formatClock(entry.createdAt),
    ].join(' · ');
    return _RowFrame(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      leading: selected
          ? _SelectedCircle(palette: palette)
          : CategoryCircle(category: category),
      title: entry.name,
      caption: Row(
        children: [
          Flexible(
            child: Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: palette.textSecondary),
            ),
          ),
          for (final glyph in attachmentGlyphs(entry))
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
              child: Icon(glyph, size: 16, color: palette.textSecondary),
            ),
        ],
      ),
      amountPiastres: entry.amountPiastres,
    );
  }
}

/// The caption's glyphs, in the spec's order: `image`, `graphic_eq`,
/// `edit_note`, `barcode`.
List<IconData> attachmentGlyphs(TransactionView entry) => [
  if (entry.attachmentKinds.contains(AttachmentKind.photo)) AppIcons.gallery,
  if (entry.attachmentKinds.contains(AttachmentKind.voice)) AppIcons.voiceNote,
  if (entry.attachmentKinds.contains(AttachmentKind.text)) AppIcons.textNote,
  if (entry.source == EntrySource.barcode) AppIcons.barcode,
];

/// The 40dp category circle: the ink at 12% (20% in dark), the glyph in
/// the ink (spec §7.2).
class CategoryCircle extends StatelessWidget {
  final CategoryView? category;

  const CategoryCircle({super.key, this.category});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colorKey = category?.colorKey ?? 'Other';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.categoryInkFill(colorKey),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconFor(category?.iconName ?? ''),
        size: 20,
        color: palette.categoryInk(colorKey),
      ),
    );
  }
}

class _SelectedCircle extends StatelessWidget {
  final AppPalette palette;

  const _SelectedCircle({required this.palette});

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle),
    child: Icon(
      AppIcons.checkCircle,
      size: 24,
      fill: 1,
      color: palette.onPrimary,
    ),
  );
}

/// The shared layout of a row and a capture group's parent row.
class _RowFrame extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget leading;
  final String title;
  final Widget caption;
  final int amountPiastres;
  final Widget? trailing;

  const _RowFrame({
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.leading,
    required this.title,
    required this.caption,
    required this.amountPiastres,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: AppSpacing.ms),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body,
                      ),
                      caption,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  formatPiastres(amountPiastres),
                  textDirection: TextDirection.ltr,
                  style: AppText.bodyStrong,
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A capture group's parent row (spec §4.3): the group title, the summed
/// amount and an expand chevron; expanded, its lines sit indented below.
class CaptureGroupTile extends StatefulWidget {
  final CaptureGroupRow row;

  /// The group's category circle: its first line's category.
  final CategoryView? category;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Builds each line when expanded, so the list can wrap it in its own
  /// swipe and selection handling.
  final Widget Function(BuildContext context, TransactionView line) lineBuilder;

  const CaptureGroupTile({
    super.key,
    required this.row,
    required this.lineBuilder,
    this.category,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<CaptureGroupTile> createState() => _CaptureGroupTileState();
}

class _CaptureGroupTileState extends State<CaptureGroupTile> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final row = widget.row;
    final first = row.lines.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyedSubtree(
          key: Key('group-row-${row.captureGroupId}'),
          child: _RowFrame(
            selected: widget.selected,
            onTap: widget.onTap ?? _toggle,
            onLongPress: widget.onLongPress,
            leading: widget.selected
                ? _SelectedCircle(palette: palette)
                : CategoryCircle(category: widget.category),
            title: row.title,
            caption: Text(
              '${row.lines.length} بنود · ${formatClock(first.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: palette.textSecondary),
            ),
            amountPiastres: row.totalPiastres,
            trailing: IconButton(
              key: Key('group-expand-${row.captureGroupId}'),
              tooltip: _expanded ? 'إخفاء البنود' : 'عرض البنود',
              onPressed: _toggle,
              icon: Icon(
                _expanded ? AppIcons.expandLess : AppIcons.expandMore,
                size: 24,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.chip),
          curve: AppMotion.enter,
          alignment: AlignmentDirectional.topStart,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final line in row.lines)
                        widget.lineBuilder(context, line),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
