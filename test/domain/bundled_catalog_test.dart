import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_icons.dart';
import 'package:spending_tracker/domain/product_catalog.dart';

/// Guards the bundled sample file, not the fixture the other catalogue
/// tests use: it must parse whole, keep every product, and name only icons
/// the app can draw.
void main() {
  final catalog = ProductCatalog.parse(
      File('assets/catalog/egypt_products.json').readAsStringSync());

  test('the bundled catalogue parses with every sample product priced', () {
    expect(catalog.products, hasLength(20));
    expect(catalog.products.where((p) => p.pricePiastres != null),
        hasLength(20));
  });

  test('an everyday product is found by its barcode', () {
    final pepsi = catalog.products.firstWhere((p) => p.nameAr == 'بيبسي 1 لتر');
    expect(catalog.byBarcode(pepsi.barcode)?.nameAr, 'بيبسي 1 لتر');
  });

  test('every category and subcategory it adds has a drawable icon', () {
    for (final name in [
      ...catalog.categories.map((c) => c.iconName),
      ...catalog.subcategories.map((s) => s.iconName),
    ]) {
      expect(iconFor(name), isNot(iconFor('category')), reason: name);
    }
  });
}
