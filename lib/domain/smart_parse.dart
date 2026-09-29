import 'dart:convert';
import 'dart:typed_data';

import '../core/money.dart';
import '../core/quantity.dart';
import 'models.dart';
import 'parsing/parsed_line.dart';
import 'spending_repository.dart';

/// What a smart request reads (spec §6.6): a transcript or note, photos of
/// a receipt or product, or a voice note's audio.
enum SmartInputKind { text, photo, audio }

/// One smart request's input. Exactly one of [text], [images] or [audio]
/// is set, matching [kind].
class SmartInput {
  final SmartInputKind kind;
  final String? text;

  /// JPEG bytes, one per photo.
  final List<Uint8List> images;

  /// AAC-LC `.m4a` bytes.
  final Uint8List? audio;

  const SmartInput.text(String this.text)
      : kind = SmartInputKind.text,
        images = const [],
        audio = null;

  const SmartInput.photos(this.images)
      : kind = SmartInputKind.photo,
        text = null,
        audio = null;

  const SmartInput.audio(Uint8List this.audio)
      : kind = SmartInputKind.audio,
        text = null,
        images = const [];
}

/// What a smart request gave back: the rewrite, the date it found (if
/// any) and the lines, ready for the review sheet.
class SmartResult {
  final String cleanText;
  final DateTime? date;
  final List<ParsedLine> lines;

  const SmartResult(
      {required this.cleanText, this.date, required this.lines});
}

/// The smart path as the review sheet sees it. The one implementation
/// talks to Gemini through the network gate; tests give their own.
abstract class SmartImprover {
  /// The inputs that may be sent right now: none unless online features
  /// and the input's own switch are on and a key is saved. Never throws.
  Future<Set<SmartInputKind>> available();

  /// The smart reading of [input], or null on any failure (switched off,
  /// offline, a 4xx/5xx, a timeout, an answer that does not match the
  /// schema). The caller keeps the local result either way.
  Future<SmartResult?> improve(SmartInput input, {required DateTime day});
}

/// The catalogue a smart request may map lines to: the live categories
/// and subcategories and the most used items.
class SmartCatalogue {
  final List<CategoryView> categories;
  final List<SubcategoryView> subcategories;

  /// At most [maxItems], most used first.
  final List<QuickPickItem> items;

  const SmartCatalogue({
    required this.categories,
    required this.subcategories,
    required this.items,
  });

  /// Spec §6.6: the prompt carries the top 200 item names with their ids.
  static const maxItems = 200;
}

Future<SmartCatalogue> loadSmartCatalogue(SpendingRepository repo) async {
  final categories = await repo.categories();
  return SmartCatalogue(
    categories: categories,
    subcategories: [
      for (final c in categories) ...await repo.subcategories(c.key),
    ],
    items: await repo.topItems(SmartCatalogue.maxItems),
  );
}

/// The unit keys the answer may use; `none` is a plain count.
const _noUnit = 'none';
List<String> get _unitKeys => [_noUnit, ...entryUnitLabels.keys];

/// The `responseJsonSchema` of spec §6.6. Keys are enums of what exists,
/// so the answer cannot name a category the app does not have. Money and
/// quantities are decimal strings, read with [parsePiastres] and
/// [parseQuantityMilli], never as floating point.
///
/// An enum must not be empty, so `subcategoryKey` and `itemId` are left
/// out when there is nothing to pick from.
Map<String, Object?> smartResponseSchema(SmartCatalogue catalogue) {
  const string = {'type': 'string'};
  return {
    'type': 'object',
    'properties': {
      'date': {
        'type': 'string',
        'description': 'YYYY-MM-DD, only when the input states the date',
      },
      'cleanText': string,
      'lines': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': string,
            'quantity': string,
            'unit': {'type': 'string', 'enum': _unitKeys},
            'amount': string,
            'unitPrice': string,
            'categoryKey': {
              'type': 'string',
              'enum': [for (final c in catalogue.categories) c.key],
            },
            if (catalogue.subcategories.isNotEmpty)
              'subcategoryKey': {
                'type': 'string',
                'enum': [for (final s in catalogue.subcategories) s.key],
              },
            if (catalogue.items.isNotEmpty)
              'itemId': {
                'type': 'string',
                'enum': [for (final i in catalogue.items) i.id],
              },
          },
          'required': ['name', 'quantity', 'unit', 'amount', 'categoryKey'],
        },
      },
    },
    'required': ['cleanText', 'lines'],
  };
}

/// The instruction sent with every input. It is written for the model,
/// not shown to the user, so it is plain English; the names it asks for
/// are Egyptian Arabic.
String smartPrompt(SmartCatalogue catalogue, SmartInputKind kind) {
  final source = switch (kind) {
    SmartInputKind.text => 'The input is a spoken or typed shopping note.',
    SmartInputKind.photo =>
      'The input is one or more photos of a receipt, a payment screenshot '
          'or product packaging.',
    SmartInputKind.audio =>
      'The input is a voice note in Egyptian Arabic listing purchases.',
  };
  return [
    'You turn Egyptian household spending notes into expense lines.',
    source,
    'Write each line with a clean Egyptian Arabic item name. Do not invent '
        'items: return only what the input states.',
    'amount is the line total in Egyptian pounds as a decimal string, or an '
        'empty string when the input gives no price. unitPrice is the price '
        'of one unit when stated. quantity is a decimal string, 1 when not '
        'stated. Use unit "none" for a plain count.',
    'Give itemId only when the line is that catalogue item. Pick the '
        'categoryKey (and subcategoryKey when one fits) from the lists below.',
    'cleanText is the input rewritten as clean Egyptian Arabic, one item per '
        'line, as: name quantity unit ب amount.',
    'Give date (YYYY-MM-DD) only when the input states the date.',
    '',
    'Categories:',
    for (final c in catalogue.categories) '${c.key}: ${c.labelAr}',
    '',
    'Subcategories:',
    for (final s in catalogue.subcategories)
      '${s.key} (${s.categoryKey}): ${s.labelAr}',
    '',
    'Items:',
    for (final i in catalogue.items) '${i.id}: ${i.nameAr}',
  ].join('\n');
}

/// Reads the model's JSON answer into lines for the review sheet, or null
/// when it does not match [smartResponseSchema] (spec §6.6: a schema
/// mismatch falls back to the local result).
///
/// Lenient only where the answer is still sound: an item id not in the
/// catalogue is dropped, and a subcategory of another category is
/// cleared. A line linked to an item takes that item's category, as a
/// local catalogue match does. A date after [day], or one that is not a
/// real `YYYY-MM-DD`, is ignored and the lines keep [day].
SmartResult? readSmartResult(String answer, SmartCatalogue catalogue,
    {required DateTime day}) {
  final Object? body;
  try {
    body = jsonDecode(answer);
  } on FormatException {
    return null;
  }
  if (body is! Map) return null;
  final cleanText = body['cleanText'];
  final rawLines = body['lines'];
  if (cleanText is! String || rawLines is! List) return null;

  final date = _readDate(body['date'], day);
  final lineDay = date ?? day;
  final categoryKeys = {for (final c in catalogue.categories) c.key};
  final lines = <ParsedLine>[];
  for (final raw in rawLines) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final quantity = raw['quantity'];
    final unit = raw['unit'];
    final amount = raw['amount'];
    final unitPrice = raw['unitPrice'];
    var categoryKey = raw['categoryKey'];
    if (name is! String || name.trim().isEmpty) return null;
    if (quantity is! String || amount is! String || unit is! String) {
      return null;
    }
    if (unitPrice != null && unitPrice is! String) return null;
    if (categoryKey is! String || !categoryKeys.contains(categoryKey)) {
      return null;
    }
    if (!_unitKeys.contains(unit)) return null;
    final quantityMilli =
        quantity.trim().isEmpty ? 1000 : parseQuantityMilli(quantity);
    if (quantityMilli == null) return null;
    final amountPiastres =
        amount.trim().isEmpty ? null : parsePiastres(amount);
    if (amount.trim().isNotEmpty && amountPiastres == null) return null;
    final unitPricePiastres = unitPrice is String && unitPrice.trim().isNotEmpty
        ? parsePiastres(unitPrice)
        : null;

    final item = catalogue.items
        .where((i) => i.id == raw['itemId'])
        .firstOrNull;
    String? subcategoryKey;
    if (item != null) {
      categoryKey = item.categoryKey;
      subcategoryKey = item.subcategoryKey;
    } else if (catalogue.subcategories.any((s) =>
        s.key == raw['subcategoryKey'] && s.categoryKey == categoryKey)) {
      subcategoryKey = raw['subcategoryKey'] as String;
    }
    final noAmount = amountPiastres == null || amountPiastres <= 0;
    lines.add(ParsedLine(
      rawText: name.trim(),
      date: lineDay,
      name: name.trim(),
      itemId: item?.id,
      categoryKey: categoryKey,
      subcategoryKey: subcategoryKey,
      quantityMilli: quantityMilli,
      unit: unit == _noUnit ? null : unit,
      amountPiastres: noAmount ? null : amountPiastres,
      unitPricePiastres: unitPricePiastres,
      confidence: noAmount ? ParseConfidence.low : ParseConfidence.medium,
      flags: {
        if (noAmount) ParseFlag.noAmount,
        if (date != null) ParseFlag.dateFromText,
      },
    ));
  }
  return SmartResult(cleanText: cleanText, date: date, lines: lines);
}

/// A `YYYY-MM-DD` that is a real day no later than [day], or null.
DateTime? _readDate(Object? value, DateTime day) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final [y, m, d] = [for (var g = 1; g <= 3; g++) int.parse(match[g]!)];
  final date = DateTime(y, m, d);
  // DateTime rolls 2026-13-40 over into a later day; a real date does not.
  if (date.year != y || date.month != m || date.day != d) return null;
  return date.isAfter(day) ? null : date;
}
