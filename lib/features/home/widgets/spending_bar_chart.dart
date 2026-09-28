import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';

/// A compact bar chart of spending totals over a range of periods (days,
/// weeks or months — whichever the caller passed in `points`). Tapping
/// anywhere on it runs [onTap] (opening the statistics screen for a closer
/// look) — the chart's own touch handling is disabled so that tap always
/// lands on this widget rather than being consumed by fl_chart's touch
/// arena.
class SpendingBarChart extends StatelessWidget {
  final List<({String label, int totalPiastres})> points;
  final VoidCallback? onTap;

  const SpendingBarChart({super.key, required this.points, this.onTap});

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(
        0, (max, p) => p.totalPiastres > max ? p.totalPiastres : max);
    // 15% headroom above the tallest bar, computed in integer piastres so
    // the only float conversion happens once, at the chart's own maxY
    // boundary.
    final maxYPiastres = maxValue == 0 ? 1 : maxValue + (maxValue * 15 ~/ 100);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 160,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: BarChart(
            BarChartData(
              maxY: maxYPiastres.toDouble(),
              alignment: BarChartAlignment.spaceAround,
              barTouchData: const BarTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      // Always Latin digits, rather than an Arabic label —
                      // keeps the axis consistent with every other digit
                      // in the app.
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child:
                            Text(points[index].label, style: AppText.caption),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].totalPiastres.toDouble(),
                        color: AppColors.accent,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
