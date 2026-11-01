import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../core/amount_expression.dart';
import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../core/quantity.dart';
import '../../data/bill_reminders.dart';
import '../../data/document_picker_service.dart';
import '../../data/photo_capture_service.dart';
import '../../data/voice_playback.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../../domain/transactions.dart';
import '../add/add_sheet.dart' show keypadText, paymentMethodLabels;
import '../add/widgets/amount_keypad.dart';
import '../add/widgets/category_strip.dart';
import '../add/widgets/subcategory_strip.dart';
import 'widgets/attachment_strip.dart';

enum EntryDetailOutcome { saved, deleted }

/// How the detail sheet closed. [entryId] is the entry acted on, which is
/// not always the one opened: the sheet can move to a sibling line.
class EntryDetailResult {
  final EntryDetailOutcome outcome;
  final String entryId;

  const EntryDetailResult(this.outcome, this.entryId);
}

/// Opens the entry detail sheet (spec §4.4) full height. Resolves to what
/// happened, or null when it was just closed. A delete is done by the
/// sheet; the caller offers the undo, since the sheet is gone by then.
Future<EntryDetailResult?> showEntryDetail(
  BuildContext context, {
  required SpendingRepository repository,
  required String entryId,
  DateTime Function() clock = DateTime.now,
  PhotoCaptureService? photoCaptureService,
  DocumentPickerService? documentPicker,
  VoicePlayback Function()? playbackFactory,
}) => showModalBottomSheet<EntryDetailResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
  ),
  builder: (_) => FractionallySizedBox(
    heightFactor: 1,
    child: EntryDetailSheet(
      repository: repository,
      entryId: entryId,
      clock: clock,
      photoCaptureService: photoCaptureService,
      documentPicker: documentPicker,
      playbackFactory: playbackFactory,
    ),
  ),
);

/// The entry detail sheet: the attachments on top, then every field
/// editable in place (amount on the keypad, quantity and unit, date,
/// category → subcategory → item, payment method, note), the other lines
/// of its capture, and the actions تكرار اليوم, كرر شهرياً, إضافة مرفق and
/// حذف. حفظ writes the fields and stamps `updatedAt`.
class EntryDetailSheet extends StatefulWidget {
  final SpendingRepository repository;
  final String entryId;
  final DateTime Function() clock;

  /// Defaults to the real image_picker one, created on first use; also
  /// resolves every attachment's relative path for display.
  final PhotoCaptureService? photoCaptureService;

  /// Picks a PDF to keep as a file; defaults to the system document picker.
  final DocumentPickerService? documentPicker;

  /// Defaults to just_audio, created only when a voice note is played.
  final VoicePlayback Function()? playbackFactory;

  const EntryDetailSheet({
    super.key,
    required this.repository,
    required this.entryId,
    this.clock = DateTime.now,
    this.photoCaptureService,
    this.documentPicker,
    this.playbackFactory,
  });

  @override
  State<EntryDetailSheet> createState() => _EntryDetailSheetState();
}

class _EntryDetailSheetState extends State<EntryDetailSheet> {
  SpendingRepository get _repo => widget.repository;

  PhotoCaptureService? _photoCaptureService;
  PhotoCaptureService get _photos => _photoCaptureService ??=
      widget.photoCaptureService ?? ImagePickerPhotoCaptureService();

  DocumentPickerService? _documentPicker;
  DocumentPickerService get _documents =>
      _documentPicker ??= widget.documentPicker ?? FilePickerDocumentService();

  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _note = TextEditingController();

  /// Null while loading, and after the entry turned out to be gone.
  EntryRecord? _entry;
  bool _missing = false;
  bool _busy = false;

  String _expression = '';
  bool _filled = false;
  bool _keypadOpen = false;
  late DateTime _date;
  late String _categoryKey;
  String? _subcategoryKey;
  String? _itemId;
  String? _unit;
  late String _paymentMethod;

  List<AttachmentView> _attachments = const [];
  List<CategoryView> _categories = const [];
  List<SubcategoryView> _subcategories = const [];
  List<QuickPickItem> _items = const [];
  List<EntryRecord> _siblings = const [];

  @override
  void initState() {
    super.initState();
    _load(widget.entryId);
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final entry = await _repo.entry(id);
    if (!mounted) return;
    if (entry == null) {
      setState(() => _missing = true);
      return;
    }
    final categories = await _repo.categories();
    final attachments = await _repo.attachmentsForEntry(id);
    final groupId = entry.captureGroupId;
    final group = groupId == null ? null : await _repo.captureGroup(groupId);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _expression = keypadText(entry.amountPiastres);
      _filled = true;
      _keypadOpen = false;
      _date = entry.date;
      _categoryKey = entry.categoryKey;
      _subcategoryKey = entry.subcategoryKey;
      _itemId = entry.itemId;
      _unit = entry.unit;
      _paymentMethod = entry.paymentMethod;
      _name.text = entry.description;
      _quantity.text = entry.quantityMilli == null
          ? ''
          : formatQuantityMilli(entry.quantityMilli!);
      _note.text = entry.note ?? '';
      _categories = categories;
      _attachments = attachments;
      _siblings = [
        for (final e in group?.entries ?? const <EntryRecord>[])
          if (e.id != id) e,
      ];
    });
    await _loadCategoryChoices();
  }

  /// The subcategory and item strips under the chosen category.
  Future<void> _loadCategoryChoices() async {
    final subcategories = await _repo.subcategories(_categoryKey);
    final subKey = _subcategoryKey;
    final items = subKey != null
        ? await _repo.itemsInSubcategory(subKey, 12)
        : await _repo.itemsInCategory(_categoryKey, 12);
    if (mounted) {
      setState(() {
        _subcategories = subcategories;
        _items = items;
      });
    }
  }

  int? get _amount => evaluateAmountExpression(_expression);

  void _press(String key) => setState(() {
    final next = pressKeypadKey(_expression, _filled, key);
    _expression = next.expression;
    _filled = next.filled;
  });

  void _selectCategory(String? key) {
    // The strip's الكل chip means nothing here: an entry always has one.
    if (key == null || key == _categoryKey) return;
    setState(() {
      _categoryKey = key;
      _subcategoryKey = null;
      _itemId = null;
    });
    _loadCategoryChoices();
  }

  void _selectSubcategory(String? key) {
    setState(() {
      _subcategoryKey = key;
      _itemId = null;
    });
    _loadCategoryChoices();
  }

  void _selectItem(QuickPickItem item) => setState(() {
    _itemId = item.id;
    _name.text = item.nameAr;
    if (item.subcategoryKey != null) _subcategoryKey = item.subcategoryKey;
  });

  void _say(String message, {Key? key}) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(key: key, content: Text(message)));
  }

  Future<void> _pickDate() async {
    final now = widget.clock();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  /// Whether any field differs from the stored entry, so leaving for a
  /// sibling line would drop edits.
  bool get _isDirty {
    final entry = _entry;
    if (entry == null) return false;
    final storedQuantity = entry.quantityMilli == null
        ? ''
        : formatQuantityMilli(entry.quantityMilli!);
    return _amount != entry.amountPiastres ||
        _date != entry.date ||
        _categoryKey != entry.categoryKey ||
        _subcategoryKey != entry.subcategoryKey ||
        _itemId != entry.itemId ||
        _unit != entry.unit ||
        _paymentMethod != entry.paymentMethod ||
        _name.text.trim() != entry.description ||
        _quantity.text.trim() != storedQuantity ||
        _note.text.trim() != (entry.note ?? '');
  }

  /// The entry as the fields now stand, or null (after saying why) when
  /// the amount or quantity does not read.
  EntryRecord? _edited() {
    final entry = _entry;
    final amount = _amount;
    if (entry == null) return null;
    if (amount == null || amount <= 0) {
      _say('اكتب مبلغ أكبر من صفر');
      return null;
    }
    final quantityText = _quantity.text.trim();
    final quantity = quantityText.isEmpty
        ? null
        : parseQuantityMilli(quantityText);
    if (quantityText.isNotEmpty && quantity == null) {
      _say('الكمية مش مظبوطة');
      return null;
    }
    final note = _note.text.trim();
    return EntryRecord(
      id: entry.id,
      date: _date,
      amountPiastres: amount,
      categoryKey: _categoryKey,
      subcategoryKey: _subcategoryKey,
      itemId: _itemId,
      description: _name.text.trim(),
      paymentMethod: _paymentMethod,
      source: entry.source,
      quantityMilli: quantity,
      unit: _unit,
      // A unit price no longer holds once amount or quantity changed.
      unitPricePiastres:
          amount == entry.amountPiastres && quantity == entry.quantityMilli
          ? entry.unitPricePiastres
          : null,
      captureGroupId: entry.captureGroupId,
      externalId: entry.externalId,
      reference: entry.reference,
      note: note.isEmpty ? null : note,
    );
  }

  /// Runs one action at a time: while it runs every action and حفظ are
  /// off, so a double tap cannot make two copies or two bills. A failure
  /// (a write, or the camera refusing) is said in a snackbar and turns
  /// them back on; an action that closes the sheet leaves them off.
  Future<void> _run(
    Future<void> Function() action, {
    String failure = 'ما نفعش، جرب تاني',
    Key failureKey = const Key('detail-action-failed'),
  }) async {
    if (_busy || _entry == null) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) _say(failure, key: failureKey);
    } finally {
      // After a pop the state is unmounted and there is nothing to reset.
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final edited = _edited();
    if (edited == null) return;
    await _run(
      () async {
        await _repo.updateEntry(edited);
        if (mounted) {
          Navigator.of(
            context,
          ).pop(EntryDetailResult(EntryDetailOutcome.saved, edited.id));
        }
      },
      failure: 'الحفظ ما نفعش، جرب تاني',
      failureKey: const Key('detail-save-failed'),
    );
  }

  /// Opens a sibling line in place. With unsaved edits it asks first:
  /// حفظ writes them, تجاهل drops them, إلغاء stays on this entry.
  Future<void> _openSibling(String id) async {
    if (_busy) return;
    if (!_isDirty) {
      await _load(id);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('unsaved-dialog'),
        content: const Text('فيه تعديلات مش محفوظة. تحفظها الأول؟'),
        actions: [
          TextButton(
            key: const Key('unsaved-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            key: const Key('unsaved-discard'),
            onPressed: () => Navigator.of(dialogContext).pop('discard'),
            child: const Text('تجاهل'),
          ),
          FilledButton(
            key: const Key('unsaved-save'),
            onPressed: () => Navigator.of(dialogContext).pop('save'),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'discard') {
      await _load(id);
      return;
    }
    final edited = _edited();
    if (edited == null) return;
    await _run(
      () async {
        await _repo.updateEntry(edited);
        await _load(id);
      },
      failure: 'الحفظ ما نفعش، جرب تاني',
      failureKey: const Key('detail-save-failed'),
    );
  }

  Future<void> _duplicate() => _run(() async {
    await _repo.duplicateEntry(_entry!.id, widget.clock());
    _say('اتكرر النهارده');
  });

  Future<void> _repeatMonthly() => _run(() async {
    final entry = _entry!;
    final name = entry.description.isNotEmpty
        ? entry.description
        : _categories
                  .where((c) => c.key == entry.categoryKey)
                  .map((c) => c.labelAr)
                  .firstOrNull ??
              entry.categoryKey;
    await _repo.createRecurringBill(
      nameAr: name,
      amountPiastres: entry.amountPiastres,
      categoryKey: entry.categoryKey,
      subcategoryKey: entry.subcategoryKey,
      nextDue: nextMonthlyDue(entry.date, widget.clock()),
    );
    _say('اتعملت فاتورة شهرية');
    unawaited(BillReminders.shared.rescheduleFrom(_repo));
  });

  Future<void> _delete() => _run(() async {
    final entry = _entry!;
    await _repo.deleteEntries([entry.id]);
    if (mounted) {
      Navigator.of(
        context,
      ).pop(EntryDetailResult(EntryDetailOutcome.deleted, entry.id));
    }
  });

  Future<void> _addAttachment() => _run(_attach);

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, icon, label) in const [
              ('camera', AppIcons.camera, 'صورة بالكاميرا'),
              ('gallery', AppIcons.gallery, 'صورة من المعرض'),
              ('text', AppIcons.textNote, 'ملاحظة مكتوبة'),
              ('pdf', AppIcons.pdf, 'ملف PDF'),
            ])
              ListTile(
                key: Key('attach-$key'),
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(sheetContext).pop(key),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final entry = _entry;
    if (entry == null) return;
    DraftAttachment? attachment;
    switch (choice) {
      case 'text':
        final text = await _askText();
        if (text != null && text.isNotEmpty) {
          attachment = DraftAttachment(kind: AttachmentKind.text, text: text);
        }
      case 'pdf':
        // The name it was picked by is what the card shows (spec §6.2).
        final picked = await _documents.pickPdf();
        if (picked != null) {
          attachment = DraftAttachment(
            kind: AttachmentKind.file,
            path: picked.relativePath,
            text: picked.name,
          );
        }
      default:
        final result = choice == 'camera'
            ? await _photos.captureFromCamera()
            : await _photos.pickFromGallery();
        if (result.outcome == PhotoCaptureOutcome.permissionDenied) {
          _say('محتاج إذن الكاميرا عشان أصور');
        } else if (result.relativePath case final path?) {
          attachment = DraftAttachment(kind: AttachmentKind.photo, path: path);
        }
    }
    if (attachment == null) return;
    await _repo.addAttachment(entryId: entry.id, attachment: attachment);
    final attachments = await _repo.attachmentsForEntry(entry.id);
    if (mounted) setState(() => _attachments = attachments);
  }

  Future<String?> _askText() => showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final controller = TextEditingController();
      return AlertDialog(
        title: const Text('ملاحظة'),
        content: TextField(
          key: const Key('attach-text-field'),
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('attach-text-save'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        key: const Key('entry-detail'),
        backgroundColor: Colors.transparent,
        body: _missing
            ? const Center(child: Text('المصروف ده مبقاش موجود'))
            : _entry == null
            ? const SizedBox.shrink()
            : _buildFields(context),
        bottomNavigationBar: _entry == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    AppSpacing.sm,
                  ),
                  child: FilledButton(
                    key: const Key('detail-save'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _busy ? null : _save,
                    child: const Text('حفظ'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFields(BuildContext context) {
    final palette = context.palette;
    final amount = _amount;
    final category = _categories
        .where((c) => c.key == _categoryKey)
        .firstOrNull;
    Widget label(String text) => Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: AppText.label.copyWith(color: palette.textSecondary),
      ),
    );
    // One scroll view over a Column, not a lazy ListView: the fields are
    // few, and a text field scrolled out of a lazy list would be disposed
    // mid-edit.
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AttachmentStrip(
            attachments: _attachments,
            resolveFile: (path) => _photos.resolve(path),
            playbackFactory:
                widget.playbackFactory ?? JustAudioVoicePlayback.new,
          ),
          // The amount: tap to open the keypad in place.
          Semantics(
            button: true,
            label: 'المبلغ',
            child: InkWell(
              key: const Key('detail-amount'),
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => setState(() => _keypadOpen = !_keypadOpen),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    Text(
                      amount == null ? '—' : formatPiastres(amount),
                      key: const Key('detail-amount-text'),
                      textDirection: TextDirection.ltr,
                      style: AppText.display,
                    ),
                    Text(
                      keypadOperators.any(_expression.contains)
                          ? _expression
                          : 'ج.م',
                      textDirection: TextDirection.ltr,
                      style: AppText.caption.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_keypadOpen) AmountKeypad(onKey: _press),
          label('الاسم'),
          TextField(
            key: const Key('detail-name'),
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          label('الكمية'),
          Row(
            children: [
              SizedBox(
                width: 96,
                child: TextField(
                  key: const Key('detail-quantity'),
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(hintText: '1'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final MapEntry(key: unit, value: unitLabel)
                          in entryUnitLabels.entries)
                        SelectableChip(
                          key: Key('unit-$unit'),
                          label: unitLabel,
                          icon: AppIcons.check,
                          selected: _unit == unit,
                          onTap: () => setState(
                            () => _unit = _unit == unit ? null : unit,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          label('التاريخ'),
          InkWell(
            key: const Key('detail-date'),
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: _pickDate,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(AppIcons.calendar, size: 20, color: palette.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(formatFullDate(_date), style: AppText.body),
                  ),
                ],
              ),
            ),
          ),
          label('الفئة'),
          CategoryStrip(
            categories: _categories,
            selectedKey: _categoryKey,
            onSelected: _selectCategory,
          ),
          if (_subcategories.isNotEmpty)
            SubcategoryStrip(
              subcategories: _subcategories,
              selectedKey: _subcategoryKey,
              colorKey: category?.colorKey,
              onSelected: _selectSubcategory,
            ),
          if (_items.isNotEmpty)
            SizedBox(
              height: 52,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in _items)
                      SelectableChip(
                        key: Key('item-${item.id}'),
                        label: item.nameAr,
                        icon: iconFor(category?.iconName ?? ''),
                        colorKey: category?.colorKey,
                        selected: _itemId == item.id,
                        onTap: () => _selectItem(item),
                      ),
                  ],
                ),
              ),
            ),
          label('طريقة الدفع'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final MapEntry(key: method, value: methodLabel) in {
                  ...paymentMethodLabels,
                  if (!paymentMethodLabels.containsKey(_paymentMethod))
                    _paymentMethod: _paymentMethod,
                }.entries)
                  SelectableChip(
                    key: Key('payment-$method'),
                    label: methodLabel,
                    icon: AppIcons.payment,
                    selected: _paymentMethod == method,
                    onTap: () => setState(() => _paymentMethod = method),
                  ),
              ],
            ),
          ),
          label('ملاحظة'),
          TextField(
            key: const Key('detail-note'),
            controller: _note,
            minLines: 1,
            maxLines: 3,
          ),
          if (_siblings.isNotEmpty) ...[
            label('في نفس التسجيل'),
            for (final sibling in _siblings)
              ListTile(
                key: Key('sibling-${sibling.id}'),
                contentPadding: EdgeInsetsDirectional.zero,
                minTileHeight: 48,
                title: Text(
                  sibling.description.isNotEmpty
                      ? sibling.description
                      : (_categories
                                .where((c) => c.key == sibling.categoryKey)
                                .map((c) => c.labelAr)
                                .firstOrNull ??
                            sibling.categoryKey),
                  style: AppText.body,
                ),
                trailing: Text(
                  formatPiastres(sibling.amountPiastres),
                  textDirection: TextDirection.ltr,
                  style: AppText.bodyStrong,
                ),
                onTap: () => _openSibling(sibling.id),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Action(
                key: const Key('detail-duplicate'),
                icon: AppIcons.duplicate,
                label: 'تكرار اليوم',
                onPressed: _busy ? null : _duplicate,
              ),
              _Action(
                key: const Key('detail-repeat-monthly'),
                icon: AppIcons.repeat,
                label: 'كرر شهرياً',
                onPressed: _busy ? null : _repeatMonthly,
              ),
              _Action(
                key: const Key('detail-add-attachment'),
                icon: AppIcons.attach,
                label: 'إضافة مرفق',
                onPressed: _busy ? null : _addAttachment,
              ),
              _Action(
                key: const Key('detail-delete'),
                icon: AppIcons.delete,
                label: 'حذف',
                color: palette.negative,
                onPressed: _busy ? null : _delete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: color,
      side: color == null || onPressed == null
          ? null
          : BorderSide(color: color!),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
  );
}
