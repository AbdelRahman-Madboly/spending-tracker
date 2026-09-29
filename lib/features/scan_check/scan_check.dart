import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../data/barcode_scan_service.dart';
import '../../data/gemini_key_store.dart';
import '../../data/net/gemini_client.dart';
import '../../data/net/gemini_product_reader.dart';
import '../../data/net/network_gate.dart';
import '../../data/net/product_lookup.dart';
import '../../data/photo_capture_service.dart';
import '../../data/product_catalog_source.dart';
import '../../data/text_recognition_service.dart';
import '../../domain/models.dart';
import '../../domain/online_features.dart';
import '../../domain/parsing/line_parser.dart';
import '../../domain/parsing/parsed_line.dart';
import '../../domain/product_catalog.dart';
import '../../domain/scan_check.dart';
import '../../domain/spending_repository.dart';
import '../add/widgets/category_strip.dart' show SelectableChip;
import '../capture/permission_prompt.dart';
import '../products/product_editor.dart' show barcodeTakenMessage;
import '../review/review_sheet.dart';

/// «امسح واعرف»: scan a product, see what the app knows about it and its
/// price, and only then decide: record it as a purchase (through review),
/// keep it in منتجاتي, or neither. A scan on its own writes nothing.
///
/// A code is looked up in منتجاتي, الدليل, Open Food Facts (its switch on)
/// and a web search through Gemini (its switch on). What is still unknown
/// can be read off a photo of the pack or typed. «امسح تاني» goes straight
/// on to the next product. The services are injectable for tests.
Future<void> scanAndCheck(
  BuildContext context,
  SpendingRepository repository, {
  BarcodeScanService? scanner,
  NetworkGate? networkGate,
  GeminiKeyStore? geminiKeyStore,
  ProductLookup? productLookup,
  OnlineProductReader? onlineReader,
  ProductCatalogSource? productCatalog,
  PhotoCaptureService? photoCaptureService,
  TextRecognitionService? textRecognition,
  Future<Uint8List> Function(String relativePath)? readPhotoBytes,
  PermissionService? permissionService,
  DateTime Function() clock = DateTime.now,
}) async {
  if (!await ensurePermission(context, AppPermission.camera,
      service: permissionService)) {
    return;
  }
  if (!context.mounted) return;
  final scan = scanner ?? MobileScannerBarcodeScanService();
  final catalogSource = productCatalog ?? ProductCatalogSource.shared;
  final catalogLoading = catalogSource.load();
  final gate = networkGate ?? NetworkGate(repository);
  final reader = onlineReader ??
      GeminiProductReader(GeminiClient(
          gate, repository, geminiKeyStore ?? SecureGeminiKeyStore()));
  final photos = photoCaptureService ?? ImagePickerPhotoCaptureService();
  final ocr = textRecognition ?? MlKitTextRecognitionService();
  Future<Uint8List> bytesOf(String path) async => readPhotoBytes != null
      ? readPhotoBytes(path)
      : (await photos.resolve(path)).readAsBytes();

  while (true) {
    if (!context.mounted) return;
    final scanned = (await scan.scan(context))?.trim() ?? '';
    if (scanned.isEmpty || !context.mounted) return;
    final capturedAt = clock();
    final catalog = await catalogLoading;
    final categories = await repository.categories();
    if (!context.mounted) return;

    final lookup = productLookup ??
        (await isOnlineFeatureOn(repository, OnlineFeature.productLookup)
            ? OpenFoodFactsLookup(gate, repository, clock: clock)
            : null);
    final finding = checkBarcode(
      scanned,
      repository: repository,
      catalog: catalog,
      lookupName: lookup?.nameFor,
      searchOnline: (code) async =>
          await reader.canSearch() ? reader.search(code) : null,
    );

    // The photo taken for this product, kept only if it is bought.
    String? photoPath;
    Future<ScanFinding?> takePhoto(ScanFinding current) async {
      final PhotoCaptureResult result;
      try {
        result = await photos.captureFromCamera();
      } catch (_) {
        return null;
      }
      final path = result.relativePath;
      if (path == null) return null;
      if (photoPath != null) await photos.delete(photoPath!);
      photoPath = path;
      var text = '';
      try {
        text = await ocr.recognize((await photos.resolve(path)).path);
      } catch (_) {}
      ProductInfo? online;
      try {
        if (await reader.canReadPhoto()) {
          online = await reader.readPhoto(await bytesOf(path));
        }
      } catch (_) {}
      return readProductPhoto(current,
          repository: repository,
          catalog: catalog,
          ocrText: text,
          online: online);
    }

    if (!context.mounted) return;
    final decision = await showModalBottomSheet<ScanDecision>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => ScanResultSheet(
        code: scanned,
        finding: finding,
        categories: categories,
        catalog: catalog,
        onPhoto: takePhoto,
      ),
    );
    if (!context.mounted) return;

    if (decision?.action != ScanAction.record && photoPath != null) {
      await photos.delete(photoPath!);
      photoPath = null;
    }
    if (!context.mounted) return;
    switch (decision?.action) {
      case null:
      case ScanAction.cancel:
        return;
      case ScanAction.again:
        continue;
      case ScanAction.save:
        await _saveProduct(context, repository, catalog, decision!);
        return;
      case ScanAction.record:
        final keys =
            await _categoryFor(repository, catalog, decision!, categories);
        if (!context.mounted) return;
        final line = ParsedLine(
          rawText: scanned,
          date: ArabicLineParser.captureDay(capturedAt),
          name: decision.name,
          itemId: decision.finding.item?.id,
          categoryKey: keys.categoryKey,
          subcategoryKey: keys.subcategoryKey,
          amountPiastres: decision.pricePiastres,
          confidence: ParseConfidence.medium,
          flags: {
            if (keys.categoryKey == null) ParseFlag.noCategory,
            if (decision.finding.product != null &&
                decision.finding.item == null)
              ParseFlag.catalogue,
          },
          barcode: scanned,
        );
        await showReviewSheet(
          context,
          repository: repository,
          request: ReviewRequest(
            kind: CaptureKind.barcode,
            capturedAt: capturedAt,
            lines: [line],
            attachments: [
              if (photoPath case final path?)
                DraftAttachment(kind: AttachmentKind.photo, path: path),
            ],
          ),
          clock: clock,
          productCatalog: catalogSource,
          photoCaptureService: photos,
          textRecognition: ocr,
        );
        return;
    }
  }
}

/// The category the decision files under in the app. A catalogue
/// product's own category and subcategory are created from the
/// catalogue's additions now that the user has chosen to keep or buy it.
Future<({String? categoryKey, String? subcategoryKey})> _categoryFor(
  SpendingRepository repository,
  ProductCatalog catalog,
  ScanDecision decision,
  List<CategoryView> live,
) async {
  final key = decision.categoryKey;
  final product = decision.finding.product;
  if (product != null && key == product.categoryKey) {
    final keys = await ensureCatalogueCategory(repository, catalog, product);
    if (keys.categoryKey != null) return keys;
  }
  if (key != null && live.any((c) => c.key == key)) {
    return (categoryKey: key, subcategoryKey: decision.subcategoryKey);
  }
  return (categoryKey: null, subcategoryKey: null);
}

Future<void> _saveProduct(
  BuildContext context,
  SpendingRepository repository,
  ProductCatalog catalog,
  ScanDecision decision,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String text, [Key? key]) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(key: key, content: Text(text)));
  final keys = await _categoryFor(
      repository, catalog, decision, await repository.categories());
  final categoryKey = keys.categoryKey;
  if (categoryKey == null) {
    say('الفئة دي مش متاحة، اختار فئة تانية');
    return;
  }
  final code = decision.finding.code;
  final item = decision.finding.item;
  try {
    if (item == null) {
      await repository.createItem(
        nameAr: decision.name,
        categoryKey: categoryKey,
        subcategoryKey: keys.subcategoryKey,
        defaultAmountPiastres: decision.pricePiastres,
        barcode: code,
      );
    } else {
      await repository.updateProduct(
        itemId: item.id,
        nameAr: decision.name,
        categoryKey: categoryKey,
        subcategoryKey: keys.subcategoryKey,
        defaultAmountPiastres: decision.pricePiastres,
        barcode: item.barcode ?? code,
        // The card edits name, price and category only; how the product
        // is sold stays as the editor set it.
        unit: item.unit,
        defaultQuantityMilli: item.defaultQuantityMilli,
      );
    }
  } on DuplicateBarcodeException catch (e) {
    final holder = await repository.itemByBarcode(e.barcode);
    say(barcodeTakenMessage(holder?.nameAr ?? 'منتج تاني'));
    return;
  } catch (_) {
    say('الحفظ ما نفعش، جرب تاني');
    return;
  }
  say('«${decision.name}» اتحفظ في منتجاتك', const Key('scan-saved'));
}

/// What the user chose on the result card.
enum ScanAction { record, save, again, cancel }

/// The user's choice with the details they confirmed.
class ScanDecision {
  const ScanDecision({
    required this.action,
    required this.finding,
    this.name = '',
    this.pricePiastres,
    this.categoryKey,
    this.subcategoryKey,
  });

  final ScanAction action;
  final ScanFinding finding;
  final String name;
  final int? pricePiastres;
  final String? categoryKey;
  final String? subcategoryKey;
}

/// The result card of one scan: the digits read, what is known about the
/// product and where from, and its price, with the actions that decide
/// what happens. Pops with a [ScanDecision]; writes nothing itself.
class ScanResultSheet extends StatefulWidget {
  const ScanResultSheet({
    super.key,
    required this.code,
    required this.finding,
    required this.categories,
    required this.catalog,
    required this.onPhoto,
  });

  final String code;
  final Future<ScanFinding> finding;

  /// The app's live categories.
  final List<CategoryView> categories;

  /// Labels a catalogue category the app does not have yet.
  final ProductCatalog catalog;

  /// Takes a photo of the pack and reads it; null when nothing was read.
  final Future<ScanFinding?> Function(ScanFinding current) onPhoto;

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _priceFocus = FocusNode();

  ScanFinding? _finding;
  bool _editing = false;
  bool _reading = false;
  String? _categoryKey;
  String? _subcategoryKey;
  String? _nameError;
  String? _priceError;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    widget.finding.then((f) {
      if (mounted) _apply(f);
    }, onError: (_) {
      if (mounted) {
        _apply(ScanFinding(code: widget.code, source: ScanSource.unknown));
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _apply(ScanFinding f) {
    setState(() {
      _finding = f;
      _name.text = f.name;
      _price.text = switch (f.pricePiastres) {
        final p? => formatPiastres(p).replaceAll(',', ''),
        null => '',
      };
      _categoryKey = f.categoryKey;
      _subcategoryKey = f.subcategoryKey;
      _nameError = _priceError = _categoryError = null;
    });
    if (f.pricePiastres == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _priceFocus.requestFocus();
      });
    }
  }

  /// The live categories, and the catalogue's own when the product files
  /// under one the app does not have yet.
  List<CategoryView> get _categories {
    final key = _finding?.categoryKey;
    if (key == null || widget.categories.any((c) => c.key == key)) {
      return widget.categories;
    }
    final addition = widget.catalog.category(key);
    if (addition == null) return widget.categories;
    return [
      ...widget.categories,
      CategoryView(
        key: addition.key,
        labelAr: addition.labelAr,
        iconName: addition.iconName,
        colorKey: addition.colorKey,
      ),
    ];
  }

  Future<void> _photo() async {
    final current = _finding;
    if (current == null) return;
    setState(() => _reading = true);
    final read = await widget.onPhoto(current);
    if (!mounted) return;
    setState(() => _reading = false);
    if (read == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('ما قدرتش أقرا اسم المنتج من الصورة، اكتبه')));
      return;
    }
    // A price the user already typed is kept over the one read.
    final typed = _price.text;
    _apply(read);
    if (read.pricePiastres == null && typed.isNotEmpty) _price.text = typed;
  }

  int? get _typedPrice {
    final text = _price.text.trim();
    if (text.isEmpty) return null;
    final p = parsePiastres(text);
    return p == null || p <= 0 ? null : p;
  }

  void _decide(ScanAction action) {
    final finding = _finding!;
    final name = _name.text.trim();
    final price = _typedPrice;
    final needsCategory = action == ScanAction.save;
    setState(() {
      _nameError = name.isEmpty ? 'اكتب اسم المنتج' : null;
      _priceError = price == null
          ? (_price.text.trim().isEmpty ? 'اكتب السعر' : 'قيمة غير صحيحة')
          : null;
      _categoryError =
          needsCategory && _categoryKey == null ? 'اختار الفئة' : null;
    });
    if (_nameError != null || _priceError != null || _categoryError != null) {
      if (_priceError != null) _priceFocus.requestFocus();
      return;
    }
    Navigator.of(context).pop(ScanDecision(
      action: action,
      finding: finding,
      name: name,
      pricePiastres: price,
      categoryKey: _categoryKey,
      subcategoryKey: _subcategoryKey,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final f = _finding;
    return Padding(
      key: const Key('scan-result'),
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _codeRow(palette, f),
            const SizedBox(height: AppSpacing.md),
            if (f == null || _reading)
              Row(
                key: const Key('scan-looking'),
                children: [
                  const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: AppSpacing.ms),
                  Text(_reading ? 'بقرا الصورة…' : 'بدوّر على المنتج…',
                      style: AppText.body),
                ],
              )
            else
              ..._details(palette, f),
            const SizedBox(height: AppSpacing.lg),
            ..._actions(f),
          ],
        ),
      ),
    );
  }

  Widget _codeRow(AppPalette palette, ScanFinding? f) => Row(
        children: [
          Icon(AppIcons.barcode, size: 20, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              widget.code,
              key: const Key('scan-code'),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              style: AppText.bodyStrong.copyWith(
                  fontFamily: 'monospace', letterSpacing: 1.5),
            ),
          ),
          if (f != null)
            Container(
              key: const Key('scan-source'),
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.ms, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: f.source == ScanSource.unknown
                    ? palette.surfaceAlt
                    : palette.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                f.source.labelAr,
                style: AppText.caption.copyWith(
                  color: f.source == ScanSource.unknown
                      ? palette.textSecondary
                      : palette.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );

  List<Widget> _details(AppPalette palette, ScanFinding f) {
    final nameField = _editing ||
        f.name.isEmpty ||
        f.source == ScanSource.photo ||
        _nameError != null;
    final price = f.pricePiastres;
    final priceField = _editing || price == null || f.priceIsEstimate;
    final chips = _editing || _categoryKey == null || _categoryError != null;
    final detail = [f.size, f.brand].where((s) => s.isNotEmpty).join(' · ');
    final category =
        _categories.where((c) => c.key == _categoryKey).firstOrNull;
    return [
      if (nameField)
        TextField(
          key: const Key('scan-name'),
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'اسم المنتج',
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        )
      else
        Text(f.name, style: AppText.headline),
      if (f.nameEn.isNotEmpty && f.nameEn != f.name)
        Text(f.nameEn,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.end,
            style: AppText.label.copyWith(color: palette.textSecondary)),
      if (detail.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
          child: Text(detail,
              style: AppText.label.copyWith(color: palette.textSecondary)),
        ),
      const SizedBox(height: AppSpacing.md),
      if (price == null)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Icon(AppIcons.warning, size: 18, color: palette.warning),
              const SizedBox(width: AppSpacing.xs),
              Text('السعر مش معروف',
                  style: AppText.label.copyWith(color: palette.textPrimary)),
            ],
          ),
        ),
      if (priceField)
        TextField(
          key: const Key('scan-price'),
          controller: _price,
          focusNode: _priceFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppText.title,
          decoration: InputDecoration(
            labelText: 'السعر',
            suffixText: 'ج.م',
            helperText: f.priceIsEstimate && !_editing
                ? 'سعر تقريبي${f.priceNote == null ? '' : ' من ${f.priceNote}'}، أكده أو غيّره'
                : null,
            helperMaxLines: 2,
            errorText: _priceError,
          ),
          onChanged: (_) {
            if (_priceError != null) setState(() => _priceError = null);
          },
        )
      else
        Text(
          formatPiastres(price, withCurrency: true),
          key: const Key('scan-price-text'),
          style: AppText.display.copyWith(color: palette.textPrimary),
        ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Text('الفئة',
              style: AppText.label.copyWith(color: palette.textSecondary)),
          if (_categoryError != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(AppIcons.warning, size: 16, color: palette.negative),
            const SizedBox(width: AppSpacing.xs),
            Text(_categoryError!,
                style: AppText.caption.copyWith(color: palette.negative)),
          ] else if (!chips && category != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(category.labelAr, style: AppText.bodyStrong),
          ],
        ],
      ),
      if (chips) ...[
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          children: [
            for (final c in _categories)
              SelectableChip(
                key: ValueKey('scan-category-${c.key}'),
                label: c.labelAr,
                icon: iconFor(c.iconName),
                colorKey: c.colorKey,
                selected: c.key == _categoryKey,
                onTap: () => setState(() {
                  if (c.key != _categoryKey) _subcategoryKey = null;
                  _categoryKey = c.key;
                  if (c.key == f.categoryKey) {
                    _subcategoryKey = f.subcategoryKey;
                  }
                  _categoryError = null;
                }),
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _actions(ScanFinding? f) {
    final ready = f != null && !_reading;
    final mine = f?.item != null && f?.source == ScanSource.mine;
    const tall = Size(0, 52);
    const target = Size(48, 48);
    return [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('scan-record'),
              style: FilledButton.styleFrom(minimumSize: tall),
              onPressed: ready ? () => _decide(ScanAction.record) : null,
              icon: const Icon(AppIcons.payment),
              label: const Text('سجل كمصروف'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton.tonalIcon(
              key: const Key('scan-save'),
              style: FilledButton.styleFrom(minimumSize: tall),
              onPressed: ready ? () => _decide(ScanAction.save) : null,
              icon: Icon(mine ? AppIcons.check : AppIcons.add),
              label: Text(mine ? 'احفظ التعديل' : 'أضف لمنتجاتي'),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.center,
        children: [
          if (!_editing)
            TextButton.icon(
              key: const Key('scan-edit'),
              style: TextButton.styleFrom(minimumSize: target),
              onPressed: ready ? () => setState(() => _editing = true) : null,
              icon: const Icon(AppIcons.edit, size: 20),
              label: const Text('عدل'),
            ),
          if (f?.source != ScanSource.mine)
            TextButton.icon(
              key: const Key('scan-photo'),
              style: TextButton.styleFrom(minimumSize: target),
              onPressed: ready ? _photo : null,
              icon: const Icon(AppIcons.camera, size: 20),
              label: const Text('صوّر المنتج'),
            ),
          TextButton.icon(
            key: const Key('scan-again'),
            style: TextButton.styleFrom(minimumSize: target),
            onPressed: _reading
                ? null
                : () => Navigator.of(context).pop(ScanDecision(
                      action: ScanAction.again,
                      finding: f ??
                          ScanFinding(
                              code: widget.code, source: ScanSource.unknown),
                    )),
            icon: const Icon(AppIcons.barcode, size: 20),
            label: const Text('امسح تاني'),
          ),
          TextButton(
            key: const Key('scan-cancel'),
            style: TextButton.styleFrom(minimumSize: target),
            onPressed: _reading ? null : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    ];
  }
}
