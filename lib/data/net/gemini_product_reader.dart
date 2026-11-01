import 'dart:convert';
import 'dart:typed_data';

import '../../domain/gemini_usage.dart';
import '../../domain/online_features.dart';
import '../../domain/scan_check.dart';
import '../../domain/spending_repository.dart';
import 'gemini_client.dart';

/// «امسح واعرف»'s online help through [GeminiClient], and so through the
/// network gate: a barcode searched on the web with Google Search
/// grounding ([OnlineFeature.productWebSearch], which also needs
/// [OnlineFeature.gemini] on), and a photo of the pack read by Gemini
/// vision ([OnlineFeature.gemini]).
///
/// A grounded answer cannot be held to a response schema on every model,
/// so the prompt asks for a small JSON object and [readProductAnswer]
/// finds it in whatever text comes back. Every failure is null: the scan
/// goes on to the photo or the typed name. Requests are counted in the
/// Gemini usage under [GeminiUsageFeature.product].
class GeminiProductReader implements OnlineProductReader {
  GeminiProductReader(this._gemini);

  final GeminiClient _gemini;

  SpendingRepository get _repository => _gemini.repository;

  /// Only a product number is ever put into a prompt: EAN-8 to GTIN-14.
  static final _productCode = RegExp(r'^\d{6,14}$');

  Future<bool> _on(OnlineFeature feature) async {
    try {
      return await isOnlineFeatureOn(_repository, feature);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canSearch() async =>
      await _on(OnlineFeature.gemini) &&
      await _on(OnlineFeature.productWebSearch) &&
      await _gemini.hasKey();

  @override
  Future<bool> canReadPhoto() async =>
      await _on(OnlineFeature.gemini) && await _gemini.hasKey();

  @override
  Future<ProductInfo?> search(String code) async {
    final value = code.trim();
    if (!_productCode.hasMatch(value)) return null;
    if (!await _on(OnlineFeature.gemini)) return null;
    return _gemini.generate(
      feature: OnlineFeature.productWebSearch,
      usage: GeminiUsageFeature.product,
      parts: [
        {'text': searchPrompt(value)},
      ],
      tools: const [
        {'google_search': <String, Object?>{}},
      ],
      read: readProductAnswer,
    );
  }

  @override
  Future<ProductInfo?> readPhoto(Uint8List jpeg) async {
    if (jpeg.isEmpty) return null;
    return _gemini.generate(
      feature: OnlineFeature.gemini,
      usage: GeminiUsageFeature.product,
      parts: [
        {'text': photoPrompt},
        {
          'inline_data': {'mime_type': 'image/jpeg', 'data': base64Encode(jpeg)},
        },
      ],
      generationConfig: const {'responseMimeType': 'application/json'},
      read: readProductAnswer,
    );
  }

  /// The web search's question for [code].
  static String searchPrompt(String code) =>
      'Search the web for the retail product with barcode (EAN/UPC) $code '
      'as sold in Egypt. Reply with one JSON object and nothing else: '
      '{"found": true, "nameAr": "the product name in Arabic as Egyptian '
      'shops write it", "nameEn": "the English name", "brand": "", '
      '"size": "pack size, e.g. 400 g", "priceEgp": typical current shelf '
      'price in Egypt in EGP as a number, or null when no price is found, '
      '"priceSource": "the shop or site the price is from"}. '
      'If this exact barcode cannot be found, reply {"found": false}. '
      'Never describe a product with a different barcode.';

  static const photoPrompt =
      'This is a photo of a product pack sold in Egypt. Read the product '
      'from the pack. Reply with one JSON object and nothing else: '
      '{"found": true, "nameAr": "the product name in Arabic as Egyptian '
      'shops would write it, even when the pack shows only English", '
      '"nameEn": "the English name", "brand": "", "size": "pack size, e.g. '
      '400 g"}. Do not give a price. If no product can be read, reply '
      '{"found": false}.';
}
