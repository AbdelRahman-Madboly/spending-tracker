import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../core/quantity.dart';
import '../../data/barcode_scan_service.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/widgets/category_strip.dart' show SelectableChip;
import '../capture/permission_prompt.dart';

/// What a new product starts with: a scanned code, and whatever the
/// catalogue knows about it.
class ProductPrefill {
  const ProductPrefill({
    this.nameAr = '',
    this.categoryKey,
    this.subcategoryKey,
    this.pricePiastres,
    this.barcode,
  });

  final String nameAr;
  final String? categoryKey;
  final String? subcategoryKey;
  final int? pricePiastres;
  final String? barcode;
}

/// The Arabic refusal of a barcode another live product holds.
String barcodeTakenMessage(String holderName) =>
    'الباركود ده مسجل على «$holderName»';

/// Opens the editor for [item] (an existing product, [archived] when it
/// sits in the archive) or for a new product from [prefill]. Resolves to
/// true when something was saved, archived or brought back.
Future<bool> openProductEditor(
  BuildContext context, {
  required SpendingRepository repository,
  required BarcodeScanService scanner,
  PermissionService? permissionService,
  QuickPickItem? item,
  bool archived = false,
  ProductPrefill prefill = const ProductPrefill(),
}) async {
  final changed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ProductEditorScreen(
        repository: repository,
        scanner: scanner,
        permissionService: permissionService,
        item: item,
        archived: archived,
        prefill: prefill,
      ),
    ),
  );
  return changed ?? false;
}

/// One product's page: its name, category and subcategory, default price
/// and barcode, what it cost each time it was bought, and archiving.
class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({
    super.key,
    required this.repository,
    required this.scanner,
    this.permissionService,
    this.item,
    this.archived = false,
    this.prefill = const ProductPrefill(),
  });

  final SpendingRepository repository;
  final BarcodeScanService scanner;
  final PermissionService? permissionService;
  final QuickPickItem? item;
  final bool archived;
  final ProductPrefill prefill;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  late final _name = TextEditingController(
    text: widget.item?.nameAr ?? widget.prefill.nameAr,
  );
  late final _price = TextEditingController(
    text: switch (widget.item?.defaultAmountPiastres ??
        widget.prefill.pricePiastres) {
      final p? => formatPiastres(p).replaceAll(',', ''),
      null => '',
    },
  );
  late final _quantity = TextEditingController(
    text: switch (widget.item?.defaultQuantityMilli) {
      final q? => formatQuantityMilli(q),
      null => '',
    },
  );
  late String? _unit = widget.item?.unit;
  late final _barcode = TextEditingController(
    text: widget.item?.barcode ?? widget.prefill.barcode ?? '',
  );
  late String? _categoryKey =
      widget.item?.categoryKey ?? widget.prefill.categoryKey;
  late String? _subcategoryKey =
      widget.item?.subcategoryKey ?? widget.prefill.subcategoryKey;

  List<CategoryView> _categories = const [];
  List<SubcategoryView> _subcategories = const [];
  List<ItemPrice>? _history;
  String? _nameError;
  String? _categoryError;
  String? _priceError;
  String? _quantityError;
  String? _barcodeError;
  bool _busy = false;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _quantity.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final categories = await widget.repository.categories();
    final subcategories = _categoryKey == null
        ? const <SubcategoryView>[]
        : await widget.repository.subcategories(_categoryKey!);
    final item = widget.item;
    final history = item == null
        ? const <ItemPrice>[]
        : await widget.repository.itemPriceHistory(item.id);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _subcategories = subcategories;
      _history = history;
    });
  }

  Future<void> _pickCategory(String key) async {
    if (key == _categoryKey) return;
    setState(() {
      _categoryKey = key;
      _subcategoryKey = null;
      _categoryError = null;
      _subcategories = const [];
    });
    final subcategories = await widget.repository.subcategories(key);
    if (!mounted || _categoryKey != key) return;
    setState(() => _subcategories = subcategories);
  }

  Future<void> _scanBarcode() async {
    if (!await ensurePermission(
      context,
      AppPermission.camera,
      service: widget.permissionService,
    )) {
      return;
    }
    if (!mounted) return;
    final code = await widget.scanner.scan(context);
    if (code == null || !mounted) return;
    setState(() {
      _barcode.text = code.trim();
      _barcodeError = null;
    });
  }

  /// The Arabic refusal naming the product that holds [barcode].
  Future<String> _takenMessage(String barcode) async {
    final holder = await widget.repository.itemByBarcode(barcode);
    return barcodeTakenMessage(holder?.nameAr ?? 'منتج تاني');
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final priceText = _price.text.trim();
    final price = priceText.isEmpty ? null : parsePiastres(priceText);
    final barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim();
    final unit = _unit;
    final quantityText = _quantity.text.trim();
    final quantity = unit == null || quantityText.isEmpty
        ? null
        : parseQuantityMilli(quantityText);
    setState(() {
      _quantityError = unit != null && quantityText.isNotEmpty && quantity == null
          ? 'كمية غير صحيحة'
          : null;
      _nameError = name.isEmpty ? 'اكتب اسم المنتج' : null;
      _categoryError = _categoryKey == null ? 'اختار الفئة' : null;
      _priceError = priceText.isNotEmpty && price == null
          ? 'قيمة غير صحيحة'
          : null;
      _barcodeError = null;
    });
    if (_nameError != null ||
        _categoryError != null ||
        _priceError != null ||
        _quantityError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final item = widget.item;
      if (item == null) {
        await widget.repository.createItem(
          nameAr: name,
          categoryKey: _categoryKey!,
          subcategoryKey: _subcategoryKey,
          defaultAmountPiastres: price,
          barcode: barcode,
          unit: unit,
          defaultQuantityMilli: quantity,
        );
      } else {
        await widget.repository.updateProduct(
          itemId: item.id,
          nameAr: name,
          categoryKey: _categoryKey!,
          subcategoryKey: _subcategoryKey,
          defaultAmountPiastres: price,
          barcode: barcode,
          unit: unit,
          defaultQuantityMilli: quantity,
        );
      }
    } on DuplicateBarcodeException catch (e) {
      final message = await _takenMessage(e.barcode);
      if (mounted) {
        setState(() {
          _barcodeError = message;
          _busy = false;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _archive() async {
    await widget.repository.archiveItem(widget.item!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _unarchive() async {
    try {
      await widget.repository.unarchiveItem(widget.item!.id);
    } on DuplicateBarcodeException catch (e) {
      final message = await _takenMessage(e.barcode);
      if (mounted) setState(() => _barcodeError = message);
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      key: const Key('product-editor'),
      appBar: AppBar(
        title: Text(_isNew ? 'منتج جديد' : 'تعديل منتج'),
        actions: [
          if (!_isNew && !widget.archived)
            IconButton(
              key: const Key('product-archive'),
              icon: const Icon(AppIcons.archive),
              tooltip: 'أرشفة',
              onPressed: _busy ? null : _archive,
            ),
          if (!_isNew && widget.archived)
            IconButton(
              key: const Key('product-unarchive'),
              icon: const Icon(AppIcons.unarchive),
              tooltip: 'استعادة',
              onPressed: _busy ? null : _unarchive,
            ),
        ],
      ),
      // A short form: every field is built at once, so none is lost to a
      // lazy list while the keyboard is up.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('product-name'),
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'اسم المنتج',
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _Label('الفئة', error: _categoryError),
            Wrap(
              children: [
                for (final c in _categories)
                  SelectableChip(
                    key: ValueKey('product-category-${c.key}'),
                    label: c.labelAr,
                    icon: iconFor(c.iconName),
                    colorKey: c.colorKey,
                    selected: c.key == _categoryKey,
                    onTap: () => _pickCategory(c.key),
                  ),
              ],
            ),
            if (_subcategories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const _Label('الفئة الفرعية'),
              Wrap(
                children: [
                  for (final s in _subcategories)
                    SelectableChip(
                      key: ValueKey('product-subcategory-${s.key}'),
                      label: s.labelAr,
                      icon: iconFor(s.iconName),
                      colorKey: _categories
                          .where((c) => c.key == _categoryKey)
                          .firstOrNull
                          ?.colorKey,
                      selected: s.key == _subcategoryKey,
                      // A second tap on the chosen one files it under the
                      // category alone.
                      onTap: () => setState(
                        () => _subcategoryKey = s.key == _subcategoryKey
                            ? null
                            : s.key,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const _Label('بيتباع بـ'),
            Wrap(
              children: [
                SelectableChip(
                  key: const ValueKey('product-unit-none'),
                  label: 'بالقطعة/العبوة',
                  icon: AppIcons.piece,
                  selected: _unit == null,
                  onTap: () => setState(() {
                    _unit = null;
                    _quantityError = null;
                  }),
                ),
                for (final unit in looseUnits)
                  SelectableChip(
                    key: ValueKey('product-unit-$unit'),
                    label: entryUnitLabels[unit]!,
                    icon: AppIcons.scale,
                    selected: _unit == unit,
                    onTap: () => setState(() => _unit = unit),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('product-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppText.body,
              decoration: InputDecoration(
                labelText: _unit == null ? 'السعر' : pricePerUnitLabel(_unit!),
                helperText: 'بيتحدث لوحده بآخر سعر دفعته',
                suffixText: 'ج.م',
                errorText: _priceError,
              ),
            ),
            if (_unit != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('product-quantity'),
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppText.body,
                decoration: InputDecoration(
                  labelText: 'الكمية المعتادة',
                  helperText: 'اللي بتشتريه عادة، وتقدر تغيره وانت بتسجل',
                  suffixText: entryUnitLabels[_unit],
                  errorText: _quantityError,
                ),
                onChanged: (_) {
                  if (_quantityError != null) {
                    setState(() => _quantityError = null);
                  }
                },
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('product-barcode'),
              controller: _barcode,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'الباركود',
                errorText: _barcodeError,
                errorMaxLines: 2,
                suffixIcon: IconButton(
                  key: const Key('product-barcode-scan'),
                  icon: const Icon(AppIcons.barcode),
                  tooltip: 'امسح الباركود',
                  onPressed: _scanBarcode,
                ),
              ),
              onChanged: (_) {
                if (_barcodeError != null) setState(() => _barcodeError = null);
              },
            ),
            if (!_isNew) ...[
              const SizedBox(height: AppSpacing.section),
              _PriceHistory(
                key: const Key('product-history'),
                history: _history,
                unit: widget.item?.unit,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (widget.archived)
              Text(
                'المنتج ده في الأرشيف: مش بيظهر في الإضافة ولا بيتعرف عليه '
                'بالباركود لحد ما ترجعه.',
                style: AppText.caption.copyWith(color: palette.textSecondary),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: FilledButton(
            key: const Key('product-save'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _busy ? null : _save,
            child: const Text('حفظ'),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.error});

  final String text;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            text,
            style: AppText.label.copyWith(color: palette.textSecondary),
          ),
          if (error != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(AppIcons.warning, size: 16, color: palette.negative),
            const SizedBox(width: AppSpacing.xs),
            Text(
              error!,
              style: AppText.caption.copyWith(color: palette.negative),
            ),
          ],
        ],
      ),
    );
  }
}

/// What one of the product cost each time it was bought, newest first.
class _PriceHistory extends StatelessWidget {
  const _PriceHistory({super.key, required this.history, this.unit});

  final List<ItemPrice>? history;

  /// The product's unit, when it is sold by one: each price is then per
  /// unit.
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final points = history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('الأسعار اللي دفعتها', style: AppText.title),
        const SizedBox(height: AppSpacing.sm),
        if (points == null)
          const SizedBox(height: 48)
        else if (points.isEmpty)
          Text(
            'لسه ما اشتريتوش من ساعة ما اتسجل.',
            style: AppText.label.copyWith(color: palette.textSecondary),
          )
        else
          for (final (i, p) in points.indexed)
            Container(
              key: ValueKey('price-$i'),
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${p.date.day}/${p.date.month}/${p.date.year}',
                      style: AppText.body,
                    ),
                  ),
                  if (p.quantityMilli case final q? when q != 1000 && q > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
                      child: Text(
                        'الإجمالي ${formatPiastres(p.amountPiastres)}',
                        style: AppText.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  Text(
                    unit == null
                        ? formatPiastres(p.unitPricePiastres, withCurrency: true)
                        : formatPiastresPer(
                            p.unitPricePiastres, entryUnitLabels[unit]!),
                    style: AppText.bodyStrong,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
