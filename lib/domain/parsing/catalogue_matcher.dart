import 'dart:math' as math;

import '../../core/arabic_text.dart';
import 'parsed_line.dart';

/// A catalogue item as the parser sees it.
class CatalogueItem {
  const CatalogueItem(
    this.id,
    this.nameAr,
    this.categoryKey,
    this.subcategoryKey, {
    this.unit,
    this.unitPricePiastres,
    this.usualQuantityMilli,
  });

  final String id;
  final String nameAr;
  final String categoryKey;
  final String? subcategoryKey;

  /// Set for a product sold loose by a unit (milk by the litre): a line
  /// matching it is priced per unit at [unitPricePiastres], and at
  /// [usualQuantityMilli] when the text gave no quantity.
  final String? unit;
  final int? unitPricePiastres;
  final int? usualQuantityMilli;
}

/// A subcategory as the parser sees it: its label doubles as a keyword.
class CatalogueSubcategory {
  const CatalogueSubcategory(this.key, this.categoryKey, this.labelAr);

  final String key;
  final String categoryKey;
  final String labelAr;
}

/// What [ParserCatalogue.match] found for a name.
class CatalogueMatch {
  const CatalogueMatch({
    required this.name,
    this.itemId,
    this.categoryKey,
    this.subcategoryKey,
    required this.confidence,
    this.fuzzy = false,
    this.item,
  });

  /// The name to show: the item's spelling when the whole name matched an
  /// item, otherwise the name as written.
  final String name;
  final String? itemId;
  final String? categoryKey;
  final String? subcategoryKey;
  final ParseConfidence confidence;

  /// True when the item was found by edit distance, not spelling.
  final bool fuzzy;

  /// The matched item, when [itemId] is set.
  final CatalogueItem? item;
}

/// Everyday words that name a subcategory without being a catalogue item
/// (spec §6.5 step 8: "مواصلات → Transport, عيش/لبن → Food"). Keys are
/// [normalizeArabic] output; values are subcategory keys, used only when
/// that subcategory exists in the catalogue the parser was given. Only
/// correct spellings belong here: typos are edit distance's job, and a
/// misspelling listed as a keyword would keep the name from being corrected.
const Map<String, String> _keywords = {
  'مترو': 'PublicTransport',
  'اتوبيس': 'PublicTransport',
  'ميكروباص': 'PublicTransport',
  'مشروع': 'PublicTransport',
  'توكتوك': 'PublicTransport',
  'قطر': 'PublicTransport',
  'قطار': 'PublicTransport',
  'مواصلات': 'PublicTransport',
  'اوبر': 'Taxi',
  'كريم': 'Taxi',
  'uber': 'Taxi',
  'careem': 'Taxi',
  'عيش': 'Groceries',
  'خبز': 'Groceries',
  'طماطم': 'Groceries',
  'خيار': 'Groceries',
  'بطاطس': 'Groceries',
  'بصل': 'Groceries',
  'رز': 'Groceries',
  'سكر': 'Groceries',
  'زيت': 'Groceries',
  'جبنه': 'Groceries',
  'بيض': 'Groceries',
  'زبادي': 'Groceries',
  'فول': 'Groceries',
  'تونه': 'Groceries',
  'مكرونه': 'Groceries',
  'كاتشب': 'Groceries',
  'خضار': 'Groceries',
  'فاكهه': 'Groceries',
  'لحمه': 'Groceries',
  'فراخ': 'Groceries',
  'زيتون': 'Groceries',
  'برتقال': 'Groceries',
  'مياه': 'Water',
  'مايه': 'Water',
  'ميه': 'Water',
  'water': 'Water',
  'بيبسي': 'Soda',
  'كولا': 'Soda',
  'كوكاكولا': 'Soda',
  'فيروز': 'Soda',
  'سبرايت': 'Soda',
  'pepsi': 'Soda',
  'شاي': 'HotDrinks',
  'قهوه': 'HotDrinks',
  'نسكافيه': 'HotDrinks',
  'coffee': 'HotDrinks',
  'شيبسي': 'Chips',
  'chips': 'Chips',
  'شوكولاته': 'Chocolate',
  'شيكولاته': 'Chocolate',
  'هوهوز': 'Sweets',
  'جاتوه': 'Sweets',
  'تورته': 'Sweets',
  'فطار': 'Breakfast',
  'فطور': 'Breakfast',
  'باتيه': 'Breakfast',
  'كرواسون': 'Breakfast',
  'غدا': 'Lunch',
  'غداء': 'Lunch',
  'كشري': 'Lunch',
  'اكل': 'Lunch',
  'عشا': 'Dinner',
  'عشاء': 'Dinner',
  'زياره': 'Visits',
  'نت': 'HomeInternet',
  'انترنت': 'HomeInternet',
  'دوا': 'Medicine',
  'دواء': 'Medicine',
  'برشام': 'Medicine',
  'صيدليه': 'Medicine',
  'غسيل': 'Laundry',
  'كوي': 'Laundry',
  'مكوجي': 'Laundry',
  'مكوه': 'Laundry',
};

/// Keywords that count only as the whole name, never as one word of a
/// longer one: كريم alone is the Careem ride app, but "كريم شعر" is hair
/// cream. The Latin "careem" has no such double meaning.
const Set<String> _wholeNameOnly = {'كريم'};

/// The items, aliases and subcategories names are matched against
/// (spec §6.5 step 8).
class ParserCatalogue {
  ParserCatalogue({
    required List<CatalogueItem> items,
    required List<CatalogueSubcategory> subcategories,
    Map<String, String> aliases = const {},
  }) : _items = {for (final i in items) i.id: i},
       _subcategories = {for (final s in subcategories) s.key: s} {
    for (final item in items) {
      _byName[normalizeArabic(item.nameAr)] = item;
    }
    // Aliases are stored normalised already; normalising again is harmless
    // and lets callers pass them as typed.
    for (final MapEntry(key: alias, value: id) in aliases.entries) {
      final item = _items[id];
      if (item != null) _byName.putIfAbsent(normalizeArabic(alias), () => item);
    }
    for (final s in subcategories) {
      _keywordToSubcategory[normalizeArabic(s.labelAr)] = s;
    }
    for (final MapEntry(key: word, value: key) in _keywords.entries) {
      final s = _subcategories[key];
      if (s != null) _keywordToSubcategory.putIfAbsent(word, () => s);
    }
  }

  /// An empty catalogue: nothing matches, every line is uncategorised.
  factory ParserCatalogue.empty() =>
      ParserCatalogue(items: const [], subcategories: const []);

  final Map<String, CatalogueItem> _items;
  final Map<String, CatalogueSubcategory> _subcategories;

  /// Normalised item names and aliases to their item.
  final Map<String, CatalogueItem> _byName = {};
  final Map<String, CatalogueSubcategory> _keywordToSubcategory = {};

  /// Matches [name] in this order: the whole name exactly (an item name or
  /// a learned alias, `high`); the leading words exactly ("مواصلات
  /// القاهرة" is مواصلات with a place, `medium`, written name kept); the
  /// whole name as a keyword or subcategory label, which gives the category
  /// alone (`medium`); the whole name within the edit distance the spec
  /// allows (`medium`, and the item's spelling replaces the typo); and last
  /// any single word of the name as a keyword. Nothing found is `low`.
  ///
  /// Exact spellings go before edit distance because real product names sit
  /// one letter apart: بيبسي is its own drink, not a typo of the شيبسي item.
  CatalogueMatch match(String name) {
    final key = normalizeArabic(name);
    if (key.isEmpty) {
      return CatalogueMatch(name: name, confidence: ParseConfidence.low);
    }

    final exact = _byName[key];
    if (exact != null) return _fromItem(exact, exact.nameAr, high: true);

    final words = key.split(' ');
    for (var n = words.length - 1; n >= 1; n--) {
      final lead = _byName[words.take(n).join(' ')];
      if (lead != null) return _fromItem(lead, name, high: false);
    }

    final whole = _keywordToSubcategory[key];
    if (whole != null) return _fromKeyword(whole, name);

    final fuzzy = _closest(key);
    if (fuzzy != null) {
      return _fromItem(fuzzy, fuzzy.nameAr, high: false, fuzzy: true);
    }

    final word = words
        .where((w) => !_wholeNameOnly.contains(w))
        .map((w) => _keywordToSubcategory[w])
        .nonNulls
        .firstOrNull;
    if (word != null) return _fromKeyword(word, name);
    return CatalogueMatch(name: name, confidence: ParseConfidence.low);
  }

  CatalogueMatch _fromKeyword(CatalogueSubcategory s, String name) =>
      CatalogueMatch(
        name: name,
        categoryKey: s.categoryKey,
        subcategoryKey: s.key,
        confidence: ParseConfidence.medium,
      );

  CatalogueMatch _fromItem(
    CatalogueItem item,
    String name, {
    required bool high,
    bool fuzzy = false,
  }) => CatalogueMatch(
    name: name,
    itemId: item.id,
    categoryKey: item.categoryKey,
    subcategoryKey: item.subcategoryKey,
    confidence: high ? ParseConfidence.high : ParseConfidence.medium,
    fuzzy: fuzzy,
    item: item,
  );

  /// The nearest item name or alias within the allowed distance: one edit
  /// for a name of four letters, two for longer ones. Two limits the spec
  /// does not state keep this from guessing wildly: below four letters only
  /// an exact match counts, because three-letter words sit one edit apart
  /// too often ("جبن" cheese and "لبن" milk); and the first letter must
  /// agree, because typos almost never hit it while unrelated words two
  /// edits apart often differ there (جمعية and زيارة against مياه).
  CatalogueItem? _closest(String key) {
    final length = key.runes.length;
    if (length < 4) return null;
    final allowed = length <= 4 ? 1 : 2;
    final first = key.runes.first;
    CatalogueItem? best;
    var bestDistance = allowed + 1;
    for (final MapEntry(key: candidate, value: item) in _byName.entries) {
      if (candidate.runes.first != first) continue;
      if ((candidate.runes.length - length).abs() > allowed) continue;
      final d = levenshtein(key, candidate);
      if (d < bestDistance) {
        best = item;
        bestDistance = d;
      }
    }
    return best;
  }
}

/// Edit distance (insertions, deletions, substitutions) between [a] and
/// [b], by code point.
int levenshtein(String a, String b) {
  final s = a.runes.toList();
  final t = b.runes.toList();
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;
  var previous = List<int>.generate(t.length + 1, (i) => i);
  for (var i = 1; i <= s.length; i++) {
    final current = List<int>.filled(t.length + 1, 0)..[0] = i;
    for (var j = 1; j <= t.length; j++) {
      final cost = s[i - 1] == t[j - 1] ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    previous = current;
  }
  return previous[t.length];
}
