// Quantities are integer milli-units (`1500` is 1.5 كيلو), never doubles,
// for the same reason money is integer piastres: a typed "1.1" must come
// back as exactly 1.1.

const _easternDigits = '٠١٢٣٤٥٦٧٨٩';

/// Parses a typed quantity (Latin or Eastern Arabic digits, `.` or the
/// Arabic decimal comma, up to three decimals) into milli-units. Null for
/// anything empty, malformed, zero or negative.
int? parseQuantityMilli(String input) {
  final text = StringBuffer();
  for (final char in input.trim().split('')) {
    final eastern = _easternDigits.indexOf(char);
    text.write(eastern >= 0 ? '$eastern' : (char == '٫' ? '.' : char));
  }
  final parts = text.toString().split('.');
  if (parts.length > 2 || parts.first.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(parts.first)) return null;
  var fraction = parts.length == 2 ? parts[1] : '';
  if (fraction.length > 3 ||
      (fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction))) {
    return null;
  }
  fraction = fraction.padRight(3, '0');
  final value = int.parse(parts.first) * 1000 + int.parse(fraction);
  return value > 0 ? value : null;
}

/// Milli-units back to the shortest decimal: `1500` is `1.5`.
String formatQuantityMilli(int milli) {
  final whole = milli ~/ 1000;
  final fraction = (milli % 1000).toString().padLeft(3, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
}
