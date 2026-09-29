import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/category_colors.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/dashboard.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../../domain/statistics.dart';
import '../../domain/transactions.dart';
import '../home/widgets/section_card.dart';
import '../transactions/transactions_screen.dart';
import '../transactions/widgets/transaction_tile.dart' show CategoryCircle;

/// الإحصائيات (spec §4.5): a calendar-month selector, a donut of the
/// selected month only that drills into a category's subcategories, and
/// the history of every month with spending.
///
/// Everything is worked out from the live transaction list, so the screen
/// follows every save, edit and delete while it stays alive in its tab.
class StatisticsScreen extends StatefulWidget {
  final SpendingRepository repository;
  final DateTime Function() clock;

  /// The month to open on; null opens on the current month.
  final YearMonth? initialMonth;

  /// Bumped by the shell on every "show [initialMonth]" request, so the
  /// dashboard's month card lands on this month even when the user has
  /// stepped to another one and the requested month is unchanged.
  final int monthRequest;

  /// Opens السجل on a month from the history. Left null, the screen pushes
  /// السجل itself, which is what a lone screen in a test gets.
  final ValueChanged<YearMonth>? onOpenMonth;

  const StatisticsScreen({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
    this.initialMonth,
    this.monthRequest = 0,
    this.onOpenMonth,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final Stream<List<TransactionView>> _transactions = widget.repository
      .watchTransactions();
  late final Future<List<CategoryView>> _categories = widget.repository
      .categories();

  late YearMonth _month = widget.initialMonth ?? _currentMonth;

  /// The category the donut is drilled into; null shows every category.
  String? _drill;

  /// Whether the legend's "أخرى" row is open on the categories merged
  /// into it.
  bool _othersOpen = false;

  YearMonth get _currentMonth => YearMonth.of(widget.clock());

  @override
  void didUpdateWidget(StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final month = widget.initialMonth;
    if (month != null &&
        (month != oldWidget.initialMonth ||
            widget.monthRequest != oldWidget.monthRequest)) {
      _show(month);
    }
  }

  /// Moves to [month], closing any drill-down: a subcategory breakdown
  /// belongs to the month it was opened in.
  void _show(YearMonth month) => setState(() {
    _month = month;
    _drill = null;
    _othersOpen = false;
  });

  void _openMonth(YearMonth month) {
    final open = widget.onOpenMonth;
    if (open != null) return open(month);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionsScreen(
          repository: widget.repository,
          clock: widget.clock,
          initialFilter: TransactionFilter(
            from: month.firstDay,
            to: month.lastDay,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات')),
      body: FutureBuilder<List<CategoryView>>(
        future: _categories,
        builder: (context, categories) => StreamBuilder<List<TransactionView>>(
          stream: _transactions,
          builder: (context, snapshot) {
            final all = snapshot.data;
            if (all == null || !categories.hasData) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.gutter),
                child: SkeletonRows(),
              );
            }
            return _body(all, {for (final c in categories.data!) c.key: c});
          },
        ),
      ),
    );
  }

  Widget _body(List<TransactionView> all, Map<String, CategoryView> byKey) {
    final history = monthHistory(all);
    final current = _currentMonth;
    // The oldest month the selector reaches: the first with spending, or
    // this month when there is none yet.
    final oldest = history.isEmpty ? current : history.last.month;
    // Labels the entries carry, for a category no longer in the catalogue
    // (archived) that still has spending in an old month.
    final labels = {for (final t in all) t.categoryKey: t.categoryLabelAr};
    String labelOf(String key) => byKey[key]?.labelAr ?? labels[key] ?? key;

    const gap = SizedBox(height: AppSpacing.section);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xxl * 2,
      ),
      children: [
        _MonthSelector(
          month: _month,
          onPrevious: oldest < _month ? () => _show(_month.previous) : null,
          onNext: _month < current ? () => _show(_month.next) : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        _drill == null
            ? _categoriesCard(all, byKey, labelOf)
            : _drillCard(all, byKey, labelOf, _drill!),
        if (history.isNotEmpty) ...[
          gap,
          SectionCard(
            key: const Key('month-history'),
            title: 'الشهور',
            child: Column(
              children: [
                for (final row in history)
                  _HistoryRow(
                    row: row,
                    selected: row.month == _month,
                    categoryLabels: [
                      for (final k in row.topCategoryKeys) labelOf(k),
                    ],
                    onTap: () => _openMonth(row.month),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _categoriesCard(
    List<TransactionView> all,
    Map<String, CategoryView> byKey,
    String Function(String) labelOf,
  ) {
    final palette = context.palette;
    final amounts = spendByCategoryInMonth(all, _month);
    final slices = donutSlices(amounts);
    final total = amounts.values.fold<int>(0, (sum, v) => sum + v);
    // A category's colour belongs to its row (colorKey), so it is the same
    // on every screen and in every month, whatever its rank.
    Color inkOf(String key) => palette.categoryInk(byKey[key]?.colorKey ?? '');
    Color colourOf(DonutSlice s) => s.isOther ? palette.outline : inkOf(s.key);
    String nameOf(DonutSlice s) => s.isOther ? 'أخرى' : labelOf(s.key);

    void drill(String key) => setState(() {
      _drill = key;
      _othersOpen = false;
    });

    int percentOf(int amount) =>
        total == 0 ? 0 : (amount * 200 + total) ~/ (total * 2);

    return SectionCard(
      key: const Key('stats-categories'),
      title: 'الفئات',
      child: slices.isEmpty
          ? const EmptyState(
              icon: AppIcons.stats,
              headline: 'مفيش مصاريف في الشهر ده',
              caption: 'اختار شهر تاني أو سجّل مصروف',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Donut(
                  summary:
                      'الفئات في ${_month.label}: '
                      '${[for (final s in slices) '${nameOf(s)} ${s.percent}%'].join('، ')}',
                  totalPiastres: total,
                  slices: [for (final s in slices) (s, colourOf(s))],
                  onTapSlice: (i) {
                    final slice = slices[i];
                    if (slice.isOther) {
                      setState(() => _othersOpen = !_othersOpen);
                    } else {
                      drill(slice.key);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                for (final s in slices) ...[
                  if (s.isOther)
                    _LegendRow(
                      key: const Key('legend-other'),
                      leading: _Dot(colour: colourOf(s)),
                      label: 'أخرى',
                      percent: s.percent,
                      amountPiastres: s.amountPiastres,
                      trailing: _othersOpen
                          ? AppIcons.expandLess
                          : AppIcons.expandMore,
                      onTap: () => setState(() => _othersOpen = !_othersOpen),
                    )
                  else
                    _categoryRow(
                      s.key,
                      s.percent,
                      s.amountPiastres,
                      byKey,
                      labelOf,
                      drill,
                    ),
                  if (s.isOther && _othersOpen)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.lg,
                      ),
                      child: Column(
                        children: [
                          for (final key in s.mergedKeys)
                            _categoryRow(
                              key,
                              percentOf(amounts[key]!),
                              amounts[key]!,
                              byKey,
                              labelOf,
                              drill,
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _categoryRow(
    String key,
    int percent,
    int amount,
    Map<String, CategoryView> byKey,
    String Function(String) labelOf,
    void Function(String) drill,
  ) => _LegendRow(
    key: Key('legend-$key'),
    leading: CategoryCircle(category: byKey[key]),
    label: labelOf(key),
    percent: percent,
    amountPiastres: amount,
    trailing: AppIcons.chevronEnd,
    onTap: () => drill(key),
  );

  Widget _drillCard(
    List<TransactionView> all,
    Map<String, CategoryView> byKey,
    String Function(String) labelOf,
    String categoryKey,
  ) {
    final palette = context.palette;
    final subs = spendBySubcategoryInMonth(all, _month, categoryKey);
    // Subcategories are keyed by name for donutSlices; the null key (the
    // category alone) becomes the empty string.
    final slices = donutSlices({
      for (final MapEntry(:key, :value) in subs.entries)
        key ?? '': value.amountPiastres,
    });
    final total = slices.fold<int>(0, (sum, s) => sum + s.amountPiastres);
    final ink = palette.categoryInk(byKey[categoryKey]?.colorKey ?? '');
    // Shades of the category's own ink, biggest slice darkest, so the
    // drill-down still reads as the one category it came from.
    const shades = [1.0, 0.78, 0.6, 0.45, 0.32, 0.22];
    Color colourAt(int i) => ink.withValues(alpha: shades[i]);
    String nameOf(DonutSlice s) {
      if (s.isOther) return 'أخرى';
      if (s.key.isEmpty) return 'من غير فئة فرعية';
      return subs[s.key]?.label ?? s.key;
    }

    return Container(
      key: const Key('stats-drill'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.fromBorderSide(palette.cardBorder),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('drill-back'),
                tooltip: 'كل الفئات',
                onPressed: () => setState(() => _drill = null),
                icon: const Icon(AppIcons.back),
              ),
              Expanded(
                child: Text(
                  labelOf(categoryKey),
                  key: const Key('drill-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title,
                ),
              ),
            ],
          ),
          if (slices.isEmpty)
            const EmptyState(
              icon: AppIcons.stats,
              headline: 'مفيش مصاريف في الشهر ده',
              caption: 'اختار شهر تاني',
            )
          else ...[
            _Donut(
              summary:
                  '${labelOf(categoryKey)} في ${_month.label}: '
                  '${[for (final s in slices) '${nameOf(s)} ${s.percent}%'].join('، ')}',
              totalPiastres: total,
              slices: [
                for (var i = 0; i < slices.length; i++)
                  (slices[i], colourAt(i)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < slices.length; i++)
              _LegendRow(
                key: Key(
                  slices[i].isOther
                      ? 'legend-sub-other'
                      : 'legend-sub-${slices[i].key.isEmpty ? 'none' : slices[i].key}',
                ),
                leading: _Dot(colour: colourAt(i)),
                label: nameOf(slices[i]),
                percent: slices[i].percent,
                amountPiastres: slices[i].amountPiastres,
              ),
          ],
        ],
      ),
    );
  }
}

/// The month chip with ‹ › on either side. The start-side button goes back
/// to the older month, like the dashboard's period header, and a swipe
/// toward the end side does the same. A null callback disables its end.
class _MonthSelector extends StatelessWidget {
  final YearMonth month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _MonthSelector({required this.month, this.onPrevious, this.onNext});

  void _onSwipe(BuildContext context, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;
    final towardEnd = Directionality.of(context) == TextDirection.rtl
        ? velocity < 0
        : velocity > 0;
    (towardEnd ? onPrevious : onNext)?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      key: const Key('stats-month'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) => _onSwipe(context, d),
      child: Row(
        children: [
          IconButton(
            key: const Key('month-previous'),
            tooltip: 'الشهر اللي فات',
            onPressed: onPrevious,
            icon: const Icon(AppIcons.chevronStart),
          ),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: 16,
                      color: palette.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        month.label,
                        key: const Key('stats-month-label'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong.copyWith(
                          color: palette.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('month-next'),
            tooltip: 'الشهر اللي بعده',
            onPressed: onNext,
            icon: const Icon(AppIcons.chevronEnd),
          ),
        ],
      ),
    );
  }
}

/// A donut of [slices], largest from 12 o'clock, with the month's total in
/// the hole and each slice's percent on it. A slice too thin to hold its
/// percent gets it just outside the ring instead.
///
/// Screen readers hear [summary] in place of the chart; the legend rows
/// below it carry the same numbers and the drill-down taps.
class _Donut extends StatelessWidget {
  final String summary;
  final int totalPiastres;
  final List<(DonutSlice, Color)> slices;
  final ValueChanged<int>? onTapSlice;

  const _Donut({
    required this.summary,
    required this.totalPiastres,
    required this.slices,
    this.onTapSlice,
  });

  /// Below this share the percent does not fit inside the ring.
  static const _insideMinPercent = 8;

  /// Near-black or white, whichever reads better on [fill]. Slices range
  /// from deep light-mode inks to dark-mode pastels and the drill-down's
  /// pale shades, so no one text colour suits them all.
  static Color _inkOn(Color fill) {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance() + 0.05;
      final lb = b.computeLuminance() + 0.05;
      return la > lb ? la / lb : lb / la;
    }

    final dark = AppPalette.light.textPrimary;
    final light = AppPalette.light.surface;
    return contrast(fill, dark) >= contrast(fill, light) ? dark : light;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      container: true,
      label: summary,
      child: ExcludeSemantics(
        child: SizedBox(
          key: const Key('stats-donut'),
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 2,
                  centerSpaceRadius: 56,
                  pieTouchData: PieTouchData(
                    enabled: onTapSlice != null,
                    touchCallback: (event, response) {
                      final index =
                          response?.touchedSection?.touchedSectionIndex;
                      if (event is FlTapUpEvent &&
                          index != null &&
                          index >= 0 &&
                          index < slices.length) {
                        onTapSlice?.call(index);
                      }
                    },
                  ),
                  sections: [
                    for (final (slice, colour) in slices)
                      PieChartSectionData(
                        value: slice.amountPiastres.toDouble(),
                        color: colour,
                        radius: 44,
                        title: '${slice.percent}%',
                        titlePositionPercentageOffset:
                            slice.percent < _insideMinPercent ? 1.45 : 0.5,
                        titleStyle: AppText.caption.copyWith(
                          color: slice.percent < _insideMinPercent
                              ? palette.textPrimary
                              : _inkOn(
                                  Color.alphaBlend(colour, palette.surface),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'المجموع',
                    style: AppText.caption.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  Text(
                    formatPiastres(totalPiastres),
                    key: const Key('stats-total'),
                    textDirection: TextDirection.ltr,
                    style: AppText.title,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One legend row: the slice's colour or category circle, its name, its
/// percent and amount, and what a tap does.
class _LegendRow extends StatelessWidget {
  final Widget leading;
  final String label;
  final int percent;
  final int amountPiastres;
  final IconData? trailing;
  final VoidCallback? onTap;

  const _LegendRow({
    super.key,
    required this.leading,
    required this.label,
    required this.percent,
    required this.amountPiastres,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            SizedBox(width: 40, child: Center(child: leading)),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body,
              ),
            ),
            Text(
              '$percent%',
              textDirection: TextDirection.ltr,
              style: AppText.label.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(width: AppSpacing.ms),
            Text(
              formatPiastres(amountPiastres, withCurrency: true),
              textDirection: TextDirection.ltr,
              style: AppText.bodyStrong,
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(trailing, size: 20, color: palette.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color colour;

  const _Dot({required this.colour});

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
  );
}

/// One month of the history: its name and top categories on the start
/// side, its total and the change from the month before on the end side.
/// The month the donut shows is tinted.
class _HistoryRow extends StatelessWidget {
  final MonthHistoryRow row;
  final bool selected;
  final List<String> categoryLabels;
  final VoidCallback onTap;

  const _HistoryRow({
    required this.row,
    required this.selected,
    required this.categoryLabels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final change = row.change;
    return Material(
      key: Key('history-${row.month.iso}'),
      color: selected ? palette.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.month.label, style: AppText.bodyStrong),
                      Text(
                        categoryLabels.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPiastres(row.totalPiastres, withCurrency: true),
                      textDirection: TextDirection.ltr,
                      style: AppText.bodyStrong,
                    ),
                    if (change != null) _Change(change: change),
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

/// The change from the month before: down and positive when less was
/// spent, up and negative when more, as on the dashboard's month card.
class _Change extends StatelessWidget {
  final MonthComparison change;

  const _Change({required this.change});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, colour, text) = switch (change.direction) {
      ComparisonDirection.less => (
        AppIcons.trendDown,
        palette.positive,
        'أقل بـ ${change.percent}%',
      ),
      ComparisonDirection.more => (
        AppIcons.trendUp,
        palette.negative,
        'أكتر بـ ${change.percent}%',
      ),
      ComparisonDirection.same => (
        AppIcons.trendFlat,
        palette.textSecondary,
        'زي الشهر اللي قبله',
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colour),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: AppText.caption.copyWith(color: colour)),
      ],
    );
  }
}
