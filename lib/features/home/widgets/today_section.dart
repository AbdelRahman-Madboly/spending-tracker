import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../domain/models.dart';
import '../../transactions/widgets/entry_row.dart';
import 'section_card.dart';

/// Today's total, its number of entries and the last three of them, or the
/// empty state inviting the first one.
///
/// A row that arrives after the section first showed (a save from the add
/// sheet) slides up 8dp and fades in; the rows already there on first load
/// just appear.
class TodaySection extends StatefulWidget {
  final List<EntryView> entries;
  final Map<String, CategoryView> categories;
  final VoidCallback onSeeAll;
  final VoidCallback onAdd;

  const TodaySection({
    super.key,
    required this.entries,
    required this.categories,
    required this.onSeeAll,
    required this.onAdd,
  });

  @override
  State<TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends State<TodaySection> {
  late final Set<String> _initialIds = {
    for (final e in widget.entries) e.id,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = widget.entries;
    final total = entries.fold<int>(0, (sum, e) => sum + e.amountPiastres);
    final duration = AppMotion.of(context, AppMotion.chip);

    return SectionCard(
      key: const Key('today-section'),
      title: 'النهارده',
      seeAllKey: const Key('today-see-all'),
      onSeeAll: entries.isEmpty ? null : widget.onSeeAll,
      child: entries.isEmpty
          ? EmptyState(
              icon: AppIcons.emptyReceipt,
              headline: 'مفيش مصاريف النهارده',
              caption: 'سجّل اللي صرفته أول بأول',
              actionLabel: 'أضف أول مصروف',
              onAction: widget.onAdd,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      formatPiastres(total),
                      textDirection: TextDirection.ltr,
                      style: AppText.headline,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${entries.length} مصروف',
                      style: AppText.label
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final entry in entries.take(3))
                  TweenAnimationBuilder<double>(
                    key: ValueKey(entry.id),
                    tween: Tween(
                        begin: _initialIds.contains(entry.id) ? 1 : 0, end: 1),
                    duration: duration,
                    curve: AppMotion.enter,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: EntryRow(
                      entry: entry,
                      category: widget.categories[entry.categoryKey],
                    ),
                  ),
              ],
            ),
    );
  }
}
