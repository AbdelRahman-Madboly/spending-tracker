import 'package:flutter/material.dart';

import '../../core/arabic_text.dart';
import '../../core/design/app_icons.dart';
import '../../core/design/category_colors.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/barcode_scan_service.dart';
import '../../data/product_catalog_source.dart';
import '../../domain/models.dart';
import '../../domain/product_catalog.dart';
import '../../domain/spending_repository.dart';
import '../add/widgets/category_strip.dart' show SelectableChip;
import '../capture/permission_prompt.dart';
import 'product_editor.dart';

/// Opens «المنتجات» over [context].
Future<void> openProductsScreen(
  BuildContext context,
  SpendingRepository repository, {
  ProductCatalogSource? catalog,
  BarcodeScanService? scanner,
  PermissionService? permissionService,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => ProductsScreen(
      repository: repository,
      catalog: catalog,
      scanner: scanner,
      permissionService: permissionService,
    ),
  ),
);

enum _Tab { mine, catalogue }

/// «المنتجات»: the user's own products (منتجاتي), to search, edit, archive
/// and add, by hand or by scanning, and the bundled catalogue (الدليل) to
/// browse and copy from.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.repository,
    this.catalog,
    this.scanner,
    this.permissionService,
  });

  final SpendingRepository repository;

  /// Defaults to the app's bundled catalogue.
  final ProductCatalogSource? catalog;

  /// Defaults to the camera scanner.
  final BarcodeScanService? scanner;
  final PermissionService? permissionService;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final BarcodeScanService _scanner =
      widget.scanner ?? MobileScannerBarcodeScanService();
  final _search = TextEditingController();

  _Tab _tab = _Tab.mine;
  String _query = '';
  String? _categoryKey;
  bool _archived = false;

  bool _loaded = false;
  ProductCatalog _catalog = ProductCatalog.empty;
  List<QuickPickItem> _items = const [];
  List<QuickPickItem> _archivedItems = const [];
  List<CategoryView> _categories = const [];

  /// Every category label the lists may need, archived ones included.
  Map<String, CategoryView> _categoryByKey = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = widget.repository;
    final catalog = await (widget.catalog ?? ProductCatalogSource.shared)
        .load();
    final items = await repo.allItems();
    final archivedItems = await repo.archivedItems();
    final categories = await repo.categories();
    final archivedCategories = await repo.archivedCategories();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _items = [...items]..sort((a, b) => a.nameAr.compareTo(b.nameAr));
      _archivedItems = archivedItems;
      _categories = categories;
      _categoryByKey = {
        for (final c in [...archivedCategories, ...categories]) c.key: c,
      };
      _loaded = true;
    });
  }

  CategoryView _category(String key) =>
      _categoryByKey[key] ??
      switch (_catalog.category(key)) {
        final c? => CategoryView(
          key: c.key,
          labelAr: c.labelAr,
          iconName: c.iconName,
          colorKey: c.colorKey,
        ),
        null => CategoryView(key: key, labelAr: key, iconName: 'category'),
      };

  // ---- actions ----

  Future<void> _edit(QuickPickItem item, {bool archived = false}) async {
    final changed = await openProductEditor(
      context,
      repository: widget.repository,
      scanner: _scanner,
      permissionService: widget.permissionService,
      item: item,
      archived: archived,
    );
    if (changed) await _load();
  }

  Future<void> _addNew([
    ProductPrefill prefill = const ProductPrefill(),
  ]) async {
    final changed = await openProductEditor(
      context,
      repository: widget.repository,
      scanner: _scanner,
      permissionService: widget.permissionService,
      prefill: prefill,
    );
    if (changed) await _load();
  }

  /// «امسح لإضافة منتج»: a known code opens its product, a catalogue code
  /// a new product filled in from the catalogue, any other a new product
  /// holding the code.
  Future<void> _scanToAdd() async {
    if (!await ensurePermission(
      context,
      AppPermission.camera,
      service: widget.permissionService,
    )) {
      return;
    }
    if (!mounted) return;
    final scanned = await _scanner.scan(context);
    final code = scanned?.trim() ?? '';
    if (code.isEmpty || !mounted) return;
    final known = await widget.repository.itemByBarcode(code);
    if (!mounted) return;
    if (known != null) return _edit(known);
    final product = _catalog.byBarcode(code);
    if (product == null) return _addNew(ProductPrefill(barcode: code));
    return _addNew(await _prefillFrom(product, barcode: code));
  }

  Future<ProductPrefill> _prefillFrom(
    CatalogueProduct product, {
    String? barcode,
  }) async {
    final keys = await ensureCatalogueCategory(
      widget.repository,
      _catalog,
      product,
    );
    return ProductPrefill(
      nameAr: product.nameAr,
      categoryKey: keys.categoryKey,
      subcategoryKey: keys.subcategoryKey,
      pricePiastres: product.pricePiastres,
      barcode: barcode ?? product.barcode,
    );
  }

  QuickPickItem? _mineFor(CatalogueProduct product) => _items
      .where(
        (i) =>
            i.barcode != null &&
            identical(_catalog.byBarcode(i.barcode!), product),
      )
      .firstOrNull;

  /// «أضف لمنتجاتي»: the catalogue product becomes one of the user's
  /// items, with no purchase recorded. One whose category cannot be filed
  /// automatically opens the editor to pick it.
  Future<void> _addToMine(CatalogueProduct product) async {
    final prefill = await _prefillFrom(product);
    if (!mounted) return;
    if (prefill.categoryKey == null) return _addNew(prefill);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.createItem(
        nameAr: prefill.nameAr,
        categoryKey: prefill.categoryKey!,
        subcategoryKey: prefill.subcategoryKey,
        defaultAmountPiastres: prefill.pricePiastres,
        barcode: prefill.barcode,
      );
    } on DuplicateBarcodeException catch (e) {
      final holder = await widget.repository.itemByBarcode(e.barcode);
      messenger.showSnackBar(
        SnackBar(
          content: Text(barcodeTakenMessage(holder?.nameAr ?? 'منتج تاني')),
        ),
      );
      return;
    }
    await _load();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('catalogue-added'),
          content: Text('«${product.nameAr}» اتضاف لمنتجاتك'),
        ),
      );
  }

  Future<void> _openCatalogueProduct(CatalogueProduct product) async {
    final mine = _mineFor(product);
    final action = await showModalBottomSheet<_SheetAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (sheetContext) => _CatalogueSheet(
        product: product,
        category: _category(product.categoryKey),
        inMine: mine != null,
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SheetAction.add:
        await _addToMine(product);
      case _SheetAction.open:
        if (mine != null) await _edit(mine);
    }
  }

  // ---- lists ----

  List<QuickPickItem> get _visibleItems {
    final key = normalizeArabic(_query);
    return [
      for (final item in _archived ? _archivedItems : _items)
        if ((_categoryKey == null || item.categoryKey == _categoryKey) &&
            (key.isEmpty || _itemMatches(key, item)))
          item,
    ];
  }

  bool _itemMatches(String key, QuickPickItem item) {
    if (normalizeArabic(item.nameAr).contains(key)) return true;
    final barcode = item.barcode;
    if (barcode == null) return false;
    if (barcode.contains(key)) return true;
    final product = _catalog.byBarcode(barcode);
    return product != null && ProductCatalog.productMatches(key, product);
  }

  List<CatalogueProduct> get _visibleCatalogue =>
      _catalog.search(_query, categoryKey: _categoryKey);

  /// The categories the filter row offers on the tab showing.
  List<CategoryView> get _filterCategories {
    if (_tab == _Tab.mine) return _categories;
    final keys = <String>{for (final p in _catalog.products) p.categoryKey};
    return [
      for (final c in _categories)
        if (keys.remove(c.key)) c,
      for (final key in keys) _category(key),
    ];
  }

  void _switchTab(_Tab tab) => setState(() {
    _tab = tab;
    _categoryKey = null;
    _archived = false;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            key: const Key('products-add'),
            icon: const Icon(AppIcons.add),
            tooltip: 'إضافة منتج',
            onPressed: () => _addNew(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('products-scan-add'),
        onPressed: _scanToAdd,
        icon: const Icon(AppIcons.barcode),
        label: const Text('امسح لإضافة منتج'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              0,
            ),
            child: _TabToggle(selected: _tab, onSelected: _switchTab),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              0,
            ),
            child: TextField(
              key: const Key('products-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'دوّر بالاسم أو الماركة أو الباركود',
                prefixIcon: const Icon(AppIcons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('products-search-clear'),
                        icon: const Icon(AppIcons.close),
                        tooltip: 'امسح البحث',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (text) => setState(() => _query = text),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.ms,
            ),
            child: Row(
              children: [
                SelectableChip(
                  key: const Key('products-filter-all'),
                  label: 'الكل',
                  icon: AppIcons.all,
                  selected: _categoryKey == null && !_archived,
                  onTap: () => setState(() {
                    _categoryKey = null;
                    _archived = false;
                  }),
                ),
                for (final c in _filterCategories)
                  SelectableChip(
                    key: ValueKey('products-filter-${c.key}'),
                    label: c.labelAr,
                    icon: iconFor(c.iconName),
                    colorKey: c.colorKey,
                    selected: _categoryKey == c.key,
                    onTap: () => setState(
                      () => _categoryKey = _categoryKey == c.key ? null : c.key,
                    ),
                  ),
                if (_tab == _Tab.mine)
                  SelectableChip(
                    key: const Key('products-filter-archived'),
                    label: 'المؤرشفة',
                    icon: AppIcons.archive,
                    selected: _archived,
                    onTap: () => setState(() => _archived = !_archived),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: SkeletonRows(count: 6),
      );
    }
    return _tab == _Tab.mine ? _buildMine() : _buildCatalogue();
  }

  Widget _empty({required String headline, required String caption}) =>
      ListView(
        key: const Key('products-empty'),
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          EmptyState(
            icon: AppIcons.barcode,
            headline: headline,
            caption: caption,
          ),
        ],
      );

  Widget _buildMine() {
    final items = _visibleItems;
    if (items.isEmpty) {
      return _query.isNotEmpty || _categoryKey != null
          ? _empty(
              headline: 'مفيش منتج بالاسم ده',
              caption: 'جرّب اسم تاني أو الباركود، أو دوّر في الدليل',
            )
          : _archived
          ? _empty(
              headline: 'مفيش منتجات مؤرشفة',
              caption: 'المنتج اللي تأرشفه بيستنى هنا لحد ما ترجعه',
            )
          : _empty(
              headline: 'لسه مفيش منتجات',
              caption: 'امسح باركود منتج أو ضيفه من الدليل',
            );
    }
    return ListView.builder(
      padding: const EdgeInsetsDirectional.only(bottom: 96),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final product = item.barcode == null
            ? null
            : _catalog.byBarcode(item.barcode!);
        return _ProductRow(
          key: ValueKey('product-${item.id}'),
          name: item.nameAr,
          detail: _detail(product),
          barcode: item.barcode,
          category: _category(item.categoryKey),
          pricePiastres: item.defaultAmountPiastres,
          onTap: () => _edit(item, archived: _archived),
        );
      },
    );
  }

  Widget _buildCatalogue() {
    if (_catalog.isEmpty) {
      return _empty(
        headline: 'الدليل مش موجود',
        caption: 'النسخة دي من التطبيق مفيهاش دليل منتجات',
      );
    }
    final products = _visibleCatalogue;
    if (products.isEmpty) {
      return _empty(
        headline: 'مفيش منتج بالاسم ده في الدليل',
        caption: 'جرّب اسم تاني أو الماركة أو الباركود',
      );
    }
    return ListView.builder(
      padding: const EdgeInsetsDirectional.only(bottom: 96),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        return _ProductRow(
          key: ValueKey('catalogue-${p.barcode}'),
          name: p.nameAr,
          detail: _detail(p),
          barcode: p.barcode,
          category: _category(p.categoryKey),
          pricePiastres: p.pricePiastres,
          onTap: () => _openCatalogueProduct(p),
        );
      },
    );
  }

  static String? _detail(CatalogueProduct? p) {
    if (p == null) return null;
    final parts = [p.size, p.brand].where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// One product in either list: its name, size and brand, category chip and
/// barcode, and its price at the end.
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    super.key,
    required this.name,
    required this.category,
    required this.onTap,
    this.detail,
    this.barcode,
    this.pricePiastres,
  });

  final String name;
  final String? detail;
  final String? barcode;
  final CategoryView category;
  final int? pricePiastres;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = palette.categoryInk(category.colorKey);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.ms,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.categoryInkFill(category.colorKey),
                shape: BoxShape.circle,
              ),
              child: Icon(iconFor(category.iconName), size: 20, color: ink),
            ),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong,
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.categoryInkFill(category.colorKey),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                        child: Text(
                          category.labelAr,
                          style: AppText.caption.copyWith(color: ink),
                        ),
                      ),
                      if (barcode != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          AppIcons.barcode,
                          size: 16,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            barcode!,
                            textDirection: TextDirection.ltr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              pricePiastres == null
                  ? '—'
                  : formatPiastres(pricePiastres!, withCurrency: true),
              style: AppText.bodyStrong.copyWith(
                color: pricePiastres == null
                    ? palette.textSecondary
                    : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// منتجاتي | الدليل: two 48dp halves, the selected one filled.
class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.selected, required this.onSelected});

  final _Tab selected;
  final ValueChanged<_Tab> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget half(_Tab tab, String label, Key key) {
      final on = tab == selected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? palette.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(AppRadii.full),
              onTap: () => onSelected(tab),
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    label,
                    style: AppText.label.copyWith(
                      color: on
                          ? palette.onPrimaryContainer
                          : palette.textSecondary,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        children: [
          half(_Tab.mine, 'منتجاتي', const Key('products-tab-mine')),
          half(_Tab.catalogue, 'الدليل', const Key('products-tab-catalogue')),
        ],
      ),
    );
  }
}

enum _SheetAction { add, open }

/// A catalogue product up close, with «أضف لمنتجاتي».
class _CatalogueSheet extends StatelessWidget {
  const _CatalogueSheet({
    required this.product,
    required this.category,
    required this.inMine,
  });

  final CatalogueProduct product;
  final CategoryView category;
  final bool inMine;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final price = product.pricePiastres;
    final priceDate = product.priceDate;
    return SafeArea(
      child: Padding(
        key: const Key('catalogue-sheet'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.gutter,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(product.nameAr, style: AppText.headline),
            if (product.nameEn.isNotEmpty)
              Text(
                product.nameEn,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.end,
                style: AppText.label.copyWith(color: palette.textSecondary),
              ),
            const SizedBox(height: AppSpacing.md),
            _Fact('الفئة', category.labelAr),
            if (product.brand.isNotEmpty) _Fact('الماركة', product.brand),
            if (product.size.isNotEmpty) _Fact('الحجم', product.size),
            _Fact('الباركود', product.barcode, ltr: true),
            _Fact(
              'السعر',
              price == null
                  ? 'مش معروف'
                  : formatPiastres(price, withCurrency: true),
            ),
            if (price != null && priceDate != null)
              Text(
                'سعر ${product.priceSource ?? 'محل'} يوم '
                '${priceDate.day}/${priceDate.month}/${priceDate.year}. '
                'السعر اللي تدفعه هو اللي بيتسجل.',
                style: AppText.caption.copyWith(color: palette.textSecondary),
              ),
            const SizedBox(height: AppSpacing.lg),
            if (inMine) ...[
              Row(
                key: const Key('catalogue-in-mine'),
                children: [
                  Icon(AppIcons.checkCircle, size: 20, color: palette.positive),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('في منتجاتك', style: AppText.bodyStrong),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const Key('catalogue-open-mine'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.of(context).pop(_SheetAction.open),
                child: const Text('افتح المنتج'),
              ),
            ] else
              FilledButton.icon(
                key: const Key('catalogue-add-mine'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.of(context).pop(_SheetAction.add),
                icon: const Icon(AppIcons.add),
                label: const Text('أضف لمنتجاتي'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppText.label.copyWith(color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: TextAlign.start,
              style: AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}
