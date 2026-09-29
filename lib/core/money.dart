import 'package:intl/intl.dart';

/// Formats an integer piastre amount for display.
///
/// Latin digits are used deliberately: every payment receipt this app ingests
/// renders amounts in Latin digits, and matching them avoids transcription errors.
String formatPiastres(int piastres, {bool withCurrency = false}) {
  final negative = piastres < 0;
  final abs = piastres.abs();
  final pounds = abs ~/ 100;
  final fraction = abs % 100;

  final poundsText = NumberFormat('#,##0', 'en_US').format(pounds);
  final body = fraction == 0
      ? poundsText
      : '$poundsText.${fraction.toString().padLeft(2, '0')}';

  final signed = negative ? '-$body' : body;
  return withCurrency ? '$signed ج.م' : signed;
}

/// A price per unit as the product lists show it: `25 ج.م / لتر`.
/// [unitLabel] is the Arabic label of the unit.
String formatPiastresPer(int piastres, String unitLabel) =>
    '${formatPiastres(piastres, withCurrency: true)} / $unitLabel';

/// Upper bound for a parsed amount, in piastres (1,000,000 EGP). Far above
/// any real purchase this app would ever log — rejecting anything past it
/// catches typos (an extra digit or two) rather than genuine spending.
const maxParsablePiastres = 100000000;

/// Parses a user-typed amount (Arabic-Indic or Latin digits, optional one
/// or two decimal places) into integer piastres. Returns null when the
/// input isn't a valid non-negative amount, or exceeds [maxParsablePiastres].
///
/// Parses digit-by-digit rather than through `double.parse` — money here is
/// integer piastres, and going through a float would risk exactly the
/// rounding drift that representation is meant to avoid.
int? parsePiastres(String input) {
  final normalized = _toLatinDigits(input.trim());
  if (normalized.isEmpty) return null;

  final parts = normalized.split('.');
  if (parts.length > 2) return null;

  final pounds = int.tryParse(parts[0]);
  if (pounds == null || pounds < 0) return null;

  var fraction = 0;
  if (parts.length == 2) {
    var fractionDigits = parts[1];
    if (fractionDigits.isEmpty || fractionDigits.length > 2) return null;
    if (fractionDigits.length == 1) fractionDigits = '${fractionDigits}0';
    final parsedFraction = int.tryParse(fractionDigits);
    if (parsedFraction == null) return null;
    fraction = parsedFraction;
  }

  final result = pounds * 100 + fraction;
  if (result > maxParsablePiastres) return null;
  return result;
}

const _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

String _toLatinDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final arabicIndex = _arabicIndicDigits.indexOf(char);
    buffer.write(arabicIndex == -1 ? char : arabicIndex.toString());
  }
  return buffer.toString();
}
