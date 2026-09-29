import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/dashboard.dart';
import '../../domain/import/importer.dart' show importOfferSettingKey;
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../capture/capture_launcher.dart';
import '../products/products_screen.dart';
import '../scan_check/scan_check.dart';
import '../review/review_sheet.dart';
import '../statistics/statistics_screen.dart';
import '../transactions/transactions_screen.dart';
import 'widgets/capture_bar.dart';
import 'widgets/hero_card.dart';
import 'widgets/month_comparison_card.dart';
import 'widgets/needs_review_section.dart';
import 'widgets/period_header.dart';
import 'widgets/range_chart_section.dart';
import 'widgets/today_section.dart';
import 'widgets/top_categories_section.dart';
import 'widgets/upcoming_bills_section.dart';

/// The dashboard (الرئيسية, spec §4.2). Top to bottom, in a fixed order:
/// period header, hero, capture bar, needs review, today, trend, top
/// categories, upcoming bills and the month comparison. Needs review,
/// upcoming bills and the month comparison hide when they have nothing to
/// say.
///
/// Every navigation is a callback, so the shell can switch tabs instead of
/// pushing routes; left null, each falls back to opening its screen or
/// sheet directly, which is what a lone `HomeScreen` in a test gets.
class HomeScreen extends StatefulWidget {
  final SpendingRepository repository;

  /// "Now", injectable so tests can freeze the day the fixture's entries
  /// are dated.
  final DateTime Function() clock;
  final VoidCallback? onAdd;
  final ValueChanged<CaptureAction>? onCapture;
  final VoidCallback? onOpenStatistics;

  /// Opens «المنتجات» (from the باركود menu).
  final VoidCallback? onOpenProducts;

  /// Starts «امسح واعرف» (from the باركود menu).
  final VoidCallback? onScanCheck;

  /// Opens السجل filtered to the given day.
  final ValueChanged<DateTime>? onOpenTransactions;
  final ValueChanged<CaptureGroupView>? onOpenDraft;

  /// Opens the import of the bundled packs; true when something was
  /// imported. With it, the dashboard offers that import once (plan
  /// Task 13) until it is done or dismissed.
  final Future<bool> Function()? onImportBundled;

  const HomeScreen({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
    this.onAdd,
    this.onCapture,
    this.onOpenStatistics,
    this.onOpenProducts,
    this.onScanCheck,
    this.onOpenTransactions,
    this.onOpenDraft,
    this.onImportBundled,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

typedef _Breakdown = ({
  List<CategoryShare> shares,
  Map<String, CategoryView> categories,
});

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  SpendingRepository get _repo => widget.repository;

  StreamSubscription<List<PeriodSummary>>? _periodsSub;
  List<PeriodSummary>? _periods;

  /// 0 is the current period, 1 the one before it, and so on.
  int _periodIndex = 0;

  /// Bumped on every change the repository reports, so the sections that
  /// load once (a Future rather than a stream) load again.
  int _revision = 0;

  late DateTime _today;
  late Stream<List<EntryView>> _todayEntries;
  late final Stream<List<CaptureGroupView>> _drafts =
      _repo.watchDraftCaptures();
  Future<Map<String, CategoryView>>? _categories;
  Future<_Breakdown>? _breakdown;
  Future<MonthComparison?>? _comparison;
  Future<List<RecurringBillView>>? _bills;

  /// Fires just after the next midnight, so النهارده moves on even when
  /// the app sits open with no database change to trigger a reload.
  Timer? _midnight;

  /// Whether the import offer shows; false until the setting is read.
  bool _offerImport = false;

  Future<void> _loadImportOffer() async {
    if (widget.onImportBundled == null) return;
    final done = await _repo.setting(importOfferSettingKey);
    if (mounted) setState(() => _offerImport = done == null);
  }

  Future<void> _closeImportOffer() async {
    setState(() => _offerImport = false);
    await _repo.setSetting(importOfferSettingKey, '1');
  }

  Future<void> _importBundled() async {
    final imported = await widget.onImportBundled!();
    if (imported && mounted) await _closeImportOffer();
  }

  @override
  void initState() {
    super.initState();
    _loadImportOffer();
    WidgetsBinding.instance.addObserver(this);
    _setToday();
    _scheduleMidnight();
    // Every entry or salary change comes through here, so it doubles as
    // the refresh signal for everything else on the page.
    _periodsSub = _repo.watchPeriods().listen((periods) {
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _periodIndex = _periodIndex.clamp(0, periods.length - 1);
        _revision++;
        _reload();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _periodsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A suspended app's timers do not fire on time, so coming back to the
    // foreground checks the day as well.
    if (state == AppLifecycleState.resumed) _checkDay();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = widget.clock();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight =
        Timer(next.difference(now) + const Duration(seconds: 1), _checkDay);
  }

  /// Reloads everything tied to today when the calendar day has changed.
  void _checkDay() {
    if (!mounted) return;
    _scheduleMidnight();
    final now = widget.clock();
    if (DateTime(now.year, now.month, now.day) == _today) return;
    // The trend's daily bars shift with the day too.
    setState(() {
      _revision++;
      _reload();
    });
  }

  void _setToday() {
    final now = widget.clock();
    _today = DateTime(now.year, now.month, now.day);
    _todayEntries = _repo.watchEntriesForDay(_today);
  }

  PeriodSummary? get _period {
    final periods = _periods;
    if (periods == null || periods.isEmpty) return null;
    return periods[_periodIndex];
  }

  void _reload() {
    // Past midnight with the app open: today moves on.
    final now = widget.clock();
    if (DateTime(now.year, now.month, now.day) != _today) _setToday();

    _categories = _repo.categories().then((cats) => {
          for (final c in cats) c.key: c,
        });
    _loadBreakdown();
    _comparison = _loadComparison();
    _bills = _repo
        .recurringBills()
        .then((bills) => upcomingBills(bills, _today));
  }

  void _loadBreakdown() {
    final period = _period;
    final start = period?.start;
    final byCategory = start == null
        ? Future.value(const <String, int>{})
        : _repo.spendByCategoryBetween(
            start, period!.isCurrent ? null : period.end);
    _breakdown = Future.wait([byCategory, _categories!]).then((results) => (
          shares: topCategoryShares(results[0] as Map<String, int>),
          categories: results[1] as Map<String, CategoryView>,
        ));
  }

  /// This month from the 1st to today against last month from the 1st to
  /// the same day, clamped to last month's length (the 31st against a
  /// 30-day month compares with its 30th).
  Future<MonthComparison?> _loadComparison() async {
    final today = _today;
    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final lastMonthLength = DateTime(today.year, today.month, 0).day;
    final sameDay = today.day > lastMonthLength ? lastMonthLength : today.day;
    final thisMonth =
        await _repo.spentBetween(DateTime(today.year, today.month, 1), today);
    final lastMonth = await _repo.spentBetween(lastMonthStart,
        DateTime(lastMonthStart.year, lastMonthStart.month, sameDay));
    return compareToLastMonth(thisMonth, lastMonth);
  }

  void _selectPeriod(int index) {
    final periods = _periods;
    if (periods == null || index < 0 || index >= periods.length) return;
    setState(() {
      _periodIndex = index;
      _loadBreakdown();
    });
  }

  void _previous() => _selectPeriod(_periodIndex + 1);
  void _next() => _selectPeriod(_periodIndex - 1);

  void _onHeroSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;
    // Right to left, the finger moving toward the end side (left) steps
    // back in time, like the start-side › button; mirrored left to right.
    final towardEnd =
        Directionality.of(context) == TextDirection.rtl ? velocity < 0 : velocity > 0;
    towardEnd ? _previous() : _next();
  }

  // ---- navigation, each defaulting to a direct route ----

  void _add() => widget.onAdd != null
      ? widget.onAdd!()
      : openAddSheet(context, _repo);

  void _capture(CaptureAction action) => widget.onCapture != null
      ? widget.onCapture!(action)
      : launchCapture(context, _repo, action, clock: widget.clock);

  void _openProducts() => widget.onOpenProducts != null
      ? widget.onOpenProducts!()
      : openProductsScreen(context, _repo);

  void _scanCheck() => widget.onScanCheck != null
      ? widget.onScanCheck!()
      : scanAndCheck(context, _repo, clock: widget.clock);

  Future<void> _barcodeMenu() async {
    final choice = await showBarcodeMenu(context);
    if (!mounted) return;
    switch (choice) {
      case BarcodeMenuChoice.record:
        _capture(CaptureAction.barcode);
      case BarcodeMenuChoice.check:
        _scanCheck();
      case BarcodeMenuChoice.products:
        _openProducts();
      case null:
        break;
    }
  }

  void _openStatistics() => widget.onOpenStatistics != null
      ? widget.onOpenStatistics!()
      : Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              StatisticsScreen(repository: _repo, clock: widget.clock)));

  void _openTransactions() => widget.onOpenTransactions != null
      ? widget.onOpenTransactions!(_today)
      : Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TransactionsScreen(
              repository: _repo, initialDay: _today, clock: widget.clock)));

  void _openDraft(CaptureGroupView draft) => widget.onOpenDraft != null
      ? widget.onOpenDraft!(draft)
      : showReviewSheet(context,
          repository: _repo,
          request: ReviewRequest.fromDraft(draft),
          clock: widget.clock);

  @override
  Widget build(BuildContext context) {
    final period = _period;
    final periods = _periods ?? const [];
    final gap = const SizedBox(height: AppSpacing.section);

    return Scaffold(
      appBar: AppBar(title: const Text('مصاريفي')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.gutter,
                AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl * 2),
            sliver: SliverList.list(
              children: [
                PeriodHeader(
                  key: const Key('period-header'),
                  label: period?.start == null
                      ? 'الفترة الحالية'
                      : formatPeriodLabel(period!.start!, period.end),
                  onPrevious:
                      _periodIndex < periods.length - 1 ? _previous : null,
                  onNext: _periodIndex > 0 ? _next : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onHorizontalDragEnd: _onHeroSwipe,
                  child: period == null
                      ? const Skeleton(height: 220)
                      : HeroCard(
                          key: ValueKey('hero-$_periodIndex'),
                          summary: period),
                ),
                gap,
                CaptureBar(
                  // باركود asks first: a purchase, a price check or the
                  // products, so «امسح واعرف» is one tap away.
                  onAction: (action) => action == CaptureAction.barcode
                      ? _barcodeMenu()
                      : _capture(action),
                  onLongPress: (_) => _barcodeMenu(),
                ),
                // Always in the list, so showing or hiding it never shifts
                // the sections below to new slots.
                if (!_offerImport)
                  const SizedBox.shrink()
                else
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(top: AppSpacing.section),
                    child: _ImportOfferCard(
                      onImport: _importBundled,
                      onDismiss: _closeImportOffer,
                    ),
                  ),
                StreamBuilder<List<CaptureGroupView>>(
                  stream: _drafts,
                  builder: (context, snapshot) {
                    final drafts = snapshot.data ?? const [];
                    if (drafts.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.section),
                      child: NeedsReviewSection(
                          drafts: drafts, onOpen: _openDraft),
                    );
                  },
                ),
                gap,
                FutureBuilder<Map<String, CategoryView>>(
                  future: _categories,
                  builder: (context, categories) =>
                      StreamBuilder<List<EntryView>>(
                    // Keyed by day so a new day starts a fresh section
                    // (and its "already there" set of rows).
                    key: ValueKey(_today),
                    stream: _todayEntries,
                    builder: (context, snapshot) {
                      final entries = snapshot.data;
                      if (entries == null) return const SkeletonRows();
                      return TodaySection(
                        entries: entries,
                        categories: categories.data ?? const {},
                        onSeeAll: _openTransactions,
                        onAdd: _add,
                      );
                    },
                  ),
                ),
                gap,
                Container(
                  key: const Key('trend-section'),
                  child: RangeChartSection(
                    revision: _revision,
                    repository: _repo,
                    onTap: _openStatistics,
                  ),
                ),
                gap,
                FutureBuilder<_Breakdown>(
                  future: _breakdown,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    if (data == null) return const SkeletonRows();
                    return TopCategoriesSection(
                      shares: data.shares,
                      categories: data.categories,
                      onSeeAll: _openStatistics,
                    );
                  },
                ),
                FutureBuilder<List<RecurringBillView>>(
                  future: _bills,
                  builder: (context, snapshot) {
                    final bills = snapshot.data ?? const [];
                    if (bills.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.section),
                      child: UpcomingBillsSection(bills: bills, today: _today),
                    );
                  },
                ),
                FutureBuilder<MonthComparison?>(
                  future: _comparison,
                  builder: (context, snapshot) {
                    final comparison = snapshot.data;
                    if (comparison == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.section),
                      child: MonthComparisonCard(
                          comparison: comparison, onTap: _openStatistics),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one-time offer to import the September data bundled with the app.
class _ImportOfferCard extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onDismiss;

  const _ImportOfferCard({required this.onImport, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      key: const Key('import-offer'),
      margin: EdgeInsets.zero,
      color: palette.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('استيراد مصاريف سبتمبر',
                style: AppText.title
                    .copyWith(color: palette.onPrimaryContainer)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'ملاحظات سامسونج والإدخالات اليدوية ومتتبع الشغل جاهزين '
              'للاستيراد. هتراجعهم قبل ما يتسجلوا.',
              style:
                  AppText.body.copyWith(color: palette.onPrimaryContainer),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const Key('import-offer-import'),
                  onPressed: onImport,
                  child: const Text('استيراد'),
                ),
                TextButton(
                  key: const Key('import-offer-dismiss'),
                  onPressed: onDismiss,
                  child: const Text('مش دلوقتي'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
