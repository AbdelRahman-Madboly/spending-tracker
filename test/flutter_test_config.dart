import 'dart:async';
import 'dart:io';

import 'package:spending_tracker/data/instapay_identity.dart';
import 'package:spending_tracker/data/product_catalog_source.dart';
import 'package:spending_tracker/domain/product_catalog.dart';

/// Every test starts with an empty product catalogue, the way the app
/// behaves without the bundled file. Tests that need catalogue products
/// pass their own `ProductCatalogSource.fixed(...)`; the bundled file
/// itself is checked in test/domain/bundled_catalog_test.dart.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ProductCatalogSource.shared = ProductCatalogSource.fixed(ProductCatalog.empty);
  // The personal build's InstaPay default, read from disk at once: an
  // asset load would not finish inside a widget test's fake clock.
  // test/data/instapay_identity_test.dart checks the bundled one.
  final defaults = File(personalDefaultsAsset).readAsStringSync();
  personalInstaPayDefault = () => Future.value(instaPayDefaultFrom(defaults));
  await testMain();
}
