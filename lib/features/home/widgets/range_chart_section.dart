import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../domain/spending_repository.dart';
import 'section_card.dart';
import 'spending_bar_chart.dart';

typedef ChartPoint = ({String label, int totalPiastres});

/// Splits `2 × count` totals, oldest first, into the [count] shown and the
/// [count] before them: bar `i` of the shown window lines up with value
/// `i` of the previous one, the same offset into its period. Fewer totals
/// than that pad the previous window with zeros at its old end.
(List<ChartPoint>, List<int>) splitCurrentAndPrevious(
  List<ChartPoint> totals,
  int count,
) {
  final shown = totals.length <= count
      ? totals
      : totals.sublist(totals.length - count);
  final before = totals.length <= count
      ? const <ChartPoint>[]
      : totals.sublist(0, totals.length - count);
  final previous = [
    for (var i = 0; i < count - before.length; i++) 0,
    for (final p
        in before.length > count
            ? before.sublist(before.length - count)
            : before)
      p.totalPiastres,
  ];
  return (shown, previous);
}

/// Which granularity [RangeChartSection]'s chart is currently showing.
enum ChartRange { day, week, month }

/// A segmented يوم/أسبوع/شهر control above a [SpendingBarChart], letting the
/// user flip between daily, weekly and monthly spending totals — "شهر" is
/// the default so existing behaviour (the six-month chart) is what renders
/// first.
class RangeChartSection extends StatefulWidget {
  final SpendingRepository repository;
  final VoidCallback? onTap;

  const RangeChartSection({super.key, required this.repository, this.onTap});

  @override
  State<RangeChartSection> createState() => _RangeChartSectionState();
}

class _RangeChartSectionState extends State<RangeChartSection> {
  ChartRange _range = ChartRange.month;

  /// Loads twice the shown window, so the half before it can be drawn as
  /// the previous period's dashed line.
  Future<(List<ChartPoint>, List<int>)> _load(ChartRange range) async {
    switch (range) {
      case ChartRange.day:
        return splitCurrentAndPrevious(
          await widget.repository.dailyTotals(14),
          7,
        );
      case ChartRange.week:
        return splitCurrentAndPrevious(
          await widget.repository.weeklyTotals(12),
          6,
        );
      case ChartRange.month:
        final months = await widget.repository.monthlyTotals(12);
        return splitCurrentAndPrevious([
          for (final m in months)
            (label: m.yearMonth.split('-')[1], totalPiastres: m.totalPiastres),
        ], 6);
    }
  }

  // Cached per range so a rebuild (a theme change, a parent setState) does
  // not refetch.
  final _loads = <ChartRange, Future<(List<ChartPoint>, List<int>)>>{};

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'الصرف',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SegmentedButton<ChartRange>(
              key: const Key('chart-range-control'),
              segments: const [
                ButtonSegment(value: ChartRange.day, label: Text('يوم')),
                ButtonSegment(value: ChartRange.week, label: Text('أسبوع')),
                ButtonSegment(value: ChartRange.month, label: Text('شهر')),
              ],
              selected: {_range},
              // SegmentedButton's own Material 3 default is only 40dp
              // tall — below this app's 48dp minimum tap target — so this
              // overrides it explicitly rather than relying on the shared
              // button theme, which only covers Filled/Outlined/Text
              // buttons.
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(64, 48)),
              ),
              onSelectionChanged: (selection) =>
                  setState(() => _range = selection.first),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<(List<ChartPoint>, List<int>)>(
            // Keyed by range so switching ranges shows a fresh load rather
            // than momentarily reusing the previous range's stale data.
            key: ValueKey(_range),
            future: _loads[_range] ??= _load(_range),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) return const SizedBox(height: 160);
              return SpendingBarChart(
                points: data.$1,
                previous: data.$2,
                onTap: widget.onTap,
              );
            },
          ),
        ],
      ),
    );
  }
}
