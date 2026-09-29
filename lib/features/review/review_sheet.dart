import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../core/quantity.dart';
import '../../data/photo_capture_service.dart';
import '../../data/voice_playback.dart';
import '../../domain/models.dart';
import '../../domain/parsing/line_parser.dart';
import '../../domain/parsing/parsed_line.dart';
import '../../domain/parsing/repository_catalogue.dart';
import '../../domain/review.dart';
import '../../domain/spending_repository.dart';
import '../../domain/transactions.dart';
import '../add/add_sheet.dart' show keypadText, paymentMethodLabels;
import '../add/widgets/category_strip.dart';
import '../add/widgets/subcategory_strip.dart';
import '../transactions/widgets/attachment_strip.dart';

/// Everything one capture hands the review sheet (spec §6.7). Every
/// automatic path (voice, text, photo, barcode, a draft from Needs review)
/// builds one of these and nothing else: no capture is saved without
/// passing through the sheet.
class ReviewRequest {
  final CaptureKind kind;

  /// When the capture was made: dates the parsed lines (a note written
  /// before 05:00 belongs to the day before).
  final DateTime capturedAt;

  /// The shared date, when the capture already has one (a draft's).
  /// Otherwise the first parsed line's date, then the capture day.
  final DateTime? date;

  /// The transcript or typed text as captured, never altered.
  final String? rawText;
  final String? cleanText;
  final String? parsedBy;

  /// Lines the capture already has (a barcode scan, an OCR result). When
  /// null the sheet parses [cleanText] or [rawText] against the catalogue.
  final List<ParsedLine>? lines;

  /// Attachments made by this capture and not saved yet.
  final List<DraftAttachment> attachments;

  /// The draft this review finishes, and the attachments it already holds.
  final String? draftId;
  final List<AttachmentView> savedAttachments;

  const ReviewRequest({
    required this.kind,
    required this.capturedAt,
    this.date,
    this.rawText,
    this.cleanText,
    this.parsedBy,
    this.lines,
    this.attachments = const [],
    this.draftId,
    this.savedAttachments = const [],
  });

  /// Review of a capture kept for later: its text is parsed again (a draft
  /// stores no lines) and its attachments show as they are.
  factory ReviewRequest.fromDraft(CaptureGroupView draft) => ReviewRequest(
        kind: draft.kind,
        // Midday, so the before-05:00 rule never moves a draft's own day.
        capturedAt:
            DateTime(draft.date.year, draft.date.month, draft.date.day, 12),
        date: draft.date,
        rawText: draft.rawText,
        cleanText: draft.cleanText,
        parsedBy: draft.parsedBy,
        draftId: draft.id,
        savedAttachments: draft.attachments,
      );
}

/// How the review ended. [kept] covers بعدين and closing the sheet: the
/// capture waits in Needs review.
enum ReviewOutcome { saved, note, kept }

/// Opens the review sheet full height and resolves to how it ended.
///
/// Closing without saving never discards the capture (spec §6.7): a new
/// capture is kept as a `draft`, and a draft opened from Needs review stays
/// the draft it was. This runs here, after the sheet is gone, so every way
/// of closing it (بعدين, back, a drag down) keeps the capture the same way.
Future<ReviewOutcome> showReviewSheet(
  BuildContext context, {
  required SpendingRepository repository,
  required ReviewRequest request,
  DateTime Function() clock = DateTime.now,
  PhotoCaptureService? photoCaptureService,
  VoicePlayback Function()? playbackFactory,
}) async {
  final latest = _ReviewSnapshot();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final outcome = await showModalBottomSheet<ReviewOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 1,
      child: ReviewSheet(
        repository: repository,
        request: request,
        clock: clock,
        photoCaptureService: photoCaptureService,
        playbackFactory: playbackFactory,
        onChanged: (lines, date) {
          latest.lines = lines;
          latest.date = date;
        },
      ),
    ),
  );
  if (outcome == ReviewOutcome.saved || outcome == ReviewOutcome.note) {
    return outcome!;
  }
  try {
    await _keepAsDraft(repository, request, latest);
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(
      key: Key('review-keep-failed'),
      content: Text('ما قدرتش أحتفظ بالتسجيل، جرب تاني'),
    ));
  }
  return ReviewOutcome.kept;
}

class _ReviewSnapshot {
  List<ReviewLine> lines = const [];
  DateTime? date;
}

/// Keeps a new capture as a draft. A draft stores its text and
/// attachments only, so lines that came with no text of their own are
/// written as text the parser reads back to them.
Future<void> _keepAsDraft(SpendingRepository repository,
    ReviewRequest request, _ReviewSnapshot latest) async {
  if (request.draftId != null) return;
  final raw = request.rawText ?? '';
  final text = raw.trim().isNotEmpty ? raw : reviewDraftText(latest.lines);
  if (text.trim().isEmpty && request.attachments.isEmpty) return;
  final day = latest.date ?? ArabicLineParser.captureDay(request.capturedAt);
  await repository.saveCapture(CaptureDraft(
    kind: request.kind,
    date: day,
    rawText: text.isEmpty ? null : text,
    cleanText: request.cleanText,
    parsedBy: request.parsedBy,
    lines: const [],
    attachments: request.attachments,
    isDraft: true,
  ));
}

/// The review sheet (spec §6.7): a shared date and payment method and the
/// capture's attachments on top, one editable card per line, and a footer
/// with the total, حفظ N مصروف, حفظ كملاحظة and بعدين.
class ReviewSheet extends StatefulWidget {
  final SpendingRepository repository;
  final ReviewRequest request;
  final DateTime Function() clock;
  final PhotoCaptureService? photoCaptureService;
  final VoicePlayback Function()? playbackFactory;

  /// Told the lines and date after every change, so whoever opened the
  /// sheet can keep them as a draft when it is closed.
  final void Function(List<ReviewLine> lines, DateTime date)? onChanged;

  const ReviewSheet({
    super.key,
    required this.repository,
    required this.request,
    this.clock = DateTime.now,
    this.photoCaptureService,
    this.playbackFactory,
    this.onChanged,
  });

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  SpendingRepository get _repo => widget.repository;
  ReviewRequest get _request => widget.request;

  PhotoCaptureService? _photoCaptureService;
  PhotoCaptureService get _photos => _photoCaptureService ??=
      widget.photoCaptureService ?? ImagePickerPhotoCaptureService();

  final _messenger = GlobalKey<ScaffoldMessengerState>();

  bool _loaded = false;
  bool _saving = false;
  bool _paymentTouched = false;
  int _nextId = 0;

  List<ReviewLine> _lines = const [];
  late DateTime _date;
  String _paymentMethod = 'Cash';

  /// Set when the sheet parsed the text itself rather than being handed
  /// lines.
  String? _parsedBy;

  List<CategoryView> _categories = const [];
  Map<String, List<SubcategoryView>> _subcategories = const {};
  List<QuickPickItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _date = _request.date ?? ArabicLineParser.captureDay(_request.capturedAt);
    _load();
  }

  String _newId() => 'l${_nextId++}';

  Future<void> _load() async {
    final categories = await _repo.categories();
    final subcategories = {
      for (final c in categories) c.key: await _repo.subcategories(c.key),
    };
    final items = await _repo.allItems();
    final payment = await _repo.setting(lastPaymentMethodSettingKey);
    var parsed = _request.lines;
    String? parsedBy = _request.parsedBy;
    if (parsed == null) {
      final text = _request.cleanText ?? _request.rawText ?? '';
      parsed = ArabicLineParser(await loadParserCatalogue(_repo))
          .parse(text, capturedAt: _request.capturedAt);
      parsedBy ??= 'local';
    }
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _subcategories = subcategories;
      _items = items;
      if (!_paymentTouched && payment != null) _paymentMethod = payment;
      _parsedBy = parsedBy;
      _lines = [for (final p in parsed!) ReviewLine.fromParsed(p, id: _newId())];
      if (_request.date == null && parsed.isNotEmpty) _date = parsed.first.date;
      _loaded = true;
    });
    _report();
  }

  void _report() => widget.onChanged?.call(_lines, _date);

  void _update(ReviewLine line) {
    setState(() {
      _lines = [for (final l in _lines) l.id == line.id ? line : l];
    });
    _report();
  }

  void _remove(String id) {
    setState(() => _lines = [for (final l in _lines) if (l.id != id) l]);
    _report();
  }

  void _addLine() {
    setState(() => _lines = [..._lines, ReviewLine.blank(_newId())]);
    _report();
  }

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
    if (picked != null && mounted) {
      setState(() => _date = picked);
      _report();
    }
  }

  /// Writes the capture. One write at a time: while it runs every footer
  /// button is off, so a double tap cannot save it twice. A failure says
  /// so and leaves the sheet open with the lines as they were.
  Future<void> _write(List<CaptureLine> lines, ReviewOutcome outcome) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final raw = _request.rawText;
      await _repo.saveCapture(CaptureDraft(
        kind: _request.kind,
        date: _date,
        paymentMethod: _paymentMethod,
        // A note needs words to be worth keeping; lines that came with no
        // text of their own give it theirs.
        rawText: raw ??
            (lines.isEmpty && _lines.isNotEmpty
                ? reviewDraftText(_lines)
                : null),
        cleanText: _request.cleanText,
        parsedBy: _parsedBy,
        lines: lines,
        attachments: _request.attachments,
        draftId: _request.draftId,
      ));
      if (outcome == ReviewOutcome.saved) HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(outcome);
    } catch (_) {
      if (mounted) {
        _say('الحفظ ما نفعش، جرب تاني', key: const Key('review-save-failed'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!canSaveReview(_lines)) return;
    await _write([for (final l in _lines) l.toCaptureLine()],
        ReviewOutcome.saved);
  }

  Future<void> _saveNote() => _write(const [], ReviewOutcome.note);

  List<AttachmentView> get _attachmentViews {
    final now = widget.clock();
    return [
      ..._request.savedAttachments,
      for (final (i, a) in _request.attachments.indexed)
        AttachmentView(
          id: 'new-$i',
          kind: a.kind,
          path: a.path,
          text: a.text,
          transcript: a.transcript,
          durationMs: a.durationMs,
          createdAt: now,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        key: const Key('review-sheet'),
        backgroundColor: Colors.transparent,
        body: _loaded ? _buildBody(context) : const SizedBox.shrink(),
        bottomNavigationBar: _loaded ? _buildFooter(context) : null,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final palette = context.palette;
    final text = (_request.cleanText ?? _request.rawText ?? '').trim();
    Widget label(String value) => Padding(
          padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Text(value,
              style: AppText.label.copyWith(color: palette.textSecondary)),
        );
    // One scroll view over a Column, not a lazy ListView: a text field
    // scrolled out of a lazy list would be disposed mid-edit.
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.review, color: palette.primary),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Text('راجع قبل الحفظ', style: AppText.title)),
            ],
          ),
          label('التاريخ'),
          InkWell(
            key: const Key('review-date'),
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: _pickDate,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(AppIcons.calendar, size: 20, color: palette.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                      child: Text(formatFullDate(_date), style: AppText.body)),
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
                    onTap: () => setState(() {
                      _paymentTouched = true;
                      _paymentMethod = method;
                    }),
                  ),
              ],
            ),
          ),
          if (_attachmentViews.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AttachmentStrip(
              attachments: _attachmentViews,
              resolveFile: (path) => _photos.resolve(path),
              playbackFactory:
                  widget.playbackFactory ?? JustAudioVoicePlayback.new,
            ),
          ],
          if (text.isNotEmpty) ...[
            label('اللي اتسجل'),
            Container(
              key: const Key('review-raw-text'),
              padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: palette.textSecondary)),
            ),
          ],
          label(_lines.isEmpty ? 'مفيش سطور' : 'السطور (${_lines.length})'),
          for (final line in _lines)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.ms),
              child: Dismissible(
                key: Key('review-line-${line.id}'),
                onDismissed: (_) => _remove(line.id),
                background: const _DismissBackground(
                    alignment: AlignmentDirectional.centerStart),
                secondaryBackground: const _DismissBackground(
                    alignment: AlignmentDirectional.centerEnd),
                child: _LineCard(
                  line: line,
                  categories: _categories,
                  subcategories: _subcategories[line.categoryKey] ?? const [],
                  items: _itemsFor(line),
                  onChanged: _update,
                  onRemove: () => _remove(line.id),
                ),
              ),
            ),
          OutlinedButton.icon(
            key: const Key('review-add-line'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _addLine,
            icon: const Icon(AppIcons.add, size: 20),
            label: const Text('+ سطر'),
          ),
        ],
      ),
    );
  }

  /// The item chips under a line's category (and subcategory, once one
  /// is picked). The linked item always shows, even past the first twelve.
  List<QuickPickItem> _itemsFor(ReviewLine line) {
    final category = line.categoryKey;
    if (category == null) return const [];
    final sub = line.subcategoryKey;
    final matching = [
      for (final i in _items)
        if (i.categoryKey == category &&
            (sub == null || i.subcategoryKey == sub))
          i,
    ];
    final shown = matching.take(12).toList();
    final linked = matching.where((i) => i.id == line.itemId).firstOrNull;
    if (linked != null && !shown.contains(linked)) shown.insert(0, linked);
    return shown;
  }

  Widget _buildFooter(BuildContext context) {
    final palette = context.palette;
    final ready = canSaveReview(_lines);
    final blocked = _lines.any((l) => !l.isReady);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(top: BorderSide(color: palette.divider)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('الإجمالي',
                    style:
                        AppText.label.copyWith(color: palette.textSecondary)),
                const Spacer(),
                Text(
                  formatPiastres(reviewTotal(_lines)),
                  key: const Key('review-total'),
                  textDirection: TextDirection.ltr,
                  style: AppText.title,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('ج.م',
                    style:
                        AppText.caption.copyWith(color: palette.textSecondary)),
              ],
            ),
            if (blocked)
              Padding(
                key: const Key('review-blocked'),
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(AppIcons.warning, size: 16, color: palette.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text('كمّل المبلغ والفئة في السطور المعلّمة أو امسحها',
                          style: AppText.caption
                              .copyWith(color: palette.warning)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('review-save'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: ready && !_saving ? _save : null,
              child: Text('حفظ ${_lines.length} مصروف'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('review-note'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _saving ? null : _saveNote,
                    child: const Text('حفظ كملاحظة'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    key: const Key('review-later'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(ReviewOutcome.kept),
                    child: const Text('بعدين'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  final AlignmentGeometry alignment;

  const _DismissBackground({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      alignment: alignment,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.negative,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: const Icon(AppIcons.delete, color: Colors.white),
    );
  }
}

/// One line's card: name and amount, quantity and unit, then the category
/// → subcategory → item strips. A field the parser was unsure of gets a
/// warning outline and icon until it is touched; a missing amount or
/// category says so under its field.
class _LineCard extends StatefulWidget {
  final ReviewLine line;
  final List<CategoryView> categories;
  final List<SubcategoryView> subcategories;
  final List<QuickPickItem> items;
  final ValueChanged<ReviewLine> onChanged;
  final VoidCallback onRemove;

  const _LineCard({
    required this.line,
    required this.categories,
    required this.subcategories,
    required this.items,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  late final _name = TextEditingController(text: widget.line.name);
  late final _amount = TextEditingController(text: _amountText(widget.line));
  late final _quantity =
      TextEditingController(text: _quantityText(widget.line));

  static String _amountText(ReviewLine line) =>
      line.amountPiastres == null ? '' : keypadText(line.amountPiastres!);

  static String _quantityText(ReviewLine line) =>
      line.quantityMilli == 1000 && line.unit == null
          ? ''
          : formatQuantityMilli(line.quantityMilli);

  @override
  void didUpdateWidget(_LineCard old) {
    super.didUpdateWidget(old);
    final line = widget.line;
    // Only a change made elsewhere (an item linked, a quantity that moved
    // the amount) rewrites a field, and only when the field no longer
    // reads as the value: a half-typed "15." stays as typed.
    if (old.line.name != line.name && _name.text != line.name) {
      _name.text = line.name;
    }
    if (old.line.amountPiastres != line.amountPiastres &&
        parsePiastres(_amount.text) != line.amountPiastres) {
      _amount.text = _amountText(line);
    }
    if (old.line.quantityMilli != line.quantityMilli &&
        (parseQuantityMilli(_quantity.text) ?? 1000) != line.quantityMilli) {
      _quantity.text = _quantityText(line);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _quantity.dispose();
    super.dispose();
  }

  InputDecoration _decoration(
    BuildContext context, {
    required bool warn,
    required String warningKey,
    String? hint,
    String? helper,
    String? suffix,
  }) {
    final palette = context.palette;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: warn
          ? BorderSide(color: palette.warning, width: 1.5)
          : BorderSide(color: palette.outline),
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      helperText: helper,
      helperStyle: AppText.caption.copyWith(color: palette.warning),
      suffixText: suffix,
      enabledBorder: border,
      border: border,
      suffixIcon: warn
          ? Icon(AppIcons.warning,
              key: Key(warningKey), size: 20, color: palette.warning)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final line = widget.line;
    final problems = line.problems;
    final missingAmount = problems.contains(ReviewProblem.missingAmount);
    final missingCategory = problems.contains(ReviewProblem.missingCategory);
    final category =
        widget.categories.where((c) => c.key == line.categoryKey).firstOrNull;
    final warnCategory =
        missingCategory || line.uncertain.contains(ReviewField.category);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: problems.isEmpty ? palette.divider : palette.warning,
          width: problems.isEmpty ? 1 : 1.5,
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.ms, AppSpacing.ms, AppSpacing.xs, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('line-name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    context,
                    warn: line.uncertain.contains(ReviewField.name),
                    warningKey: 'line-name-warning',
                    hint: 'الاسم',
                  ),
                  onChanged: (text) => widget.onChanged(line.withName(text)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 124,
                child: TextField(
                  key: const Key('line-amount'),
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  style: AppText.bodyStrong,
                  decoration: _decoration(
                    context,
                    warn: missingAmount ||
                        line.uncertain.contains(ReviewField.amount),
                    warningKey: 'line-amount-warning',
                    hint: '0',
                    helper: missingAmount ? 'اكتب المبلغ' : null,
                    suffix: 'ج.م',
                  ),
                  onChanged: (text) =>
                      widget.onChanged(line.withAmount(parsePiastres(text))),
                ),
              ),
              IconButton(
                key: const Key('line-remove'),
                tooltip: 'امسح السطر',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(AppIcons.close, size: 20, color: palette.textSecondary),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 84,
                child: TextField(
                  key: const Key('line-quantity'),
                  controller: _quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: _decoration(
                    context,
                    warn: line.uncertain.contains(ReviewField.quantity),
                    warningKey: 'line-quantity-warning',
                    hint: '1',
                  ),
                  onChanged: (text) {
                    final quantity = text.trim().isEmpty
                        ? 1000
                        : parseQuantityMilli(text);
                    if (quantity != null) {
                      widget.onChanged(line.withQuantity(quantity));
                    }
                  },
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
                          selected: line.unit == unit,
                          onTap: () => widget.onChanged(
                              line.withUnit(line.unit == unit ? null : unit)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (warnCategory)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(AppIcons.warning,
                      key: const Key('line-category-warning'),
                      size: 16,
                      color: palette.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Text(missingCategory ? 'اختار الفئة' : 'اتأكد من الفئة',
                      style: AppText.caption.copyWith(color: palette.warning)),
                ],
              ),
            ),
          CategoryStrip(
            categories: widget.categories,
            selectedKey: line.categoryKey,
            showAll: false,
            onSelected: (key) {
              if (key != null) widget.onChanged(line.withCategory(key));
            },
          ),
          if (widget.subcategories.isNotEmpty)
            SubcategoryStrip(
              subcategories: widget.subcategories,
              selectedKey: line.subcategoryKey,
              colorKey: category?.colorKey,
              onSelected: (key) =>
                  widget.onChanged(line.withSubcategory(key)),
            ),
          if (widget.items.isNotEmpty)
            SizedBox(
              height: 52,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in widget.items)
                      SelectableChip(
                        key: Key('item-${item.id}'),
                        label: item.nameAr,
                        icon: iconFor(category?.iconName ?? ''),
                        colorKey: category?.colorKey,
                        selected: line.itemId == item.id,
                        onTap: () => widget.onChanged(line.withItem(item)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
