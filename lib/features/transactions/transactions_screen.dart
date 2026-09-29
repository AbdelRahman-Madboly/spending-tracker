import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/photo_capture_service.dart';
import '../../data/voice_playback.dart';
import '../../domain/dashboard.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../../domain/transactions.dart';
import '../add/add_sheet.dart' show paymentMethodLabels;
import 'entry_detail_sheet.dart';
import 'widgets/transaction_tile.dart';

/// "اليوم", "أمس", else the weekday and date, e.g. "الجمعة 4 سبتمبر"
/// (spec §4.3's day headers).
String formatDayLabel(DateTime day, DateTime today) {
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  if (d == t) return 'اليوم';
  if (d == DateTime(t.year, t.month, t.day - 1)) return 'أمس';
  return '${arabicWeekdayName(d.weekday)} ${d.day} ${arabicMonthName(d.month)}';
}

String _dayMonth(DateTime d) => '${d.day} ${arabicMonthName(d.month)}';

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

/// From the 1st to the last day of one calendar month: statistics' month
/// history opens السجل on exactly this.
bool _isWholeMonth(DateTime from, DateTime to) =>
    from.day == 1 &&
    to.year == from.year &&
    to.month == from.month &&
    DateTime(to.year, to.month, to.day + 1).month != to.month;

const _attachmentKindLabels = {
  AttachmentKind.photo: 'صورة',
  AttachmentKind.voice: 'صوت',
  AttachmentKind.text: 'ملاحظة',
};

/// السجل (spec §4.3): every entry grouped by day under sticky headers with
/// the day's total, a capture's lines folded into one parent row, search
/// (Arabic-normalised) and filter chips for period, category, payment
/// method and attachments.
///
/// Swiping a row from the end side deletes it and swiping from the start
/// side opens the editor; a long press starts multi-select with bulk
/// category change and bulk delete. Every delete offers a 5-second undo.
///
/// Narrowed to a single day (the dashboard's "عرض الكل" does this) the
/// list shows a ‹ day › stepper with the day's total in place of the
/// sticky headers.
class TransactionsScreen extends StatefulWidget {
  final SpendingRepository repository;
  final DateTime Function() clock;

  /// The day to open on; null opens on every entry. Shorthand for a
  /// one-day [initialFilter], which wins when both are given.
  final DateTime? initialDay;

  /// What to open on, such as a month from statistics' history.
  final TransactionFilter? initialFilter;

  /// Bumped by the shell on every "show this" request. The filter alone is
  /// not enough: asking for today twice, with the user having stepped to
  /// yesterday in between, passes the same day both times.
  final int filterRequest;

  /// Passed to the entry detail sheet; the defaults are the real ones.
  final PhotoCaptureService? photoCaptureService;
  final VoicePlayback Function()? playbackFactory;

  const TransactionsScreen({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
    this.initialDay,
    this.initialFilter,
    this.filterRequest = 0,
    this.photoCaptureService,
    this.playbackFactory,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  SpendingRepository get _repo => widget.repository;

  late final Stream<List<TransactionView>> _transactions = _repo
      .watchTransactions();
  List<CategoryView> _categoryList = const [];
  Map<String, CategoryView> _categories = const {};

  TransactionFilter _filter = const TransactionFilter();
  bool _searching = false;
  final _search = TextEditingController();

  /// Ids chosen in multi-select; empty when not selecting.
  final Set<String> _selected = {};

  /// Ids deleted here and not undone. They are hidden at once, before the
  /// repository's stream catches up, so a dismissed row is never drawn
  /// again for a frame (Dismissible requires it to leave the tree).
  final Set<String> _hidden = {};

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _filter = _requested(widget) ?? const TransactionFilter();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _repo.categories();
    if (!mounted) return;
    setState(() {
      _categoryList = categories;
      _categories = {for (final c in categories) c.key: c};
    });
  }

  @override
  void didUpdateWidget(TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell reuses this screen when the dashboard asks for another day
    // or statistics for another month.
    final requested = _requested(widget);
    if (requested != null &&
        (requested != _requested(oldWidget) ||
            widget.filterRequest != oldWidget.filterRequest)) {
      _selected.clear();
      _filter = requested;
    }
  }

  static TransactionFilter? _requested(TransactionsScreen w) {
    final day = w.initialDay;
    return w.initialFilter ?? (day == null ? null : TransactionFilter.day(day));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Any change of filter (a chip, the search, the day stepper) ends the
  /// selection: a bulk action must only touch rows that are on screen.
  void _setFilter(TransactionFilter filter) => setState(() {
    _filter = filter;
    _selected.clear();
  });

  void _step(int days) {
    final from = _filter.from!;
    final day = DateTime(from.year, from.month, from.day + days);
    _setFilter(_filter.withRange(day, day));
  }

  // ---- selection ----

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(Iterable<String> ids) => setState(() {
    final all = ids.every(_selected.contains);
    if (all) {
      _selected.removeAll(ids);
    } else {
      _selected.addAll(ids);
    }
  });

  // ---- actions ----

  Future<void> _delete(List<String> ids) async {
    setState(() {
      _hidden.addAll(ids);
      _selected.clear();
    });
    try {
      await _repo.deleteEntries(ids);
    } catch (_) {
      // A swiped row must leave the tree before it can come back, so the
      // rows reappear only after the frame that hid them.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      setState(() => _hidden.removeAll(ids));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            key: Key('delete-failed'),
            content: Text('المسح ما نفعش، جرب تاني'),
          ),
        );
      return;
    }
    _offerUndo(ids);
  }

  void _offerUndo(List<String> ids) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('undo-snackbar'),
          content: Text(ids.length == 1 ? 'اتمسح' : 'اتمسح ${ids.length}'),
          duration: const Duration(seconds: 5),
          // An action normally keeps a snack bar up until tapped; the
          // undo is meant to lapse after five seconds (spec §8).
          persist: false,
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () async {
              await _repo.restoreEntries(ids);
              if (mounted) setState(() => _hidden.removeAll(ids));
            },
          ),
        ),
      );
  }

  Future<void> _openDetail(String id) async {
    final result = await showEntryDetail(
      context,
      repository: _repo,
      entryId: id,
      clock: widget.clock,
      photoCaptureService: widget.photoCaptureService,
      playbackFactory: widget.playbackFactory,
    );
    if (result?.outcome == EntryDetailOutcome.deleted) {
      setState(() => _hidden.add(result!.entryId));
      _offerUndo([result!.entryId]);
    }
  }

  Future<void> _recategorizeSelected() async {
    final key = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
                child: Text('انقل إلى', style: AppText.title),
              ),
              for (final c in _categoryList)
                ListTile(
                  key: Key('recategorize-${c.key}'),
                  leading: CategoryCircle(category: c),
                  title: Text(c.labelAr),
                  onTap: () => Navigator.of(sheetContext).pop(c.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (key == null || !mounted) return;
    await _repo.recategorizeEntries(_selected.toList(), key);
    if (!mounted) return;
    final label = _categories[key]?.labelAr ?? key;
    setState(_selected.clear);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('اتنقلت إلى $label')));
  }

  // ---- filters ----

  Future<void> _pickPeriod() async {
    final today = _today;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, label) in const [
              ('all', 'كل الأيام'),
              ('today', 'اليوم'),
              ('salary', 'فترة المرتب دي'),
              ('month', 'الشهر ده'),
              ('custom', 'مدة أختارها'),
            ])
              ListTile(
                key: Key('period-$key'),
                title: Text(label),
                onTap: () => Navigator.of(sheetContext).pop(key),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'all':
        _setFilter(_filter.withRange(null, null));
      case 'today':
        _setFilter(_filter.withRange(today, today));
      case 'month':
        _setFilter(_filter.withRange(DateTime(today.year, today.month), today));
      case 'salary':
        final period = await _repo.watchCurrentPeriod().first;
        if (!mounted) return;
        _setFilter(_filter.withRange(period.start, period.end));
      case 'custom':
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: today,
          initialDateRange: _filter.from == null
              ? null
              : DateTimeRange(start: _filter.from!, end: _filter.to ?? today),
        );
        if (range != null && mounted) {
          _setFilter(_filter.withRange(range.start, range.end));
        }
    }
  }

  /// A sheet of chips to pick any number of [options] (key to label),
  /// starting from [current]. Null when dismissed without تم.
  Future<Set<T>?> _pickSet<T>(
    String title,
    Map<T, String> options,
    Set<T> current,
    String Function(T) keyOf,
  ) {
    final picked = {...current};
    return showModalBottomSheet<Set<T>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.title),
                const SizedBox(height: AppSpacing.ms),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final MapEntry(key: value, value: label)
                        in options.entries)
                      FilterChip(
                        key: Key('filter-option-${keyOf(value)}'),
                        label: Text(label),
                        selected: picked.contains(value),
                        onSelected: (on) => setSheetState(
                          () => on ? picked.add(value) : picked.remove(value),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('filter-apply'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(picked),
                  child: const Text('تم'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCategories() async {
    final picked = await _pickSet<String>(
      'الفئة',
      {for (final c in _categoryList) c.key: c.labelAr},
      _filter.categoryKeys,
      (k) => k,
    );
    if (picked != null) _setFilter(_filter.copyWith(categoryKeys: picked));
  }

  Future<void> _pickPayments() async {
    final picked = await _pickSet<String>(
      'طريقة الدفع',
      paymentMethodLabels,
      _filter.paymentMethods,
      (k) => k,
    );
    if (picked != null) _setFilter(_filter.copyWith(paymentMethods: picked));
  }

  Future<void> _pickAttachments() async {
    final picked = await _pickSet<AttachmentKind>(
      'فيه مرفق',
      _attachmentKindLabels,
      _filter.attachmentKinds,
      (k) => k.name,
    );
    if (picked != null) _setFilter(_filter.copyWith(attachmentKinds: picked));
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _searching = false;
      _filter = const TransactionFilter();
    });
  }

  void _closeSearch() {
    _search.clear();
    setState(() {
      _searching = false;
      _filter = _filter.copyWith(query: '');
    });
  }

  // ---- build ----

  PreferredSizeWidget _appBar() {
    if (_selecting) {
      return AppBar(
        leading: IconButton(
          key: const Key('selection-close'),
          tooltip: 'إلغاء التحديد',
          onPressed: () => setState(_selected.clear),
          icon: const Icon(AppIcons.close),
        ),
        title: Text('${_selected.length} محدد'),
        actions: [
          IconButton(
            key: const Key('bulk-category'),
            tooltip: 'غيّر الفئة',
            onPressed: _recategorizeSelected,
            icon: const Icon(AppIcons.recategorize),
          ),
          IconButton(
            key: const Key('bulk-delete'),
            tooltip: 'امسح',
            onPressed: () => _delete(_selected.toList()),
            icon: const Icon(AppIcons.delete),
          ),
        ],
      );
    }
    if (_searching) {
      return AppBar(
        leading: IconButton(
          key: const Key('search-close'),
          tooltip: 'إغلاق البحث',
          onPressed: _closeSearch,
          icon: const Icon(AppIcons.close),
        ),
        title: TextField(
          key: const Key('transactions-search-field'),
          controller: _search,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'دور على اسم أو ملاحظة',
            border: InputBorder.none,
          ),
          onChanged: (text) => _setFilter(_filter.copyWith(query: text)),
        ),
      );
    }
    return AppBar(
      title: const Text('السجل'),
      actions: [
        IconButton(
          key: const Key('transactions-search'),
          tooltip: 'بحث',
          onPressed: () => setState(() => _searching = true),
          icon: const Icon(AppIcons.search),
        ),
      ],
    );
  }

  Widget _filterBar() {
    final f = _filter;
    String periodLabel() {
      final from = f.from;
      final to = f.to;
      if (from == null && to == null) return 'الفترة';
      if (f.isSingleDay) return _dayMonth(from!);
      if (from != null && to != null && _isWholeMonth(from, to)) {
        return '${arabicMonthName(from.month)} ${from.year}';
      }
      return '${from == null ? '…' : _dayMonth(from)} – '
          '${to == null ? '…' : _dayMonth(to)}';
    }

    String counted(String label, int n) => n == 0 ? label : '$label ($n)';

    Widget chip(String key, String label, bool active, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
          child: FilterChip(
            key: Key('filter-$key'),
            label: Text(label),
            selected: active,
            showCheckmark: false,
            // Off while selecting, so the selection cannot outlive the
            // rows it was made on.
            onSelected: _selecting ? null : (_) => onTap(),
          ),
        );

    // A Row, not a lazy ListView: four chips, and each must exist for
    // screen readers and tests whatever the scroll position.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          chip(
            'period',
            periodLabel(),
            f.from != null || f.to != null,
            _pickPeriod,
          ),
          chip(
            'category',
            counted('الفئة', f.categoryKeys.length),
            f.categoryKeys.isNotEmpty,
            _pickCategories,
          ),
          chip(
            'payment',
            counted('الدفع', f.paymentMethods.length),
            f.paymentMethods.isNotEmpty,
            _pickPayments,
          ),
          chip(
            'attachment',
            counted('مرفقات', f.attachmentKinds.length),
            f.attachmentKinds.isNotEmpty,
            _pickAttachments,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selecting && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selecting) {
          setState(_selected.clear);
        } else if (_searching) {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: _appBar(),
        body: Column(
          children: [
            _filterBar(),
            Expanded(
              child: StreamBuilder<List<TransactionView>>(
                stream: _transactions,
                builder: (context, snapshot) => _list(snapshot.data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<TransactionView>? all) {
    final dayMode = _filter.isSingleDay;
    final visible = all == null
        ? null
        : [
            for (final t in all)
              if (!_hidden.contains(t.id) && _filter.matches(t)) t,
          ];
    final days = visible == null ? null : groupTransactions(visible);
    final slivers = <Widget>[
      if (dayMode)
        SliverToBoxAdapter(
          child: _DayStepper(
            day: _filter.from!,
            today: _today,
            totalPiastres: days?.firstOrNull?.totalPiastres,
            count: visible?.length,
            onStep: _step,
            onClear: () => _setFilter(_filter.withRange(null, null)),
          ),
        ),
    ];
    if (days == null) {
      slivers.add(
        const SliverPadding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.gutter,
          ),
          sliver: SliverToBoxAdapter(child: SkeletonRows()),
        ),
      );
    } else if (days.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: _empty(dayMode)));
    } else {
      for (final day in days) {
        final rows = SliverList.builder(
          itemCount: day.rows.length,
          itemBuilder: (context, i) => _row(day.rows[i]),
        );
        slivers.add(
          SliverPadding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
            ),
            sliver: dayMode
                ? rows
                : SliverMainAxisGroup(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _DayHeaderDelegate(
                          label: formatDayLabel(day.day, _today),
                          totalPiastres: day.totalPiastres,
                          totalKey: Key('day-total-${_isoDay(day.day)}'),
                          background: context.palette.bg,
                        ),
                      ),
                      rows,
                    ],
                  ),
          ),
        );
      }
    }
    // Room for the docked FAB.
    slivers.add(
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl * 2)),
    );
    return CustomScrollView(slivers: slivers);
  }

  Widget _empty(bool dayMode) {
    if (dayMode && _filter == TransactionFilter.day(_filter.from!)) {
      return const EmptyState(
        icon: AppIcons.emptyReceipt,
        headline: 'مفيش مصاريف في اليوم ده',
        caption: 'اللي تسجله هيظهر هنا',
      );
    }
    if (_filter.isEmpty) {
      return const EmptyState(
        icon: AppIcons.emptyReceipt,
        headline: 'مفيش مصاريف لسه',
        caption: 'اللي تسجله هيظهر هنا',
      );
    }
    return Column(
      children: [
        const EmptyState(
          icon: AppIcons.search,
          headline: 'مفيش نتائج',
          caption: 'جرب كلمة تانية أو فلاتر أقل',
        ),
        TextButton(
          key: const Key('filters-clear'),
          onPressed: _clearFilters,
          child: const Text('امسح الفلاتر'),
        ),
      ],
    );
  }

  Widget _row(TransactionRow row) => switch (row) {
    SingleTransactionRow(:final entry) => _single(entry),
    CaptureGroupRow() => CaptureGroupTile(
      key: ValueKey('group-${row.captureGroupId}'),
      row: row,
      category: _categories[row.lines.first.categoryKey],
      selected: row.lines.every((l) => _selected.contains(l.id)),
      onTap: _selecting
          ? () => _toggle([for (final l in row.lines) l.id])
          : null,
      onLongPress: () => _toggle([for (final l in row.lines) l.id]),
      lineBuilder: (context, line) => _single(line),
    ),
  };

  Widget _single(TransactionView entry) {
    final palette = context.palette;
    Widget swipeBackground(
      IconData icon,
      String label,
      Color color,
      bool atStart,
    ) => Container(
      color: color,
      alignment: atStart
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppText.label.copyWith(color: Colors.white)),
        ],
      ),
    );
    return Dismissible(
      key: ValueKey('dismiss-${entry.id}'),
      direction: _selecting
          ? DismissDirection.none
          : DismissDirection.horizontal,
      // Start side (the right, in RTL): edit. End side: delete.
      background: swipeBackground(
        AppIcons.edit,
        'تعديل',
        palette.primary,
        true,
      ),
      secondaryBackground: swipeBackground(
        AppIcons.delete,
        'مسح',
        palette.negative,
        false,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _openDetail(entry.id);
          return false;
        }
        return true;
      },
      onDismissed: (_) => _delete([entry.id]),
      child: TransactionTile(
        key: Key('row-${entry.id}'),
        entry: entry,
        category: _categories[entry.categoryKey],
        selected: _selected.contains(entry.id),
        onTap: _selecting
            ? () => _toggle([entry.id])
            : () => _openDetail(entry.id),
        onLongPress: () => _toggle([entry.id]),
      ),
    );
  }
}

/// The ‹ day › stepper shown when السجل is narrowed to one day, with the
/// day's count and total and a close that widens back to every day.
class _DayStepper extends StatelessWidget {
  final DateTime day;
  final DateTime today;
  final int? totalPiastres;
  final int? count;
  final ValueChanged<int> onStep;
  final VoidCallback onClear;

  const _DayStepper({
    required this.day,
    required this.today,
    required this.totalPiastres,
    required this.count,
    required this.onStep,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final atToday = !day.isBefore(today);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.gutter,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('day-previous'),
                tooltip: 'اليوم اللي قبله',
                onPressed: () => onStep(-1),
                icon: const Icon(AppIcons.chevronStart),
              ),
              Expanded(
                child: Text(
                  formatDayLabel(day, today),
                  key: const Key('day-label'),
                  textAlign: TextAlign.center,
                  style: AppText.title,
                ),
              ),
              IconButton(
                key: const Key('day-next'),
                tooltip: 'اليوم اللي بعده',
                onPressed: atToday ? null : () => onStep(1),
                icon: const Icon(AppIcons.chevronEnd),
              ),
              IconButton(
                key: const Key('day-clear'),
                tooltip: 'كل الأيام',
                onPressed: onClear,
                icon: const Icon(AppIcons.close),
              ),
            ],
          ),
          if ((count ?? 0) > 0)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    '$count مصروف',
                    style: AppText.label.copyWith(color: palette.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    formatPiastres(totalPiastres ?? 0, withCurrency: true),
                    key: const Key('day-total'),
                    textDirection: TextDirection.ltr,
                    style: AppText.bodyStrong,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A sticky day header: the day's label on the start side, its total on
/// the end side.
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final int totalPiastres;
  final Key totalKey;
  final Color background;

  const _DayHeaderDelegate({
    required this.label,
    required this.totalPiastres,
    required this.totalKey,
    required this.background,
  });

  static const _height = 44.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = context.palette;
    return Container(
      color: background,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            formatPiastres(totalPiastres, withCurrency: true),
            key: totalKey,
            textDirection: TextDirection.ltr,
            style: AppText.label.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate old) =>
      old.label != label ||
      old.totalPiastres != totalPiastres ||
      old.background != background;
}
