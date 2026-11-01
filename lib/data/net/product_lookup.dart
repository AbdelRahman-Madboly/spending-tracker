import 'dart:convert';

import '../../domain/online_features.dart';
import '../../domain/spending_repository.dart';
import 'network_gate.dart';

/// Names a product from its barcode (spec §6.3), or gives null.
abstract class ProductLookup {
  Future<String?> nameFor(String barcode);
}

/// The `app_settings` key holding when the recent lookups were sent, as
/// comma-separated milliseconds since the epoch: the rate stamp that keeps
/// lookups under Open Food Facts' limit across app restarts.
const productLookupStampsSettingKey = 'product_lookup_stamps';

/// Open Food Facts v3, through [NetworkGate] as [OnlineFeature.productLookup].
///
/// Every failure gives null rather than an error: the lookup only saves
/// typing, and the scan goes on to ask for the name either way. That covers
/// the switch being off, no connection, the 5-second timeout, an unknown
/// product, a body that does not parse, and a 16th lookup within a minute
/// (Open Food Facts asks for at most 15 product reads a minute).
class OpenFoodFactsLookup implements ProductLookup {
  OpenFoodFactsLookup(this._gate, this._repository,
      {this.clock = DateTime.now});

  final NetworkGate _gate;
  final SpendingRepository _repository;

  /// Dates the rate stamps.
  final DateTime Function() clock;

  static const userAgent = 'Masarifi/3.0 (personal Android app)';
  static const perMinute = 15;
  static const timeout = Duration(seconds: 5);

  /// EAN-8, UPC-A, EAN-13 and GTIN-14 are all digits. Anything else (a QR
  /// code's URL, a store's own label) is not a product Open Food Facts
  /// knows, and is never put into a request path.
  static final _productCode = RegExp(r'^\d{6,14}$');

  @override
  Future<String?> nameFor(String barcode) async {
    if (!_productCode.hasMatch(barcode)) return null;
    if (!await isOnlineFeatureOn(_repository, OnlineFeature.productLookup)) {
      return null;
    }
    if (!await _takeSlot()) return null;
    try {
      final response = await _gate.get(
        OnlineFeature.productLookup,
        Uri.https('world.openfoodfacts.org', '/api/v3/product/$barcode', {
          'fields': 'product_name_ar,product_name,brands,quantity',
        }),
        headers: const {'User-Agent': userAgent},
        timeout: timeout,
      );
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map || body['product'] is! Map) return null;
      return _nameOf(body['product'] as Map);
    } catch (_) {
      return null;
    }
  }

  /// `product_name_ar`, then `product_name`, then the first brand with the
  /// quantity ("Juhayna 1 L").
  static String? _nameOf(Map product) {
    String text(String key) {
      final value = product[key];
      return value is String ? value.trim() : '';
    }

    for (final key in ['product_name_ar', 'product_name']) {
      if (text(key).isNotEmpty) return text(key);
    }
    final brand = text('brands').split(',').first.trim();
    if (brand.isEmpty) return null;
    return [brand, text('quantity')].where((s) => s.isNotEmpty).join(' ');
  }

  /// Records a lookup now when fewer than [perMinute] were sent in the last
  /// minute, and says whether there was room.
  Future<bool> _takeSlot() async {
    final now = clock().millisecondsSinceEpoch;
    final stored = await _repository.setting(productLookupStampsSettingKey);
    final recent = [
      for (final part in (stored ?? '').split(','))
        if (int.tryParse(part) case final stamp?)
          if (now - stamp < 60000 && stamp <= now) stamp,
    ];
    if (recent.length >= perMinute) return false;
    await _repository.setSetting(
        productLookupStampsSettingKey, [...recent, now].join(','));
    return true;
  }
}
