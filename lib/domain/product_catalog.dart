import 'dart:convert';

import '../core/arabic_text.dart';
import 'spending_repository.dart';

/// A category the catalogue files products under that the app may not have
/// yet. Created, by key, the first time a product needs it.
class CatalogueCategory {
  const CatalogueCategory({
    required this.key,
    required this.labelAr,
    required this.iconName,
    this.colorKey = 'Other',
  });

  final String key;
  final String labelAr;
  final String iconName;
  final String colorKey;
}

/// A subcategory the catalogue may add under [categoryKey].
class CatalogueSubcategory {
  const CatalogueSubcategory({
    required this.key,
    required this.categoryKey,
    required this.labelAr,
    required this.iconName,
  });

  final String key;
  final String categoryKey;
  final String labelAr;
  final String iconName;
}

/// One product of the bundled Egyptian product catalogue. Money is integer
/// piastres; a product with no known price has a null [pricePiastres].
class CatalogueProduct {
  const CatalogueProduct({
    required this.barcode,
    required this.nameAr,
    this.nameEn = '',
    this.brand = '',
    this.size = '',
    required this.categoryKey,
    this.subcategoryKey,
    this.pricePiastres,
    this.priceSource,
    this.priceDate,
  });

  final String barcode;
  final String nameAr;
  final String nameEn;
  final String brand;
  final String size;
  final String categoryKey;
  final String? subcategoryKey;
  final int? pricePiastres;
  final String? priceSource;
  final DateTime? priceDate;
}

/// The bundled product catalogue (`assets/catalog/egypt_products.json`,
/// format `product-catalog/1`): products known by barcode before the user
/// has ever scanned them, and the categories they need.
///
/// Read only. A scan of a catalogue product is a suggestion: it becomes the
/// user's own item only when a line with it is saved (spec §6.3).
class ProductCatalog {
  ProductCatalog._({
    required this.builtOn,
    required this.categories,
    required this.subcategories,
    required this.products,
  }) : _byBarcode = {
          for (final p in products.reversed) p.barcode: p,
        };

  /// No products: the app as it is without the catalogue file.
  static final empty = ProductCatalog._(
    builtOn: null,
    categories: const [],
    subcategories: const [],
    products: const [],
  );

  static const format = 'product-catalog/1';

  final DateTime? builtOn;
  final List<CatalogueCategory> categories;
  final List<CatalogueSubcategory> subcategories;

  /// Every product, in file order, one per barcode.
  final List<CatalogueProduct> products;
  final Map<String, CatalogueProduct> _byBarcode;

  bool get isEmpty => products.isEmpty;

  /// Reads a catalogue file. Throws [FormatException] when the text is not
  /// JSON or not this format. A product row with no barcode or no Arabic
  /// name is skipped, and of two rows with one barcode the first is kept.
  factory ProductCatalog.parse(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('not a product catalogue: $e');
    }
    if (root is! Map<String, Object?> || root['format'] != format) {
      throw const FormatException('not a product-catalog/1 file');
    }
    final additions = root['catalogueAdditions'];
    final additionMap =
        additions is Map<String, Object?> ? additions : const <String, Object?>{};
    final categories = [
      for (final row in _rows(additionMap['categories']))
        if (_text(row['key']) case final key? when key.isNotEmpty)
          CatalogueCategory(
            key: key,
            labelAr: _text(row['labelAr']) ?? key,
            iconName: _text(row['iconName']) ?? 'category',
            colorKey: _text(row['colorKey']) ?? 'Other',
          ),
    ];
    final subcategories = [
      for (final row in _rows(additionMap['subcategories']))
        if ((_text(row['key']), _text(row['categoryKey']))
            case (final key?, final categoryKey?)
            when key.isNotEmpty && categoryKey.isNotEmpty)
          CatalogueSubcategory(
            key: key,
            categoryKey: categoryKey,
            labelAr: _text(row['labelAr']) ?? key,
            iconName: _text(row['iconName']) ?? 'category',
          ),
    ];
    final seen = <String>{};
    final products = <CatalogueProduct>[];
    for (final row in _rows(root['products'])) {
      final barcode = _text(row['barcode']) ?? '';
      final nameAr = _text(row['nameAr']) ?? '';
      final categoryKey = _text(row['categoryKey']) ?? '';
      if (barcode.isEmpty || nameAr.isEmpty || categoryKey.isEmpty) continue;
      if (!seen.add(barcode)) continue;
      final price = row['pricePiastres'];
      products.add(CatalogueProduct(
        barcode: barcode,
        nameAr: nameAr,
        nameEn: _text(row['nameEn']) ?? '',
        brand: _text(row['brand']) ?? '',
        size: _text(row['size']) ?? '',
        categoryKey: categoryKey,
        subcategoryKey: switch (_text(row['subcategoryKey'])) {
          final key? when key.isNotEmpty => key,
          _ => null,
        },
        pricePiastres: price is int && price > 0 ? price : null,
        priceSource: _text(row['priceSource']),
        priceDate: _date(row['priceDate']),
      ));
    }
    return ProductCatalog._(
      builtOn: _date(root['builtOn']),
      categories: categories,
      subcategories: subcategories,
      products: products,
    );
  }

  /// The product with [code], or null. A 12-digit UPC-A code also finds
  /// the same product written as EAN-13 with a leading zero, and the other
  /// way round: scanners report either.
  CatalogueProduct? byBarcode(String code) {
    final value = code.trim();
    if (value.isEmpty) return null;
    return _byBarcode[value] ??
        (value.length == 12
            ? _byBarcode['0$value']
            : value.length == 13 && value.startsWith('0')
                ? _byBarcode[value.substring(1)]
                : null);
  }

  CatalogueCategory? category(String key) =>
      categories.where((c) => c.key == key).firstOrNull;

  CatalogueSubcategory? subcategory(String key) =>
      subcategories.where((s) => s.key == key).firstOrNull;

  /// Products whose Arabic name, English name or brand holds [query]
  /// (compared through [normalizeArabic]) or whose barcode holds it, in
  /// file order, optionally only those filed under [categoryKey].
  List<CatalogueProduct> search(String query, {String? categoryKey}) {
    final key = normalizeArabic(query);
    return [
      for (final p in products)
        if ((categoryKey == null || p.categoryKey == categoryKey) &&
            (key.isEmpty || productMatches(key, p)))
          p,
    ];
  }

  /// Whether [normalizedQuery] (already through [normalizeArabic]) is in
  /// [p]'s names, brand or barcode.
  static bool productMatches(String normalizedQuery, CatalogueProduct p) =>
      normalizeArabic(p.nameAr).contains(normalizedQuery) ||
      normalizeArabic(p.nameEn).contains(normalizedQuery) ||
      normalizeArabic(p.brand).contains(normalizedQuery) ||
      p.barcode.contains(normalizedQuery);

  static Iterable<Map<String, Object?>> _rows(Object? list) =>
      list is List ? list.whereType<Map<String, Object?>>() : const [];

  static String? _text(Object? value) =>
      value is String ? value.trim() : null;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// The category and subcategory a catalogue product files under in the app,
/// creating them from the catalogue's additions (by key, so only once) the
/// first time one is needed.
///
/// A category the user archived is not brought back: the product then has
/// no category and the user files it in review. The same goes for a
/// category or subcategory neither the app nor the additions know, and for
/// a subcategory whose key the app already uses somewhere else.
Future<({String? categoryKey, String? subcategoryKey})> ensureCatalogueCategory(
  SpendingRepository repository,
  ProductCatalog catalog,
  CatalogueProduct product,
) async {
  const none = (categoryKey: null, subcategoryKey: null);
  final categoryKey = product.categoryKey;
  final live = await repository.categories();
  if (!live.any((c) => c.key == categoryKey)) {
    final archived = await repository.archivedCategories();
    if (archived.any((c) => c.key == categoryKey)) return none;
    final addition = catalog.category(categoryKey);
    if (addition == null) return none;
    try {
      await repository.createCategory(
        key: addition.key,
        labelAr: addition.labelAr,
        iconName: addition.iconName,
        colorKey: addition.colorKey,
      );
    } catch (_) {
      return none;
    }
  }
  final subcategoryKey = product.subcategoryKey;
  if (subcategoryKey == null) {
    return (categoryKey: categoryKey, subcategoryKey: null);
  }
  final subs = await repository.subcategories(categoryKey);
  if (subs.any((s) => s.key == subcategoryKey)) {
    return (categoryKey: categoryKey, subcategoryKey: subcategoryKey);
  }
  final addition = catalog.subcategory(subcategoryKey);
  final archived = await repository.archivedSubcategories();
  if (addition == null ||
      addition.categoryKey != categoryKey ||
      archived.any((s) => s.key == subcategoryKey) ||
      await _subcategoryKeyTaken(repository, subcategoryKey)) {
    return (categoryKey: categoryKey, subcategoryKey: null);
  }
  try {
    await repository.createSubcategory(
      key: addition.key,
      categoryKey: categoryKey,
      labelAr: addition.labelAr,
      iconName: addition.iconName,
    );
  } catch (_) {
    return (categoryKey: categoryKey, subcategoryKey: null);
  }
  return (categoryKey: categoryKey, subcategoryKey: subcategoryKey);
}

Future<bool> _subcategoryKeyTaken(
    SpendingRepository repository, String key) async {
  for (final category in await repository.categories()) {
    if ((await repository.subcategories(category.key))
        .any((s) => s.key == key)) {
      return true;
    }
  }
  return false;
}
