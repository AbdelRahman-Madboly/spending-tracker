import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../domain/spending_repository.dart';
import 'spending_bar_chart.dart';

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

  Future<List<({String label, int totalPiastres})>> _load(
      ChartRange range) async {
    switch (range) {
      case ChartRange.day:
        return widget.repository.dailyTotals(7);
      case ChartRange.week:
        return widget.repository.weeklyTotals(6);
      case ChartRange.month:
        final months = await widget.repository.monthlyTotals(6);
        return [
          for (final m in months)
            (label: m.yearMonth.split('-')[1], totalPiastres: m.totalPiastres),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Center(
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
        ),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<({String label, int totalPiastres})>>(
          // Keyed by range so switching ranges shows a fresh load rather
          // than momentarily reusing the previous range's stale data.
          key: ValueKey(_range),
          future: _load(_range),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return const SizedBox(height: 160);
            return SpendingBarChart(points: data, onTap: widget.onTap);
          },
        ),
      ],
    );
  }
}
