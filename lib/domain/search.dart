import '../core/arabic_text.dart';

/// [normalizeArabic] plus digit folding: Eastern Arabic (٠-٩) and Persian
/// (۰-۹) digits become Latin ones, so "٣٠" typed on an Arabic keyboard
/// finds the "30" a receipt or the keypad stored (spec §4.3). Applied to
/// both the query and every searched field, so a match never depends on
/// which spelling either side happened to use. Pure Dart.
String normalizeForSearch(String input) {
  final out = StringBuffer();
  for (final rune in normalizeArabic(input).runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + rune - 0x06F0);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// True when every word of [query] appears in at least one of [fields]
/// (not necessarily the same one), both sides normalised with
/// [normalizeForSearch]. A blank query matches everything. Words may land
/// in different fields so "طماطم كيلو" finds an entry named طماطم whose
/// transcript says "اتنين كيلو".
bool matchesSearch(String query, Iterable<String?> fields) {
  final words = normalizeForSearch(query)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;
  final haystack = [
    for (final f in fields)
      if (f != null && f.isNotEmpty) normalizeForSearch(f),
  ];
  return words.every((w) => haystack.any((f) => f.contains(w)));
}
