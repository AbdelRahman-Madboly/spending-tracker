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
        _fixed = catalog;

  /// The app's one catalogue. Tests swap it for a fixed one (see
  /// test/flutter_test_config.dart) so no widget test reads the 1.5 MB
  /// bundled file.
  static ProductCatalogSource shared = ProductCatalogSource();

  final Future<String> Function() _read;
  ProductCatalog? _fixed;
  Future<ProductCatalog>? _loading;

  static Future<String> _never() => throw StateError('fixed catalogue');

  /// The catalogue, read and indexed the first time it is asked for.
  ///
  /// A fixed catalogue makes a fresh future on every call rather than one
  /// held from construction, so a source built outside a test's fake-async
  /// zone still completes inside it.
  Future<ProductCatalog> load() {
    final fixed = _fixed;
    if (fixed != null) return Future.value(fixed);
    return _loading ??= _load();
  }

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
