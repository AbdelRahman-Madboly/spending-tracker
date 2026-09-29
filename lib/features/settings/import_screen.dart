import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/import/import_pack.dart';
import '../../domain/import/import_review.dart';
import '../../domain/import/importer.dart';
import '../../domain/import/note_import.dart';
import '../../domain/parsing/line_parser.dart';
import '../../domain/parsing/repository_catalogue.dart';
import '../../domain/spending_repository.dart';

/// The import screen (plan Task 13): choose a source (the bundled packs, a
/// JSON / `.sdocx` / text file, or pasted text), then review every row
/// with its flags and confirm. Nothing is written before the confirm.
///
/// With [packs] it opens straight on their review, as the dashboard card
/// and a shared note do.
class ImportScreen extends StatefulWidget {
  final SpendingRepository repository;
  final Importer importer;
  final List<ImportPack>? packs;

  /// A file shared into the app: opens straight on its review.
  final PickedImportFile? initialFile;
  final Future<List<ImportPack>> Function()? loadBundled;
  final Future<PickedImportFile?> Function()? pickFile;
  final DateTime Function() clock;

  const ImportScreen({
    super.key,
    required this.repository,
    required this.importer,
    this.packs,
    this.initialFile,
    this.loadBundled,
    this.pickFile,
    this.clock = DateTime.now,
  });

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

String _idOf(ImportReviewItem item) =>
    item.row?.externalId ?? item.salary!.externalId;

class _ImportScreenState extends State<ImportScreen> {
  List<ImportReview>? _reviews;
  final Set<String> _selected = {};
  Map<String, String> _categoryLabels = const {};
  bool _busy = false;
  String? _error;
  ImportSummary? _result;

  @override
  void initState() {
    super.initState();
    final packs = widget.packs;
    if (packs != null) _review(() async => packs);
    final file = widget.initialFile;
    if (file != null) _review(() => _packOf(file));
  }

  Future<void> _review(Future<List<ImportPack>> Function() load) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final packs = await load();
      final reviews = [
        for (final pack in packs) await widget.importer.review(pack),
      ];
      final labels = {
        for (final c in await widget.repository.categories()) c.key: c.labelAr,
        for (final pack in packs)
          for (final c in pack.additions.categories) c.key: c.labelAr,
      };
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _categoryLabels = labels;
        _selected
          ..clear()
          ..addAll([
            for (final r in reviews)
              for (final i in r.items)
                if (i.selectedByDefault) _idOf(i),
          ]);
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is FormatException
            ? 'الملف ده مش ملف استيراد ولا ملاحظة'
            : 'مقدرناش نقرا الملف',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ArabicLineParser> _parser() async =>
      ArabicLineParser(await loadParserCatalogue(widget.repository));

  Future<void> _pick() async {
    final pick = widget.pickFile;
    if (pick == null) return;
    final file = await pick();
    if (file == null) return;
    await _review(() => _packOf(file));
  }

  Future<List<ImportPack>> _packOf(PickedImportFile file) async => [
    packFromFile(
      file.name,
      file.bytes,
      parser: await _parser(),
      now: widget.clock(),
    ),
  ];

  Future<void> _paste() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _PasteDialog(),
    );
    if (text == null || text.trim().isEmpty) return;
    await _review(
      () async => [
        noteImportPack(
          text: text,
          capturedAt: widget.clock(),
          parser: await _parser(),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    final reviews = _reviews!;
    setState(() => _busy = true);
    var entries = 0, salaries = 0, failed = 0;
    try {
      for (final review in reviews) {
        final chosen = [
          for (final i in review.items)
            if (_selected.contains(_idOf(i))) i,
        ];
        if (chosen.isEmpty) continue;
        final s = await widget.importer.apply(review.pack, chosen);
        entries += s.entries;
        salaries += s.salaries;
        failed += s.failed;
      }
    } on Object {
      failed = -1;
    }
    // The bundled packs imported, from here or from the dashboard: the
    // dashboard need not offer them again.
    if (entries + salaries > 0 &&
        reviews.any((r) => bundledPackFiles.contains(r.pack.fileName))) {
      await widget.repository.setSetting(importOfferSettingKey, '1');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = ImportSummary(
        entries: entries,
        salaries: salaries,
        failed: failed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _reviews;
    final result = _result;
    // Once something is written, leaving by back reports it as done too.
    return PopScope<bool>(
      canPop: result == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('استيراد')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : result != null
            ? _ResultView(result: result)
            : reviews == null
            ? _sources(context)
            : _reviewList(context, reviews),
        bottomNavigationBar: reviews == null || result != null || _busy
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton(
                    key: const Key('import-confirm'),
                    onPressed: _selected.isEmpty ? null : _confirm,
                    child: Text('استورد (${_selected.length})'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _sources(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        Text(
          'كل اللي هيتستورد هيظهر الأول في قائمة تراجعها، ومفيش حاجة '
          'بتتسجل قبل ما توافق. اللي اتستورد قبل كده مش بيتكرر.',
          style: AppText.body.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.loadBundled case final load?)
          ListTile(
            key: const Key('import-bundled'),
            leading: const Icon(AppIcons.importBundled),
            title: const Text('بيانات سبتمبر المرفقة'),
            subtitle: const Text(
              'ملاحظات سامسونج، الإدخالات اليدوية، ومتتبع الشغل',
            ),
            onTap: () => _review(load),
          ),
        if (widget.pickFile != null)
          ListTile(
            key: const Key('import-pick'),
            leading: const Icon(AppIcons.importFile),
            title: const Text('اختار ملف'),
            subtitle: const Text('JSON أو ملاحظة سامسونج .sdocx أو نص'),
            onTap: _pick,
          ),
        ListTile(
          key: const Key('import-paste'),
          leading: const Icon(AppIcons.importPaste),
          title: const Text('الصق نص ملاحظة'),
          onTap: _paste,
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              error,
              style: AppText.body.copyWith(color: palette.negative),
            ),
          ),
      ],
    );
  }

  Widget _reviewList(BuildContext context, List<ImportReview> reviews) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        for (final review in reviews) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              0,
            ),
            child: Text(review.pack.fileName, style: AppText.title),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.gutter,
            ),
            child: Text(
              'جديد ${review.count(ImportRowState.fresh)} · '
              'محتاج مراجعة ${review.count(ImportRowState.flagged)} · '
              'مكرر ${review.count(ImportRowState.duplicate)} · '
              'ناقص ${review.count(ImportRowState.incomplete)}'
              '${review.pack.skipped > 0 ? ' · متجاهل ${review.pack.skipped}' : ''}',
              style: AppText.caption.copyWith(color: palette.textSecondary),
            ),
          ),
          if (review.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.gutter),
              child: Text('مفيش حاجة تتستورد.'),
            ),
          for (final item in review.items) _tile(context, item),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, ImportReviewItem item) {
    final palette = context.palette;
    final id = _idOf(item);
    final row = item.row;
    final salary = item.salary;
    final date = row?.date ?? salary!.datePaid;
    final amount = row?.amountPiastres ?? salary?.amountPiastres;
    final title = row != null
        ? (row.description.isEmpty ? (row.rawText ?? '') : row.description)
        : 'راتب';
    final category = row?.categoryKey;
    final details = [
      '${date.day}/${date.month}/${date.year}',
      if (category != null) _categoryLabels[category] ?? category,
      if (row != null && row.paymentMethod != 'Cash') row.paymentMethod,
      if (row?.evidence != null || salary?.evidence != null) 'مرفق',
    ].join(' · ');
    final notes = [...item.problems, if (row != null) ...row.flags];
    final color = switch (item.state) {
      ImportRowState.duplicate || ImportRowState.incomplete => palette.negative,
      ImportRowState.flagged => palette.warning,
      ImportRowState.fresh => palette.textSecondary,
    };
    return CheckboxListTile(
      key: ValueKey('import-item-$id'),
      value: _selected.contains(id),
      onChanged: item.selectable
          ? (v) => setState(() {
              if (v == true) {
                _selected.add(id);
              } else {
                _selected.remove(id);
              }
            })
          : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Expanded(child: Text(title, style: AppText.body)),
          if (amount != null)
            Text(formatPiastres(amount), style: AppText.bodyStrong),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details, style: AppText.caption),
          for (final note in notes)
            Text(note, style: AppText.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ImportSummary result;

  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final failed = result.failed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اتضاف ${result.entries} مصروف و${result.salaries} راتب',
              style: AppText.title,
              textAlign: TextAlign.center,
            ),
            if (failed != 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  failed < 0
                      ? 'حصلت مشكلة وقفت الاستيراد في النص، جرّب تاني'
                      : '$failed ماتسجلوش لأنهم متسجلين قبل كده',
                  style: AppText.body.copyWith(color: context.palette.negative),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('import-done'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns its text controller, so the controller outlives the dialog's
/// closing animation.
class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('الصق الملاحظة'),
    content: TextField(
      key: const Key('import-paste-field'),
      controller: _controller,
      maxLines: 8,
      minLines: 4,
      autofocus: true,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        key: const Key('import-paste-ok'),
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('اقرا'),
      ),
    ],
  );
}
