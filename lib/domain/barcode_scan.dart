import '../core/arabic_text.dart';
import 'models.dart';
import 'parsing/parsed_line.dart';
import 'review.dart';
import 'spending_repository.dart';

/// Counts the products passed in front of the scanner in continuous mode
/// (spec §6.3).
///
/// The camera reports a code on every frame it can read it in, many times a
/// second, so a code only counts again once it has been out of sight for
/// [gap]: holding a can in front of the camera is one can, taking it away
/// and scanning it again is two.
class BarcodeTally {
  BarcodeTally({this.gap = const Duration(milliseconds: 1500)});

  final Duration gap;
  final _codes = <String>[];
  final _lastSeen = <String, DateTime>{};

  /// Every counted code, in scan order, repeats included.
  List<String> get codes => List.unmodifiable(_codes);
  int get count => _codes.length;

  /// Notes that [code] was seen [at], and says whether it counted.
  bool add(String code, DateTime at) {
    final value = code.trim();
    if (value.isEmpty) return false;
    final last = _lastSeen[value];
    _lastSeen[value] = at;
    if (last != null && at.difference(last) < gap) return false;
    _codes.add(value);
    return true;
  }
}

/// The review lines for the codes scanned, one per code in first-scan
/// order, with a code scanned n times as n of it (spec §6.3).
///
/// - A code an item holds is that item at the price it was last bought at
///   (else its default price), in its category.
/// - Any other code is a product to name: [nameFor] (the online lookup,
///   when it is on) is asked once per code and may fill the name; the
///   amount and category are left for review.
Future<List<ParsedLine>> barcodeLines(
  List<String> codes, {
  required SpendingRepository repository,
  required DateTime day,
  Future<String?> Function(String code)? nameFor,
}) async {
  final counts = <String, int>{};
  for (final code in codes) {
    counts[code] = (counts[code] ?? 0) + 1;
  }
  final lines = <ParsedLine>[];
  for (final MapEntry(key: code, value: count) in counts.entries) {
    final quantityMilli = count * 1000;
    final item = await repository.itemByBarcode(code);
    if (item != null) {
      final price = item.suggestedAmountPiastres;
      lines.add(ParsedLine(
        rawText: code,
        date: day,
        name: item.nameAr,
        itemId: item.id,
        categoryKey: item.categoryKey,
        subcategoryKey: item.subcategoryKey,
        quantityMilli: quantityMilli,
        amountPiastres: price == null ? null : price * count,
        unitPricePiastres: count > 1 ? price : null,
        confidence: price == null ? ParseConfidence.medium : ParseConfidence.high,
        flags: {if (price == null) ParseFlag.noAmount},
        barcode: code,
      ));
      continue;
    }
    String? name;
    try {
      name = await nameFor?.call(code);
    } catch (_) {
      // The lookup only saves typing; without it the name is typed.
    }
    lines.add(ParsedLine(
      rawText: code,
      date: day,
      name: name?.trim() ?? '',
      quantityMilli: quantityMilli,
      confidence: ParseConfidence.low,
      flags: const {ParseFlag.noAmount, ParseFlag.noCategory},
      barcode: code,
    ));
  }
  return lines;
}

/// Starts a row of a barcode draft's text that holds a scanned code.
const _codeMark = '#';

/// The text a barcode capture is kept as when review closes without
/// saving (spec §6.7: closing never discards a capture).
///
/// A draft stores text, not lines, and a product not named yet has no text
/// of its own, so a scanned line is kept as its code: one `#code` row per
/// scan, the first carrying the name typed for it, which
/// [readBarcodeDraft] scans back to lines. A line with no code (one added
/// by hand) is kept as the text the parser reads back to it.
String barcodeDraftText(Iterable<ReviewLine> lines) {
  final rows = <String>[];
  for (final line in lines) {
    final code = line.barcode;
    if (code == null) {
      final text = reviewDraftText([line]);
      if (text.isNotEmpty) rows.add(text);
      continue;
    }
    final count = (line.quantityMilli + 500) ~/ 1000;
    final name = line.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    for (var i = 0; i < (count < 1 ? 1 : count); i++) {
      rows.add(i == 0 && name.isNotEmpty
          ? '$_codeMark$code $name'
          : '$_codeMark$code');
    }
  }
  return rows.join('\n');
}

/// A barcode draft's text read back: its codes scanned again through
/// [barcodeLines], so a code the app has learned since is its item at its
/// price, and the rest of the text for the parser.
///
/// A name typed for an unknown code comes back with it. When an item has
/// that name (the line was linked to it in review), the line is linked to
/// it again rather than making a second item of the same name when saved.
/// Codes are read offline: the product lookup only saves typing, and a
/// name kept with the draft is already typed. A draft kept before codes
/// were kept has no `#` rows and reads as text only.
Future<({List<ParsedLine> lines, String text})> readBarcodeDraft(
  String? rawText, {
  required SpendingRepository repository,
  required DateTime day,
}) async {
  final codes = <String>[];
  final names = <String, String>{};
  final rest = <String>[];
  for (final row in (rawText ?? '').split('\n')) {
    final trimmed = row.trim();
    if (!trimmed.startsWith(_codeMark) || trimmed.length == 1) {
      if (trimmed.isNotEmpty) rest.add(trimmed);
      continue;
    }
    final body = trimmed.substring(1);
    final space = body.indexOf(' ');
    final code = space < 0 ? body : body.substring(0, space);
    final name = space < 0 ? '' : body.substring(space + 1).trim();
    codes.add(code);
    if (name.isNotEmpty) names.putIfAbsent(code, () => name);
  }
  final text = rest.join('\n');
  if (codes.isEmpty) return (lines: const <ParsedLine>[], text: text);
  final scanned =
      await barcodeLines(codes, repository: repository, day: day);
  final items = names.isEmpty
      ? const <QuickPickItem>[]
      : await repository.allItems();
  final lines = [
    for (final line in scanned)
      switch (names[line.barcode]) {
        final name? when line.itemId == null => _named(line, name, items),
        _ => line,
      },
  ];
  return (lines: lines, text: text);
}

/// [line], an unknown code, with the [name] typed for it, and linked to
/// the item of that name when there is one.
ParsedLine _named(ParsedLine line, String name, List<QuickPickItem> items) {
  final key = normalizeArabic(name);
  final item =
      items.where((i) => normalizeArabic(i.nameAr) == key).firstOrNull;
  final price = item?.suggestedAmountPiastres;
  final count = line.quantityMilli ~/ 1000;
  return ParsedLine(
    rawText: line.rawText,
    date: line.date,
    name: item?.nameAr ?? name,
    itemId: item?.id,
    categoryKey: item?.categoryKey,
    subcategoryKey: item?.subcategoryKey,
    quantityMilli: line.quantityMilli,
    amountPiastres: price == null ? null : price * count,
    unitPricePiastres: count > 1 ? price : null,
    confidence: item == null ? ParseConfidence.low : ParseConfidence.medium,
    flags: {
      if (item == null || price == null) ParseFlag.noAmount,
      if (item == null) ParseFlag.noCategory,
    },
    barcode: line.barcode,
  );
}
