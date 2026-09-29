import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../data/bill_reminders.dart';
import '../../domain/bills.dart';
import '../../domain/dashboard.dart' show arabicMonthName;
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';

String _dueText(DateTime d) => '${d.day} ${arabicMonthName(d.month)}';

String _everyText(int months) => switch (months) {
      1 => 'كل شهر',
      2 => 'كل شهرين',
      12 => 'كل سنة',
      _ => 'كل $months شهور',
    };

/// Settings -> الفواتير المتكررة: the live bills with add, edit, archive
/// and دفعت, the bills history suggests, and on first use a card that
/// explains the notification permission before asking for it.
class RecurringBillsScreen extends StatefulWidget {
  final SpendingRepository repository;

  /// Defaults to [BillReminders.shared].
  final BillReminders? reminders;
  final DateTime Function() clock;

  const RecurringBillsScreen({
    super.key,
    required this.repository,
    this.reminders,
    this.clock = DateTime.now,
  });

  @override
  State<RecurringBillsScreen> createState() => _RecurringBillsScreenState();
}

class _RecurringBillsScreenState extends State<RecurringBillsScreen> {
  SpendingRepository get _repo => widget.repository;
  late final BillReminders _reminders =
      widget.reminders ?? BillReminders.shared;

  List<RecurringBillView> _bills = const [];
  List<BillSuggestion> _suggestions = const [];
  List<CategoryView> _categories = const [];
  Set<String> _dismissed = {};
  bool _askPermission = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bills = await _repo.recurringBills();
    final categories = await _repo.categories();
    final history = await _repo.watchTransactions().first;
    final dismissed = decodeDismissedSuggestions(
        await _repo.setting(dismissedBillSuggestionsSettingKey));
    final asked = await _repo.setting(billRemindersPermissionAskedSettingKey);
    if (!mounted) return;
    setState(() {
      _bills = bills;
      _categories = categories;
      _dismissed = dismissed;
      _suggestions = suggestBills(
        history: history,
        bills: bills,
        today: widget.clock(),
        dismissed: dismissed,
      );
      _askPermission = asked == null;
      _loaded = true;
    });
  }

  /// Reloads the list and puts the reminders in line with it.
  Future<void> _changed() async {
    await _load();
    await _reminders.reschedule(_bills);
  }

  void _say(String text, {Key? key, SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(key: key, content: Text(text), action: action));
  }

  /// One write at a time, so a double tap cannot pay or add twice. A
  /// failure is said, never thrown.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) _say('ما نفعش، جرب تاني', key: const Key('bills-failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answerPermission(bool allow) => _run(() async {
        if (allow) await _reminders.requestPermission();
        await _repo.setSetting(billRemindersPermissionAskedSettingKey, '1');
        if (mounted) setState(() => _askPermission = false);
        if (allow) await _reminders.reschedule(_bills);
      });

  Future<void> _edit([RecurringBillView? bill]) async {
    final result = await showModalBottomSheet<_BillDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BillEditor(
        bill: bill,
        categories: _categories,
        repository: _repo,
      ),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      final today = widget.clock();
      if (bill == null) {
        await _repo.createRecurringBill(
          nameAr: result.nameAr,
          amountPiastres: result.amountPiastres,
          categoryKey: result.categoryKey,
          subcategoryKey: result.subcategoryKey,
          everyMonths: result.everyMonths,
          nextDue: nextDueOnDay(result.dueDay, today),
          remindDaysBefore: result.remindDaysBefore,
        );
      } else {
        await _repo.updateRecurringBill(RecurringBillView(
          id: bill.id,
          nameAr: result.nameAr,
          amountPiastres: result.amountPiastres,
          categoryKey: result.categoryKey,
          subcategoryKey: result.subcategoryKey,
          everyMonths: result.everyMonths,
          // The same day keeps the due date (even an overdue one); a new
          // day starts from today.
          nextDue: result.dueDay == bill.nextDue.day
              ? bill.nextDue
              : nextDueOnDay(result.dueDay, today),
          remindDaysBefore: result.remindDaysBefore,
        ));
      }
      await _changed();
    });
  }

  Future<void> _pay(RecurringBillView bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('bill-pay-dialog'),
        content: Text('تسجل ${bill.nameAr} بـ '
            '${formatPiastres(bill.amountPiastres)} جنيه في مصاريف النهارده؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('bill-pay-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('سجل'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      final paid = await _repo.payRecurringBill(bill.id, widget.clock(),
          expectedDue: bill.nextDue);
      await _changed();
      if (mounted) {
        _say('اتسجلت، الجاية ${_dueText(paid.nextDue)}',
            key: const Key('bill-paid-snackbar'));
      }
    });
  }

  Future<void> _archive(RecurringBillView bill) => _run(() async {
        await _repo.archiveRecurringBill(bill.id);
        await _changed();
        if (mounted) {
          _say(
            'اتشالت ${bill.nameAr}',
            action: SnackBarAction(
              label: 'تراجع',
              onPressed: () => _run(() async {
                // The bill as it was, not archived.
                await _repo.updateRecurringBill(bill);
                await _changed();
              }),
            ),
          );
        }
      });

  Future<void> _addSuggestion(BillSuggestion s) => _run(() async {
        await _repo.createRecurringBill(
          nameAr: s.nameAr,
          amountPiastres: s.amountPiastres,
          categoryKey: s.categoryKey,
          subcategoryKey: s.subcategoryKey,
          nextDue: s.nextDue,
        );
        await _changed();
      });

  Future<void> _dismiss(BillSuggestion s) => _run(() async {
        await _repo.setSetting(dismissedBillSuggestionsSettingKey,
            encodeDismissedSuggestions({..._dismissed, s.key}));
        await _load();
      });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير المتكررة')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-bill'),
        onPressed: _busy || !_loaded ? null : () => _edit(),
        icon: const Icon(AppIcons.add),
        label: const Text('فاتورة جديدة'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.gutter,
                  AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl * 2),
              children: [
                if (_askPermission) _permissionCard(palette),
                if (_bills.isEmpty)
                  Padding(
                    key: const Key('bills-empty'),
                    padding: const EdgeInsetsDirectional.symmetric(
                        vertical: AppSpacing.lg),
                    child: Text(
                      'مفيش فواتير متكررة لسه. ضيف واحدة، أو من «كرر شهرياً» '
                      'في تفاصيل أي مصروف.',
                      style: AppText.body
                          .copyWith(color: palette.textSecondary),
                    ),
                  ),
                for (final bill in _bills) _billTile(bill, palette),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text('اقتراحات من مصاريفك', style: AppText.title),
                  const SizedBox(height: AppSpacing.sm),
                  for (final s in _suggestions) _suggestionTile(s, palette),
                ],
              ],
            ),
    );
  }

  Widget _permissionCard(AppPalette palette) => Card(
        key: const Key('bills-permission-card'),
        margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('تذكير قبل ميعاد الفاتورة', style: AppText.bodyStrong),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'عشان نفكرك بالفاتورة قبل ميعادها بكام يوم، التطبيق محتاج '
                'إذن الإشعارات. التذكير بيطلع من الموبايل نفسه من غير نت، '
                'ومش هنبعت غيره.',
                style: AppText.body.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    key: const Key('bills-permission-later'),
                    onPressed: _busy ? null : () => _answerPermission(false),
                    child: const Text('مش دلوقتي'),
                  ),
                  FilledButton(
                    key: const Key('bills-permission-allow'),
                    onPressed: _busy ? null : () => _answerPermission(true),
                    child: const Text('فعّل التذكير'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _billTile(RecurringBillView bill, AppPalette palette) {
    final today = widget.clock();
    final overdue =
        bill.nextDue.isBefore(DateTime(today.year, today.month, today.day));
    return ListTile(
      key: ValueKey('bill-${bill.id}'),
      contentPadding: EdgeInsetsDirectional.zero,
      leading: Icon(AppIcons.bill, color: palette.primary),
      title: Text(bill.nameAr, style: AppText.body),
      subtitle: Text(
        '${formatPiastres(bill.amountPiastres)} جنيه · '
        '${overdue ? 'فات ميعادها' : 'الجاية'} ${_dueText(bill.nextDue)} · '
        '${_everyText(bill.everyMonths)}',
        style: AppText.caption.copyWith(
            color: overdue ? palette.negative : palette.textSecondary),
      ),
      onTap: _busy ? null : () => _edit(bill),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: ValueKey('bill-pay-${bill.id}'),
            onPressed: _busy ? null : () => _pay(bill),
            child: const Text('دفعت'),
          ),
          IconButton(
            key: ValueKey('bill-archive-${bill.id}'),
            icon: const Icon(AppIcons.archive),
            tooltip: 'شيل',
            onPressed: _busy ? null : () => _archive(bill),
          ),
        ],
      ),
    );
  }

  Widget _suggestionTile(BillSuggestion s, AppPalette palette) => ListTile(
        key: ValueKey('suggestion-${s.key}'),
        contentPadding: EdgeInsetsDirectional.zero,
        leading: Icon(AppIcons.enhance, color: palette.textSecondary),
        title: Text(s.nameAr, style: AppText.body),
        subtitle: Text(
          '${formatPiastres(s.amountPiastres)} جنيه · '
          'الجاية ${_dueText(s.nextDue)} · كل شهر',
          style: AppText.caption.copyWith(color: palette.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: ValueKey('suggestion-dismiss-${s.key}'),
              onPressed: _busy ? null : () => _dismiss(s),
              child: const Text('تجاهل'),
            ),
            FilledButton(
              key: ValueKey('suggestion-add-${s.key}'),
              onPressed: _busy ? null : () => _addSuggestion(s),
              child: const Text('أضف'),
            ),
          ],
        ),
      );
}

class _BillDraft {
  final String nameAr;
  final int amountPiastres;
  final String categoryKey;
  final String? subcategoryKey;
  final int dueDay;
  final int everyMonths;
  final int remindDaysBefore;

  const _BillDraft({
    required this.nameAr,
    required this.amountPiastres,
    required this.categoryKey,
    required this.subcategoryKey,
    required this.dueDay,
    required this.everyMonths,
    required this.remindDaysBefore,
  });
}

class _BillEditor extends StatefulWidget {
  final RecurringBillView? bill;
  final List<CategoryView> categories;
  final SpendingRepository repository;

  const _BillEditor({
    required this.bill,
    required this.categories,
    required this.repository,
  });

  @override
  State<_BillEditor> createState() => _BillEditorState();
}

class _BillEditorState extends State<_BillEditor> {
  late final _name = TextEditingController(text: widget.bill?.nameAr ?? '');
  late final _amount = TextEditingController(
      text: widget.bill == null
          ? ''
          : formatPiastres(widget.bill!.amountPiastres));
  late final _day =
      TextEditingController(text: widget.bill?.nextDue.day.toString() ?? '');
  late String _category = widget.bill?.categoryKey ??
      (widget.categories.any((c) => c.key == 'Bills')
          ? 'Bills'
          : widget.categories.firstOrNull?.key ?? 'Other');
  late String? _subcategory = widget.bill?.subcategoryKey;
  late int _every = widget.bill?.everyMonths ?? 1;
  late int _remind = widget.bill?.remindDaysBefore ?? 2;
  List<SubcategoryView> _subcategories = const [];
  String? _nameError;
  String? _amountError;
  String? _dayError;

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  Future<void> _loadSubcategories() async {
    final subs = await widget.repository.subcategories(_category);
    if (!mounted) return;
    setState(() {
      _subcategories = subs;
      if (!subs.any((s) => s.key == _subcategory)) _subcategory = null;
    });
  }

  void _save() {
    final name = _name.text.trim();
    final amount = parsePiastres(_amount.text);
    final day = int.tryParse(_day.text.trim());
    setState(() {
      _nameError = name.isEmpty ? 'اكتب اسم الفاتورة' : null;
      _amountError = amount == null || amount <= 0 ? 'قيمة غير صحيحة' : null;
      _dayError = day == null || day < 1 || day > 31 ? 'من 1 لـ 31' : null;
    });
    if (_nameError != null || _amountError != null || _dayError != null) {
      return;
    }
    Navigator.of(context).pop(_BillDraft(
      nameAr: name,
      amountPiastres: amount!,
      categoryKey: _category,
      subcategoryKey: _subcategory,
      dueDay: day!,
      everyMonths: _every,
      remindDaysBefore: _remind,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      ...widget.categories,
      // A bill filed under a category archived since still shows it.
      if (!widget.categories.any((c) => c.key == _category))
        CategoryView(key: _category, labelAr: _category, iconName: ''),
    ];
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(AppSpacing.gutter, 0,
          AppSpacing.gutter,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.bill == null ? 'فاتورة جديدة' : 'تعديل الفاتورة',
                style: AppText.title),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('bill-name'),
              controller: _name,
              decoration:
                  InputDecoration(labelText: 'الاسم', errorText: _nameError),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('bill-amount'),
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'المبلغ', errorText: _amountError),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: const Key('bill-day'),
                    controller: _day,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'يوم الاستحقاق', errorText: _dayError),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: const Key('bill-category'),
              isExpanded: true,
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'الفئة'),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.key, child: Text(c.labelAr)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
                _loadSubcategories();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              key: ValueKey('bill-subcategory-$_category'),
              isExpanded: true,
              initialValue: _subcategory,
              decoration: const InputDecoration(labelText: 'الفئة الفرعية'),
              items: [
                const DropdownMenuItem(value: null, child: Text('بدون')),
                for (final s in _subcategories)
                  DropdownMenuItem(value: s.key, child: Text(s.labelAr)),
              ],
              onChanged: (value) => setState(() => _subcategory = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('bill-every'),
                    isExpanded: true,
                    initialValue: _every,
                    decoration: const InputDecoration(labelText: 'بتتكرر'),
                    items: [
                      for (final m in {1, 2, 3, 6, 12, _every})
                        DropdownMenuItem(value: m, child: Text(_everyText(m))),
                    ],
                    onChanged: (v) => setState(() => _every = v ?? _every),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('bill-remind'),
                    isExpanded: true,
                    initialValue: _remind,
                    decoration: const InputDecoration(labelText: 'فكرني قبلها'),
                    items: [
                      for (final d in {0, 1, 2, 3, 5, 7, _remind})
                        DropdownMenuItem(
                          value: d,
                          child: Text(d == 0 ? 'يومها' : 'بـ $d يوم'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _remind = v ?? _remind),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('bill-save'),
              onPressed: _save,
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
