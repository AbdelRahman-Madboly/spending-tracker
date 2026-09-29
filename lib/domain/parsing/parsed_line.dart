import 'package:equatable/equatable.dart';

/// How far the review sheet can trust a parsed value (spec §6). `low` lines
/// are highlighted and cannot be saved with blanks.
enum ParseConfidence { low, medium, high }

/// Why a line came out the way it did, so the review sheet can say which
/// field to check.
enum ParseFlag {
  /// No price was found on the line.
  noAmount,

  /// Neither an item nor a keyword gave the line a category.
  noCategory,

  /// The numbers could be read more than one way, for example a bare
  /// count after a price ("انودي ١٢ اتنين": 12 each or 12 in all).
  ambiguousAmount,

  /// The name was corrected to a catalogue item by edit distance.
  fuzzyMatch,

  /// The date came from a `d/m` line in the text, not the capture time.
  dateFromText,

  /// An InstaPay transfer the user received (spec §6.2): money in, which
  /// the review offers to record as a salary rather than as an expense.
  incoming,

  /// An InstaPay transfer that names the user in a way that does not say
  /// which side they were on: kept as an expense, worth a look.
  maybeIncoming,

  /// A scanned product the bundled product catalogue knows (spec §6.3):
  /// its name, category and price are the catalogue's suggestion until a
  /// saved line makes it the user's own item.
  catalogue,
}

/// Unit keys (spec §6.5 step 5). Stored in English, shown in Arabic.
abstract final class ParsedUnit {
  static const kg = 'kg';
  static const gram = 'g';
  static const liter = 'liter';
  static const bag = 'bag';
  static const box = 'box';
  static const bottle = 'bottle';
  static const can = 'can';
  static const pack = 'pack';
  static const strip = 'strip';
  static const piece = 'piece';
  static const person = 'person';
}

/// One spend read out of free text (spec §6): what the parser hands to the
/// review sheet. Money is integer piastres and quantity integer milli-units,
/// like everywhere else in the app.
class ParsedLine extends Equatable {
  const ParsedLine({
    required this.rawText,
    required this.date,
    required this.name,
    this.itemId,
    this.categoryKey,
    this.subcategoryKey,
    this.quantityMilli = 1000,
    this.unit,
    this.amountPiastres,
    this.unitPricePiastres,
    required this.confidence,
    this.flags = const {},
    this.reference,
    this.barcode,
  });

  /// The text this line was read from, as written, for display.
  final String rawText;

  /// The day the spend belongs to (local midnight).
  final DateTime date;

  /// The cleaned name: the catalogue spelling when an item matched the
  /// whole name, otherwise what was left once numbers, units, prices and
  /// currency words were taken out.
  final String name;
  final String? itemId;
  final String? categoryKey;
  final String? subcategoryKey;
  final int quantityMilli;

  /// One of [ParsedUnit], or null for a plain count.
  final String? unit;

  /// The line total. Null when the text gave no price.
  final int? amountPiastres;
  final int? unitPricePiastres;
  final ParseConfidence confidence;
  final Set<ParseFlag> flags;

  /// A payment reference the capture carried (an InstaPay transaction
  /// number read off a screenshot). Text never has one.
  final String? reference;

  /// The barcode the line was scanned from (spec §6.3). Text never has one.
  final String? barcode;

  @override
  List<Object?> get props => [
    rawText,
    date,
    name,
    itemId,
    categoryKey,
    subcategoryKey,
    quantityMilli,
    unit,
    amountPiastres,
    unitPricePiastres,
    confidence,
    flags,
    reference,
    barcode,
  ];

  @override
  String toString() =>
      'ParsedLine($name, amount: $amountPiastres, '
      'qty: $quantityMilli $unit, unitPrice: $unitPricePiastres, '
      '$categoryKey/$subcategoryKey, item: $itemId, $confidence, $flags, '
      '$date)';
}
