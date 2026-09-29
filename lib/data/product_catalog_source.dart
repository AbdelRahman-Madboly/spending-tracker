import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/product_catalog.dart';

/// Where the bundled product catalogue lives.
const productCatalogAsset = 'assets/catalog/egypt_products.json';

/// Loads the bundled product catalogue on first use, never at startup, and
/// keeps it for the life of the app. A missing or unreadable file is an
/// empty catalogue, so the app works exactly as it does without one.
class ProductCatalogSource {
  ProductCatalogSource({Future<String> Function()? read})
      : _read = read ?? (() => rootBundle.loadString(productCatalogAsset));

  /// A source that already holds [catalog], for tests.
  ProductCatalogSource.fixed(ProductCatalog catalog)
      : _read = _never,
        _loading = Future.value(catalog);

  /// The app's one catalogue.
  static final shared = ProductCatalogSource();

  final Future<String> Function() _read;
  Future<ProductCatalog>? _loading;

  static Future<String> _never() => throw StateError('fixed catalogue');

  /// The catalogue, read and indexed the first time it is asked for.
  Future<ProductCatalog> load() => _loading ??= _load();

  Future<ProductCatalog> _load() async {
    try {
      final text = await _read();
      // A big file is parsed off the UI thread, so the first scan does not
      // freeze the screen while it is indexed.
      return text.length > 200000
          ? await compute(ProductCatalog.parse, text)
          : ProductCatalog.parse(text);
    } catch (_) {
      return ProductCatalog.empty;
    }
  }
}
