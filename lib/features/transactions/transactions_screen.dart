import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/dashboard.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import 'widgets/entry_row.dart';

const _arabicWeekdays = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// "اليوم", "أمس", else the weekday and date, e.g. "الجمعة 4 سبتمبر"
/// (spec §4.3's day headers).
String formatDayLabel(DateTime day, DateTime today) {
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  if (d == t) return 'اليوم';
  if (d == DateTime(t.year, t.month, t.day - 1)) return 'أمس';
  return '${_arabicWeekdays[d.weekday - 1]} ${d.day} ${arabicMonthName(d.month)}';
}

/// السجل, one day at a time with ‹ › to step between days.
///
/// The full list grouped by day, search and filters are Task B2; this is
/// the tab's first cut so the dashboard's "عرض الكل" and the navigation
/// shell have somewhere real to land.
class TransactionsScreen extends StatefulWidget {
  final SpendingRepository repository;
  final DateTime Function() clock;

  /// The day to open on; null opens on today.
  final DateTime? initialDay;

  /// Bumped by the shell on every "show [initialDay]" request. The day
  /// alone is not enough: asking for today twice, with the user having
  /// stepped to yesterday in between, passes the same day both times.
  final int dayRequest;

  const TransactionsScreen({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
    this.initialDay,
    this.dayRequest = 0,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late DateTime _day;
  late Stream<List<EntryView>> _entries;
  late final Future<Map<String, CategoryView>> _categories = widget.repository
      .categories()
      .then((cats) => {for (final c in cats) c.key: c});

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _show(widget.initialDay ?? _today);
  }

  @override
  void didUpdateWidget(TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell reuses this screen when the dashboard asks for another day.
    final day = widget.initialDay;
    if (day != null &&
        (day != oldWidget.initialDay ||
            widget.dayRequest != oldWidget.dayRequest)) {
      _show(day);
    }
  }

  void _show(DateTime day) {
    _day = DateTime(day.year, day.month, day.day);
    _entries = widget.repository.watchEntriesForDay(_day);
  }

  void _step(int days) =>
      setState(() => _show(DateTime(_day.year, _day.month, _day.day + days)));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final atToday = !_day.isBefore(_today);
    return Scaffold(
      appBar: AppBar(title: const Text('السجل')),
      body: FutureBuilder<Map<String, CategoryView>>(
        future: _categories,
        builder: (context, categories) => StreamBuilder<List<EntryView>>(
          key: ValueKey(_day),
          stream: _entries,
          builder: (context, snapshot) {
            final entries = snapshot.data;
            final total =
                entries?.fold<int>(0, (sum, e) => sum + e.amountPiastres) ?? 0;
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xxl * 2,
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('day-previous'),
                      tooltip: 'اليوم اللي قبله',
                      onPressed: () => _step(-1),
                      icon: const Icon(AppIcons.chevronStart),
                    ),
                    Expanded(
                      child: Text(
                        formatDayLabel(_day, _today),
                        key: const Key('day-label'),
                        textAlign: TextAlign.center,
                        style: AppText.title,
                      ),
                    ),
                    IconButton(
                      key: const Key('day-next'),
                      tooltip: 'اليوم اللي بعده',
                      onPressed: atToday ? null : () => _step(1),
                      icon: const Icon(AppIcons.chevronEnd),
                    ),
                  ],
                ),
                if (entries == null)
                  const SkeletonRows()
                else if (entries.isEmpty)
                  const EmptyState(
                    icon: AppIcons.emptyReceipt,
                    headline: 'مفيش مصاريف في اليوم ده',
                    caption: 'اللي تسجله هيظهر هنا',
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${entries.length} مصروف',
                          style: AppText.label.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatPiastres(total, withCurrency: true),
                          key: const Key('day-total'),
                          textDirection: TextDirection.ltr,
                          style: AppText.bodyStrong,
                        ),
                      ],
                    ),
                  ),
                  for (final entry in entries)
                    EntryRow(
                      entry: entry,
                      category: categories.data?[entry.categoryKey],
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
