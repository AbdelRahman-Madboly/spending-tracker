/// Folds the spelling variation Egyptian Arabic text carries in practice
/// (hamza forms, taa marbuta, alef maqsura, tatweel, diacritics, extra
/// spaces, Latin case) so that two spellings of the same word compare
/// equal. Used for learned item aliases and, later, search and the parser's
/// item matching. Pure Dart, no Flutter imports.
String normalizeArabic(String input) {
  final out = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    // Tatweel and the harakat/tanween/shadda/sukun range, plus the
    // superscript alef.
    if (rune == 0x0640 ||
        (rune >= 0x064B && rune <= 0x0652) ||
        rune == 0x0670) {
      continue;
    }
    out.writeCharCode(switch (rune) {
      0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627, // أ إ آ ٱ -> ا
      0x0629 => 0x0647, // ة -> ه
      0x0649 => 0x064A, // ى -> ي
      _ => rune,
    });
  }
  return out.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}
