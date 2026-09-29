import '../../core/arabic_text.dart';
import 'catalogue_matcher.dart';
import 'number_words.dart';
import 'parsed_line.dart';

/// The local Arabic parser (spec §6.5): turns a typed, transcribed or
/// shared note into [ParsedLine]s for the review sheet. Pure Dart, no
/// network, no Flutter.
///
/// A line is read in three passes. [_tokens] turns the working copy into
/// classified tokens (numbers, units, price markers, currency, each-price
/// markers, names). [_combine] attaches halves and fractions and ties counts
/// to their units. [_resolve] decides which number is the price, which the
/// quantity and which a unit price, then the leftover words become the
/// name and are matched against the catalogue.
class ArabicLineParser {
  ArabicLineParser(this.catalogue);

  final ParserCatalogue catalogue;

  /// Parses [text], captured at [capturedAt]. Lines are dated with the
  /// capture day (see [captureDay]) until a `d/m` line changes it.
  List<ParsedLine> parse(String text, {required DateTime capturedAt}) {
    final day = captureDay(capturedAt);
    var date = day;
    var dateFromText = false;
    final out = <ParsedLine>[];
    for (final rawLine in text.split(RegExp(r'\r\n|\r|\n'))) {
      final datedLine = _dateLine(_working(rawLine).trim(), day);
      if (datedLine != null) {
        date = datedLine;
        dateFromText = true;
        continue;
      }
      for (final piece in rawLine.split(_separators)) {
        final raw = piece.trim();
        if (raw.isEmpty) continue;
        for (final segment in _splitOnWa(raw)) {
          out.add(_line(segment, date, dateFromText));
        }
      }
    }
    return out;
  }

  /// The day a note belongs to: its capture date, except that anything
  /// written before 05:00 still belongs to the evening before.
  static DateTime captureDay(DateTime capturedAt) {
    final d = DateTime(capturedAt.year, capturedAt.month, capturedAt.day);
    return capturedAt.hour < 5 ? DateTime(d.year, d.month, d.day - 1) : d;
  }

  ParsedLine _line(_Segment segment, DateTime date, bool dateFromText) {
    final r = _resolve(segment.tokens);
    final match = catalogue.match(r.name);
    final flags = <ParseFlag>{...r.flags};
    if (dateFromText) flags.add(ParseFlag.dateFromText);
    if (match.fuzzy) flags.add(ParseFlag.fuzzyMatch);
    if (r.amountPiastres == null) flags.add(ParseFlag.noAmount);
    if (match.categoryKey == null) flags.add(ParseFlag.noCategory);
    final weak =
        flags.contains(ParseFlag.noAmount) ||
        flags.contains(ParseFlag.noCategory) ||
        flags.contains(ParseFlag.ambiguousAmount);
    return ParsedLine(
      rawText: segment.raw,
      date: date,
      name: match.name,
      itemId: match.itemId,
      categoryKey: match.categoryKey,
      subcategoryKey: match.subcategoryKey,
      quantityMilli: r.quantityMilli,
      unit: r.unit,
      amountPiastres: r.amountPiastres,
      unitPricePiastres: r.unitPricePiastres,
      confidence: weak ? ParseConfidence.low : match.confidence,
      flags: flags,
    );
  }

  /// Splits one comma/newline piece on a standalone و or وكمان, but only
  /// where the text before and the text after both carry an amount: "طماطم
  /// ب 30 و عيش ب 10" is two items, "غسيل و كوي جاكيت ٥٠" one. A و inside a
  /// number phrase never gets here, because [_tokens] has already folded
  /// "خمسة و عشرين" into one number.
  List<_Segment> _splitOnWa(String raw) {
    final rawWords = raw.split(RegExp(r'\s+'));
    final tokens = _combine(_tokens(rawWords));
    final pieces = <List<_Token>>[[]];
    for (final t in tokens) {
      if (t.kind == _Kind.conj) {
        pieces.add([t]);
      } else {
        pieces.last.add(t);
      }
    }
    if (pieces.length == 1) return [_Segment(raw, tokens)];

    bool hasAmount(List<_Token> ts) =>
        _resolve(
          ts.where((t) => t.kind != _Kind.conj).toList(),
        ).amountPiastres !=
        null;

    final merged = <List<_Token>>[pieces.first];
    for (final piece in pieces.skip(1)) {
      final body = piece.skip(1).toList();
      if (hasAmount(merged.last) && hasAmount(body)) {
        merged.add(body);
      } else {
        merged.last.addAll(piece);
      }
    }
    if (merged.length == 1) return [_Segment(raw, tokens)];
    return [
      for (final ts in merged)
        if (ts.isNotEmpty)
          _Segment(
            rawWords.sublist(ts.first.rawIndex, ts.last.rawIndex + 1).join(' '),
            ts,
          ),
    ];
  }
}

/// Newline is handled first; these split a line further. A comma between
/// two digits is a thousands separator ("1,500") and stays.
final _separators = RegExp(r'[،+]|(?<![0-9٠-٩]),|,(?![0-9٠-٩])');

/// A `d/m`, `d/m/yy` or `d/m/yyyy` line (spec §6.5 step 2), or null. Without
/// a year the date takes the capture year, unless that puts it more than
/// half a year after [day]: "30/12" written on 2 January is last December.
DateTime? _dateLine(String working, DateTime day) {
  final m = RegExp(
    r'^(\d{1,2})\s*/\s*(\d{1,2})(?:\s*/\s*(\d{2}|\d{4}))?$',
  ).firstMatch(working);
  if (m == null) return null;
  final d = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final y = m.group(3);
  var year = y == null
      ? day.year
      : (y.length == 2 ? 2000 + int.parse(y) : int.parse(y));
  var date = DateTime(year, mo, d);
  if (date.day != d || date.month != mo) return null; // 31/2, 32/13
  if (y == null && date.difference(day).inDays > 183) {
    year -= 1;
    date = DateTime(year, mo, d);
  }
  return date;
}

/// The working copy of some text (spec §6.5 step 1): Eastern digits to
/// Latin, ٫ to `.`, tatweel and diacritics removed. Letters keep their
/// written form so the name reads as typed; comparisons go through
/// [normalizeArabic].
String _working(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune == 0x066B) {
      out.write('.');
    } else if (rune == 0x0640 ||
        (rune >= 0x064B && rune <= 0x0652) ||
        rune == 0x0670) {
      continue;
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

enum _Kind {
  number,
  word,
  unit,
  marker, // ب
  currency, // جنيه, ج, LE, EGP
  piastre, // قرش
  each, // الواحدة, كل واحد
  perKilo, // الكيلو
  fraction, // نص, ربع, تلت
  half, // ونص, و نص, وربع
  conj, // و, وكمان
  date, // 27/9 inside a line, or a d/m line that is no real day
}

class _Token {
  _Token(
    this.kind,
    this.text,
    this.rawIndex, {
    this.milli,
    this.unit,
    this.plural = false,
    this.fromWords = false,
  });

  final _Kind kind;

  /// The working-copy text, used for the name.
  final String text;

  /// Which whitespace-separated word of the raw line this came from.
  final int rawIndex;

  /// For numbers, halves and fractions: the value in milli-units. For
  /// units: the count, when the unit carries one (dual forms, or a count
  /// attached by [_combine]).
  int? milli;
  final String? unit;
  final bool plural;

  /// A number read from words ("اتنين"), not digits.
  final bool fromWords;

  /// A unit whose count was stated rather than assumed.
  bool counted = false;

  /// Taken as a count, price or unit price, so not a name word.
  bool used = false;

  bool get isNumber => kind == _Kind.number;
}

class _Segment {
  _Segment(this.raw, this.tokens);

  final String raw;
  final List<_Token> tokens;
}

/// Unit words (spec §6.5 step 5): normalised form to unit key, count for
/// dual forms (milli-units), and whether the word is plural (which makes a
/// preceding تلت mean three rather than a third).
const Map<String, (String, int?, bool)> _units = {
  'ك': (ParsedUnit.kg, null, false),
  'كيلو': (ParsedUnit.kg, null, false),
  'كجم': (ParsedUnit.kg, null, false),
  'كغ': (ParsedUnit.kg, null, false),
  'kg': (ParsedUnit.kg, null, false),
  'كيلوين': (ParsedUnit.kg, 2000, false),
  'كيس': (ParsedUnit.bag, null, false),
  'اكياس': (ParsedUnit.bag, null, true),
  'كيسين': (ParsedUnit.bag, 2000, false),
  'علبه': (ParsedUnit.box, null, false),
  'علب': (ParsedUnit.box, null, true),
  'علبتين': (ParsedUnit.box, 2000, false),
  'ازازه': (ParsedUnit.bottle, null, false),
  'زجاجه': (ParsedUnit.bottle, null, false),
  'ازايز': (ParsedUnit.bottle, null, true),
  'زجاجات': (ParsedUnit.bottle, null, true),
  'ازازتين': (ParsedUnit.bottle, 2000, false),
  'زجاجتين': (ParsedUnit.bottle, 2000, false),
  'كانز': (ParsedUnit.can, null, false),
  'كانزين': (ParsedUnit.can, 2000, false),
  'باكو': (ParsedUnit.pack, null, false),
  'بواكي': (ParsedUnit.pack, null, true),
  'باكوين': (ParsedUnit.pack, 2000, false),
  'شريط': (ParsedUnit.strip, null, false),
  'شرايط': (ParsedUnit.strip, null, true),
  'شريطين': (ParsedUnit.strip, 2000, false),
  'حته': (ParsedUnit.piece, null, false),
  'قطعه': (ParsedUnit.piece, null, false),
  'حتت': (ParsedUnit.piece, null, true),
  'قطع': (ParsedUnit.piece, null, true),
  'حتتين': (ParsedUnit.piece, 2000, false),
  'قطعتين': (ParsedUnit.piece, 2000, false),
  'شخص': (ParsedUnit.person, null, false),
  'فرد': (ParsedUnit.person, null, false),
  'اشخاص': (ParsedUnit.person, null, true),
  'افراد': (ParsedUnit.person, null, true),
  'شخصين': (ParsedUnit.person, 2000, false),
  'فردين': (ParsedUnit.person, 2000, false),
};

const _currency = {
  'جنيه',
  'جنيهات',
  'جنيها',
  'ج',
  'ج.م',
  'جم',
  'le',
  'egp',
  'pound',
  'pounds',
};
const _latinCurrency = {'le', 'egp'};
const _piastre = {'قرش', 'قروش'};
const _each = {'الواحد', 'الواحده', 'للواحد', 'للواحده', 'each'};

/// Fractions before a unit. تلت is 333 before a singular unit and 3000
/// before a plural one ("تلت كيلو" is a third of a kilo, "تلت اكياس" three
/// bags), which is resolved in [_combine].
const _fractions = {'نص': 500, 'نصف': 500, 'ربع': 250, 'تلت': 333, 'ثلث': 333};
const _halves = {'نص': 500, 'نصف': 500, 'ربع': 250};

/// The few number words that are also everyday nouns: مية is water as
/// often as a hundred ("ازازتين مية"), ميت is also "dead".
const _ambiguousNumbers = {'ميه', 'مايه', 'ميت'};

final _digits = RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$|^\d+(\.\d+)?$');

/// Pass 1: classify every word of the working copy.
List<_Token> _tokens(List<String> rawWords) {
  // Working words, each remembering the raw word it came from. Digits
  // glued to letters ("ب٤٠", "30ج") are pulled apart first.
  final words = <(String, int)>[];
  for (var r = 0; r < rawWords.length; r++) {
    final w = _working(rawWords[r]).replaceAllMapped(
      RegExp(r'(?<=[0-9])(?=[^0-9.,])|(?<=[^0-9.,])(?=[0-9])'),
      (_) => ' ',
    );
    for (final part in w.split(' ')) {
      if (part.isNotEmpty) words.add((part, r));
    }
  }
  final keys = [for (final (w, _) in words) normalizeArabic(w)];
  final texts = [for (final (w, _) in words) w];

  final out = <_Token>[];
  var i = 0;
  while (i < words.length) {
    final key = keys[i];
    final text = texts[i];
    final raw = words[i].$2;
    final next = i + 1 < keys.length ? keys[i + 1] : null;

    // Each-price markers come before number words: "كل واحدة" is not one.
    if (_each.contains(key)) {
      out.add(_Token(_Kind.each, text, raw));
      i++;
      continue;
    }
    if (key == 'كل' && (next == 'واحد' || next == 'واحده')) {
      out.add(_Token(_Kind.each, '$text ${texts[i + 1]}', raw));
      i += 2;
      continue;
    }
    if (key == 'الكيلو') {
      out.add(_Token(_Kind.perKilo, text, raw));
      i++;
      continue;
    }

    // "٢٧/٩" inside a line, or a whole line like "31/9" that failed the
    // calendar check in [_dateLine]: a date, never two numbers and a name
    // word "/". The digit split above has already set the slash apart.
    final date = _dateAt(keys, i);
    if (date > 0) {
      out.add(_Token(_Kind.date, texts.sublist(i, i + date).join(), raw));
      i += date;
      continue;
    }

    final read = readNumberWords(texts, i);
    if (read != null) {
      final previous = out.isEmpty ? null : out.last.kind;
      final lone = read.length == 1 && _ambiguousNumbers.contains(key);
      final priced =
          previous == _Kind.marker ||
          (next != null &&
              (_currency.contains(next) || _piastre.contains(next)));
      if (!lone || priced) {
        out.add(
          _Token(
            _Kind.number,
            texts.sublist(i, i + read.length).join(' '),
            raw,
            milli: read.value * 1000,
            fromWords: !_digits.hasMatch(text),
          ),
        );
        i += read.length;
        continue;
      }
    }
    if (_digits.hasMatch(key)) {
      out.add(_Token(_Kind.number, text, raw, milli: _milli(key)));
      i++;
      continue;
    }

    if (key == 'و' || key == 'وكمان') {
      final half = next == null ? null : _halves[next];
      if (key == 'و' && half != null) {
        out.add(_Token(_Kind.half, '$text ${texts[i + 1]}', raw, milli: half));
        i += 2;
      } else {
        out.add(_Token(_Kind.conj, text, raw));
        i++;
      }
      continue;
    }
    // "وب ٢٠" and "وبـ٢٠" (the digits already split off): a و glued to
    // the price marker is "و ب", so [ArabicLineParser._splitOnWa] can
    // split there and [_resolve] still sees the ب before the price.
    if (key == 'وب') {
      out.add(_Token(_Kind.conj, 'و', raw));
      out.add(_Token(_Kind.marker, 'ب', raw));
      i++;
      continue;
    }
    if (key.startsWith('و') && _halves.containsKey(key.substring(1))) {
      out.add(_Token(_Kind.half, text, raw, milli: _halves[key.substring(1)]));
      i++;
      continue;
    }

    final unit = _units[key];
    final kind = unit != null
        ? _Kind.unit
        : key == 'ب'
        ? _Kind.marker
        : _currency.contains(key)
        ? _Kind.currency
        : _piastre.contains(key)
        ? _Kind.piastre
        : _fractions.containsKey(key)
        ? _Kind.fraction
        : _Kind.word;
    final token = _Token(
      kind,
      text,
      raw,
      milli: unit?.$2 ?? _fractions[key],
      unit: unit?.$1,
      plural: unit?.$3 ?? false,
    );
    if (unit?.$2 != null) token.counted = true;
    out.add(token);
    i++;
  }
  return out;
}

final _dayOrMonth = RegExp(r'^\d{1,2}$');
final _year = RegExp(r'^(\d{2}|\d{4})$');

/// How many working words at [i] spell `d/m` or `d/m/y`, or 0.
int _dateAt(List<String> keys, int i) {
  bool at(int j, RegExp shape) => j < keys.length && shape.hasMatch(keys[j]);
  bool slash(int j) => j < keys.length && keys[j] == '/';
  if (!at(i, _dayOrMonth) || !slash(i + 1) || !at(i + 2, _dayOrMonth)) {
    return 0;
  }
  return slash(i + 3) && at(i + 4, _year) ? 5 : 3;
}

int _milli(String digits) {
  final parts = digits.replaceAll(',', '').split('.');
  final fraction = parts.length == 2
      ? parts[1].padRight(3, '0').substring(0, 3)
      : '000';
  return int.parse(parts[0]) * 1000 + int.parse(fraction);
}

/// Pass 2: attach halves (ونص) to the number, unit or price before them,
/// read a fraction or a number right before a unit as that unit's count,
/// and drop the tokens those absorbed.
List<_Token> _combine(List<_Token> tokens) {
  final out = <_Token>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    final next = i + 1 < tokens.length ? tokens[i + 1] : null;

    if (t.kind == _Kind.half && out.isNotEmpty) {
      final prev = out.last;
      if (prev.isNumber) {
        prev.milli = prev.milli! + t.milli!;
        continue;
      }
      if (prev.kind == _Kind.unit) {
        prev.milli = (prev.milli ?? 1000) + t.milli!;
        prev.counted = true;
        continue;
      }
      if ((prev.kind == _Kind.currency || prev.kind == _Kind.piastre) &&
          out.length >= 2 &&
          out[out.length - 2].isNumber) {
        final number = out[out.length - 2];
        number.milli = number.milli! + t.milli!;
        continue;
      }
    }

    if (t.kind == _Kind.fraction && next?.kind == _Kind.unit) {
      final isThird = t.milli == 333;
      next!.milli = isThird && next.plural ? 3000 : t.milli;
      next.counted = true;
      continue;
    }

    // A count right before a unit is the unit's quantity, unless a price
    // marker claims it ("ب ٣٠ كيلو" is not a thing people say, but "ب ٣٠"
    // always is a price).
    if (t.isNumber &&
        next?.kind == _Kind.unit &&
        (out.isEmpty || out.last.kind != _Kind.marker)) {
      next!.milli = t.milli;
      next.counted = true;
      continue;
    }

    // Anything left of a half or fraction is a plain word ("لبن نص").
    if (t.kind == _Kind.half || t.kind == _Kind.fraction) {
      out.add(_Token(_Kind.word, t.text, t.rawIndex));
      continue;
    }
    out.add(t);
  }
  return out;
}

class _Resolved {
  _Resolved({
    required this.name,
    required this.quantityMilli,
    this.unit,
    this.amountPiastres,
    this.unitPricePiastres,
    required this.flags,
  });

  final String name;
  final int quantityMilli;
  final String? unit;
  final int? amountPiastres;
  final int? unitPricePiastres;
  final Set<ParseFlag> flags;
}

/// Pass 3: price, quantity, unit price and name (spec §6.5 steps 6-7).
/// Works on fresh copies of the `used` marks, so it can be run on a piece
/// more than once while [ArabicLineParser._splitOnWa] decides where to
/// split.
_Resolved _resolve(List<_Token> tokens) {
  for (final t in tokens) {
    t.used = false;
  }
  final flags = <ParseFlag>{};

  int piastres(_Token n, {bool isPiastres = false}) =>
      isPiastres ? n.milli! ~/ 1000 : n.milli! ~/ 10;

  _Token? at(int i) => i >= 0 && i < tokens.length ? tokens[i] : null;

  /// The number at [i], or after a ب at [i].
  _Token? numberFrom(int i) {
    final t = at(i);
    if (t?.kind == _Kind.marker && at(i + 1)?.isNumber == true) {
      return at(i + 1);
    }
    return t?.isNumber == true ? t : null;
  }

  // Unit prices: "الواحدة ب ٥", "الكيلو ب ١٥", or "١٢ الكيلو".
  int? unitPrice;
  String? unitFromPrice;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.kind != _Kind.each && t.kind != _Kind.perKilo) continue;
    t.used = true;
    final after = numberFrom(i + 1);
    final before = at(i - 1);
    final price = after != null && !after.used
        ? after
        : (before != null && before.isNumber && !before.used ? before : null);
    if (price != null && unitPrice == null) {
      price.used = true;
      if (at(i + 1)?.kind == _Kind.marker) at(i + 1)!.used = true;
      unitPrice = piastres(price);
      if (t.kind == _Kind.perKilo) unitFromPrice = ParsedUnit.kg;
    }
  }

  // Explicit totals: after ب, before a currency word, or after LE/EGP.
  int? total;
  var explicitCount = 0;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (!t.isNumber || t.used) continue;
    final prev = at(i - 1);
    final next = at(i + 1);
    final isPiastres = next?.kind == _Kind.piastre;
    final marked =
        prev?.kind == _Kind.marker ||
        next?.kind == _Kind.currency ||
        isPiastres ||
        (prev?.kind == _Kind.currency &&
            _latinCurrency.contains(normalizeArabic(prev!.text)));
    if (!marked) continue;
    t.used = true;
    explicitCount++;
    total ??= piastres(t, isPiastres: isPiastres);
  }
  if (explicitCount > 1) flags.add(ParseFlag.ambiguousAmount);

  // The quantity a unit states; a stated count beats a unit on its own.
  final units = tokens.where((t) => t.kind == _Kind.unit).toList();
  final countedUnit = units.where((t) => t.counted).firstOrNull;
  final unitToken = countedUnit ?? units.firstOrNull;
  int? quantity = countedUnit?.milli;
  final unit = unitToken?.unit ?? unitFromPrice;

  // Whatever numbers are left are bare.
  final bare = [
    for (var i = 0; i < tokens.length; i++)
      if (tokens[i].isNumber && !tokens[i].used) i,
  ];
  for (final i in bare) {
    tokens[i].used = true;
  }

  if (total == null && unitPrice == null) {
    if (bare.length == 1) {
      total = piastres(tokens[bare.single]);
    } else if (bare.length == 2) {
      final a = tokens[bare[0]];
      final b = tokens[bare[1]];
      if (a.fromWords != b.fromWords) {
        // A count in words next to a price in digits.
        final count = a.fromWords ? a : b;
        final price = a.fromWords ? b : a;
        final countIndex = a.fromWords ? bare[0] : bare[1];
        final priceIndex = a.fromWords ? bare[1] : bare[0];
        final nameAfter = tokens
            .skip(countIndex + 1)
            .any((t) => t.kind == _Kind.word);
        if (quantity != null) {
          total = piastres(price);
          flags.add(ParseFlag.ambiguousAmount);
        } else if (countIndex == priceIndex + 1 && !nameAfter) {
          // "انودي ١٢ اتنين": twelve each, or twelve for both.
          quantity = count.milli;
          unitPrice = piastres(price);
          flags.add(ParseFlag.ambiguousAmount);
        } else {
          quantity = count.milli;
          total = piastres(price);
        }
      } else {
        // Two bare numbers of the same kind: the larger is the price.
        final ordered = [a, b]..sort((x, y) => x.milli!.compareTo(y.milli!));
        total = piastres(ordered.last);
        quantity ??= ordered.first.milli;
        flags.add(ParseFlag.ambiguousAmount);
      }
    } else if (bare.length > 2) {
      final largest = bare
          .map((i) => tokens[i])
          .reduce((x, y) => x.milli! >= y.milli! ? x : y);
      total = piastres(largest);
      flags.add(ParseFlag.ambiguousAmount);
    }
  } else if (bare.isNotEmpty) {
    if (total == null) {
      // "٢٥ الواحده ب ٥": the bare number is the total.
      total = piastres(tokens[bare.first]);
    } else {
      // "٣ طماطم ٣٠ جنيه": the bare number is the count.
      quantity ??= tokens[bare.first].milli;
    }
    if (bare.length > 1) flags.add(ParseFlag.ambiguousAmount);
  }

  if (unitPrice != null) {
    if (total == null) {
      // Integer rounding to the nearest piastre and milli-unit: money
      // never goes through a double.
      total = (unitPrice * (quantity ?? 1000) + 500) ~/ 1000;
    } else if (quantity == null && unitPrice > 0) {
      quantity = (total * 1000 + unitPrice ~/ 2) ~/ unitPrice;
    }
  }

  return _Resolved(
    name: _name(tokens),
    quantityMilli: quantity ?? 1000,
    unit: unit,
    amountPiastres: total,
    unitPricePiastres: unitPrice,
    flags: flags,
  );
}

/// The name (spec §6.5 step 7): the words left once numbers, units, prices
/// and currency are gone. A standalone و is written onto the word after it,
/// the way Arabic spells it ("غسيل و كوي" becomes "غسيل وكوي").
String _name(List<_Token> tokens) {
  final words = <String>[];
  var pendingWa = false;
  for (final t in tokens) {
    if (t.kind == _Kind.conj) {
      pendingWa = normalizeArabic(t.text) == 'و';
      continue;
    }
    if (t.kind != _Kind.word) continue;
    words.add(pendingWa && words.isNotEmpty ? 'و${t.text}' : t.text);
    pendingWa = false;
  }
  return words.join(' ');
}
