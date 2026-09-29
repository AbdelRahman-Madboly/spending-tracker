import 'parsing/parsed_line.dart';
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
