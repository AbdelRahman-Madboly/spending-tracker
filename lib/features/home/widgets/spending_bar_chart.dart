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

  /// The previous period's totals at the same offsets, one per point,
  /// drawn as a dashed line over the bars. Empty draws no line.
  final List<int> previous;
  final VoidCallback? onTap;

  const SpendingBarChart({
    super.key,
    required this.points,
    this.previous = const [],
    this.onTap,
  });

  /// The bottom axis labels' reserved height.
  static const _labelsHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    var maxValue = points.fold<int>(
      0,
      (max, p) => p.totalPiastres > max ? p.totalPiastres : max,
    );
    for (final v in previous) {
      if (v > maxValue) maxValue = v;
    }
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
          child: CustomPaint(
            key: const Key('trend-previous'),
            foregroundPainter: PreviousPeriodPainter(
              values: previous.length == points.length ? previous : const [],
              maxY: maxYPiastres,
              bottomInset: _labelsHeight,
              color: context.palette.textSecondary,
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
                      reservedSize: _labelsHeight,
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
                          child: Text(
                            points[index].label,
                            style: AppText.caption.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
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
                          color: context.palette.primary,
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
      ),
    );
  }
}

/// The dashed previous-period line over [SpendingBarChart]: one point per
/// bar, at the bar's centre (the chart spaces its bars evenly around), on
/// the same vertical scale as the bars.
class PreviousPeriodPainter extends CustomPainter {
  final List<int> values;
  final int maxY;
  final double bottomInset;
  final Color color;

  PreviousPeriodPainter({
    required this.values,
    required this.maxY,
    required this.bottomInset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || maxY <= 0) return;
    final plotHeight = size.height - bottomInset;
    final step = size.width / values.length;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(step * (i + 0.5), plotHeight * (1 - values[i] / maxY)),
    ];
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const dash = 4.0, gap = 4.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final length = (b - a).distance;
      final direction = (b - a) / length;
      for (var d = 0.0; d < length; d += dash + gap) {
        final end = d + dash < length ? d + dash : length;
        canvas.drawLine(a + direction * d, a + direction * end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(PreviousPeriodPainter old) =>
      old.maxY != maxY || old.color != color || !_same(old.values, values);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
