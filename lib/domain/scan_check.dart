import 'dart:convert';
import 'dart:typed_data';

import '../core/arabic_text.dart';
import '../core/money.dart';
import 'models.dart';
import 'parsing/repository_catalogue.dart';
import 'photo_reading.dart';
import 'product_catalog.dart';
import 'spending_repository.dart';

/// Where «امسح واعرف» found what it shows about a scanned code.
enum ScanSource {
  mine('منتجاتي'),
  catalogue('الدليل'),
  openFoodFacts('Open Food Facts'),
  webSearch('بحث أونلاين'),
  photo('صورة المنتج'),
  unknown('مش معروف');

  const ScanSource(this.labelAr);

  final String labelAr;
}

/// A product as an online source or a photo of its pack describes it.
/// Money is integer piastres; [pricePiastres] is null when no price was
/// given.
class ProductInfo {
  const ProductInfo({
    this.nameAr = '',
    this.nameEn = '',
    this.brand = '',
    this.size = '',
    this.pricePiastres,
    this.priceSource,
  });

  final String nameAr;
  final String nameEn;
  final String brand;
  final String size;
  final int? pricePiastres;
  final String? priceSource;

  /// The Arabic name when there is one, else the English one.
  String get displayName => nameAr.isNotEmpty ? nameAr : nameEn;
}

/// Gemini's help for «امسح واعرف»: a web search for a barcode and a
/// reading of a photo of the pack. Behind an interface so the flow is
/// tested without the network.
abstract class OnlineProductReader {
  /// Whether [search] may reach the network: the switches are on and a
  /// key is saved.
  Future<bool> canSearch();

  /// The product sold in Egypt under [code], or null.
  Future<ProductInfo?> search(String code);

  /// Whether [readPhoto] may reach the network.
  Future<bool> canReadPhoto();

  /// The product on the pack in [jpeg], or null.
  Future<ProductInfo?> readPhoto(Uint8List jpeg);
}

/// What «امسح واعرف» knows about one scanned [code]: a suggestion the
/// user confirms, never something already written.
class ScanFinding {
  const ScanFinding({
    required this.code,
    required this.source,
    this.name = '',
    this.nameEn = '',
    this.brand = '',
    this.size = '',
    this.pricePiastres,
    this.priceIsEstimate = false,
    this.priceNote,
    this.categoryKey,
    this.subcategoryKey,
    this.item,
    this.product,
  });

  /// The digits as the scanner read them.
  final String code;
  final ScanSource source;
  final String name;
  final String nameEn;
  final String brand;
  final String size;
  final int? pricePiastres;

  /// True for a price the user has not paid: a catalogue's typical price
  /// or one found online. It is shown for the user to confirm.
  final bool priceIsEstimate;

  /// Where an estimated price comes from ("Carrefour", "seoudi").
  final String? priceNote;
  final String? categoryKey;
  final String? subcategoryKey;

  /// The user's own product this finding updates when saved, if any.
  final QuickPickItem? item;

  /// The catalogue product it came from, if any; its category is created
  /// from the catalogue's additions only when the finding is saved.
  final CatalogueProduct? product;
}

/// Looks [code] up for «امسح واعرف», in order: the user's own products
/// (منتجاتي), the bundled [catalog] (الدليل), Open Food Facts through
/// [lookupName] and a web search through [searchOnline] (each given only
/// when its switch is on). A lookup that fails is skipped. Nothing is
/// written: a catalogue category is not created until the user saves.
Future<ScanFinding> checkBarcode(
  String code, {
  required SpendingRepository repository,
  ProductCatalog? catalog,
  Future<String?> Function(String code)? lookupName,
  Future<ProductInfo?> Function(String code)? searchOnline,
}) async {
  final item = await repository.itemByBarcode(code);
  if (item != null) {
    return ScanFinding(
      code: code,
      source: ScanSource.mine,
      name: item.nameAr,
      pricePiastres: item.suggestedAmountPiastres,
      categoryKey: item.categoryKey,
      subcategoryKey: item.subcategoryKey,
      item: item,
      product: catalog?.byBarcode(code),
      brand: catalog?.byBarcode(code)?.brand ?? '',
      size: catalog?.byBarcode(code)?.size ?? '',
    );
  }
  if (catalog?.byBarcode(code) case final product?) {
    return _fromCatalogue(code, product, ScanSource.catalogue);
  }
  final name = await _quietly(() => lookupName?.call(code));
  if (name != null && name.trim().isNotEmpty) {
    return ScanFinding(
      code: code,
      source: ScanSource.openFoodFacts,
      name: name.trim(),
    );
  }
  final info = await _quietly(() => searchOnline?.call(code));
  if (info != null && info.displayName.isNotEmpty) {
    return _fromInfo(code, info, ScanSource.webSearch);
  }
  return ScanFinding(code: code, source: ScanSource.unknown);
}

/// What a photo of the pack says about [current]'s product, or null when
/// it says nothing.
///
/// [online] is Gemini's reading of the photo, when it is on, and wins.
/// Otherwise the offline recogniser's Latin [ocrText] is matched against
/// the user's own products, then against the catalogue's English names and
/// brands, and failing both its Latin words become the name to confirm.
Future<ScanFinding?> readProductPhoto(
  ScanFinding current, {
  required SpendingRepository repository,
  ProductCatalog? catalog,
  String ocrText = '',
  ProductInfo? online,
}) async {
  final code = current.code;
  if (online != null && online.displayName.isNotEmpty) {
    return _fromInfo(code, online, ScanSource.photo);
  }
  final words = readPhotoText(ocrText, now: DateTime(9999)).words;
  if (words.isEmpty) return null;

  final parser = await loadParserCatalogue(repository);
  for (final word in words) {
    final match = parser.match(word);
    final id = match.itemId;
    if (id == null || match.fuzzy) continue;
    final item = (await repository.allItems())
        .where((i) => i.id == id)
        .firstOrNull;
    if (item == null) continue;
    return ScanFinding(
      code: code,
      source: ScanSource.photo,
      name: item.nameAr,
      pricePiastres: item.suggestedAmountPiastres,
      categoryKey: item.categoryKey,
      subcategoryKey: item.subcategoryKey,
      // An item with no code of its own learns this one when saved.
      item: item.barcode == null ? item : null,
    );
  }

  if (catalog != null && !catalog.isEmpty) {
    CatalogueProduct? best;
    var bestScore = 0;
    for (final product in catalog.products) {
      final tokens = {
        ..._tokens(product.nameEn),
        ..._tokens(product.brand),
      };
      final score = words.toSet().where(tokens.contains).length;
      if (score > bestScore) {
        best = product;
        bestScore = score;
      }
    }
    if (best != null) return _fromCatalogue(code, best, ScanSource.photo);
  }

  final kept = words.toSet();
  final latin = [
    for (final m in RegExp('[A-Za-z]{3,}').allMatches(ocrText))
      if (kept.contains(m.group(0)!.toLowerCase())) m.group(0)!,
  ];
  return ScanFinding(
    code: code,
    source: ScanSource.photo,
    name: latin.take(4).join(' '),
  );
}

Set<String> _tokens(String text) => {
      for (final m in RegExp('[a-z]{3,}').allMatches(normalizeArabic(text)))
        m.group(0)!,
    };

ScanFinding _fromCatalogue(
        String code, CatalogueProduct product, ScanSource source) =>
    ScanFinding(
      code: code,
      source: source,
      name: product.nameAr,
      nameEn: product.nameEn,
      brand: product.brand,
      size: product.size,
      pricePiastres: product.pricePiastres,
      priceIsEstimate: product.pricePiastres != null,
      priceNote: product.priceSource,
      categoryKey: product.categoryKey,
      subcategoryKey: product.subcategoryKey,
      product: product,
    );

ScanFinding _fromInfo(String code, ProductInfo info, ScanSource source) =>
    ScanFinding(
      code: code,
      source: source,
      name: info.displayName,
      nameEn: info.nameAr.isEmpty ? '' : info.nameEn,
      brand: info.brand,
      size: info.size,
      pricePiastres: info.pricePiastres,
      priceIsEstimate: info.pricePiastres != null,
      priceNote: info.priceSource,
    );

Future<T?> _quietly<T>(Future<T?>? Function() call) async {
  try {
    return await call();
  } catch (_) {
    // A lookup only saves typing; the next one, or the user, fills in.
    return null;
  }
}

/// The product in a web search or photo answer: the first JSON object in
/// [text] that names one, found in plain JSON, in a code fence or inside
/// prose (a grounded answer cannot be forced into a schema). Null when no
/// object parses, `found` is false, or neither name is given.
ProductInfo? readProductAnswer(String text) {
  for (final object in _jsonObjects(text)) {
    if (object['found'] == false) return null;
    String field(List<String> keys) {
      for (final key in keys) {
        final value = object[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    final info = ProductInfo(
      nameAr: field(['nameAr', 'name_ar']),
      nameEn: field(['nameEn', 'name_en', 'name']),
      brand: field(['brand']),
      size: field(['size', 'quantity']),
      pricePiastres: _price(object['priceEgp'] ?? object['price']),
      priceSource: switch (field(['priceSource', 'source'])) {
        '' => null,
        final s => s,
      },
    );
    if (info.displayName.isNotEmpty) return info;
    return null;
  }
  return null;
}

/// A price given as a number or as text with a currency around it
/// ("EGP 12,50", "25.5 جنيه"); null when it is missing or not positive.
int? _price(Object? value) {
  final String text;
  if (value is num) {
    text = value.toString();
  } else if (value is String) {
    final m = RegExp(r'\d+(?:[.,]\d{1,2})?')
        .firstMatch(value.replaceAll(RegExp(r'(?<=\d),(?=\d{3}\b)'), ''));
    if (m == null) return null;
    text = m.group(0)!.replaceAll(',', '.');
  } else {
    return null;
  }
  final piastres = parsePiastres(text);
  return piastres == null || piastres <= 0 ? null : piastres;
}

/// Every balanced `{...}` in [text] that decodes to a JSON object, in
/// order. Braces inside JSON strings are skipped.
Iterable<Map<String, Object?>> _jsonObjects(String text) sync* {
  for (var start = text.indexOf('{');
      start >= 0;
      start = text.indexOf('{', start + 1)) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) {
          try {
            final decoded = jsonDecode(text.substring(start, i + 1));
            if (decoded is Map<String, Object?>) {
              yield decoded;
              start = i;
            }
          } on FormatException {
            // Not JSON (prose in braces): try the next opening brace.
          }
          break;
        }
      }
    }
  }
}
