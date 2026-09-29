import 'parsing/catalogue_matcher.dart';
import 'parsing/parsed_line.dart';

/// Which way an InstaPay transfer went, as far as the screenshot says.
enum TransferDirection {
  /// Paid by the user: an expense. Also what anything that is not a
  /// transfer reads as.
  sent,

  /// Paid to the user: money in.
  received,

  /// The screenshot names the user, or says both things, and cannot be
  /// placed either way.
  uncertain,
}

/// The user's own InstaPay identity: the address, and the Latin spellings
/// of the name the payer's app shows (often cut short as "Mostafa M***").
final _ownIdentity = RegExp(
  r'sampleuser\s*@\s*instapay|mou?s[\s-]?t?a?fa',
  caseSensitive: false,
);

final _receivedWord =
    RegExp(r'\breceived\b|تم\s+استلام|استلمت|وارد', caseSensitive: false);
final _toLabel = RegExp(r'^(?:sent\s+)?to\b|^إلى|^الى', caseSensitive: false);
final _fromLabel = RegExp(r'^(?:received\s+)?from\b|^من\b', caseSensitive: false);

/// The import identity of a salary recorded from the InstaPay transfer
/// with [reference]: the same transfer shared again is refused.
String transferSalaryId(String reference) => 'instapay:$reference';

/// What the offline recogniser's Latin text says about a photo (spec §6.2):
/// a total, a date, an InstaPay reference and the Latin words that may
/// name a product. Pure Dart, so every rule is unit tested without a
/// recogniser; `TextRecognitionService` supplies the text on the phone.
class PhotoReading {
  const PhotoReading({
    this.amountPiastres,
    this.date,
    this.reference,
    this.isInstaPay = false,
    this.direction = TransferDirection.sent,
    this.words = const [],
  });

  /// The largest amount written next to a money word, in piastres.
  final int? amountPiastres;
  final DateTime? date;

  /// The InstaPay transaction reference. Only read off an InstaPay
  /// screenshot: a receipt's own "Ref" is a till number, and treating it as
  /// a payment reference would refuse the next receipt from the same till.
  final String? reference;
  final bool isInstaPay;

  /// Which way the transfer went; [TransferDirection.sent] for anything
  /// that is not an InstaPay screenshot.
  final TransferDirection direction;

  /// Lower-cased Latin words that could be a brand, in reading order,
  /// receipt vocabulary taken out.
  final List<String> words;

  static const empty = PhotoReading();
}

/// Words that sit next to a total (spec §6.2). "total" also catches
/// Subtotal and Total Due; the largest amount wins, so a subtotal never
/// beats the total under it.
final _moneyWord = RegExp(
  r'egp|\ble\b|l\.e|ج\.?م|جنيه|total|amount|الإجمالي|الاجمالي|المبلغ',
  caseSensitive: false,
);

/// An amount: thousands grouped by commas with an optional decimal part,
/// or plain digits with a one- or two-digit decimal after a dot or comma.
/// At most seven digits before the point, so a reference number is never
/// read as money.
final _amount = RegExp(
  r'(?<![\d.,])(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d{1,7}(?:[.,]\d{1,2})?)(?![\d.,]*\d)',
);

final _numericDate =
    RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\b|\b(\d{4})-(\d{1,2})-(\d{1,2})\b');

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

final _dayMonthName = RegExp(r'\b(\d{1,2})\s+([a-z]{3,9})\.?,?\s+(\d{4})\b');
final _monthNameDay = RegExp(r'\b([a-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{4})\b');

final _instaPayWord = RegExp(r'insta\s?pay|@instapay|\bipa\b', caseSensitive: false);

final _referenceLabel = RegExp(
  r'(reference|\bref\b\.?|transaction\s*(?:id|no\.?|number|reference)|\btxn\b)',
  caseSensitive: false,
);
final _labelFiller =
    RegExp(r'^[\s.:#-]*(?:(?:number|no\.?|id|reference)\b[\s.:#-]*)*', caseSensitive: false);

/// Receipt and screenshot vocabulary: never a brand.
const _stopWords = {
  'total', 'subtotal', 'amount', 'egp', 'cash', 'change', 'vat', 'tax', //
  'date', 'time', 'thank', 'thanks', 'you', 'for', 'the', 'and', 'from',
  'sent', 'transaction', 'successful', 'success', 'reference', 'ref',
  'number', 'instapay', 'receipt', 'invoice', 'visa', 'card', 'qty',
  'price', 'item', 'items', 'due', 'paid', 'net', 'discount', 'tel',
  'phone', 'www', 'com', 'order', 'bill', 'store', 'branch',
  'transfer', 'account', 'bank', 'fees', 'fee', 'details', 'status',
  'completed', 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug',
  'sep', 'sept', 'oct', 'nov', 'dec', 'am', 'pm', 'ipa',
};

/// Eastern Arabic digits and the Arabic decimal separator to Latin ones.
String _latinDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune == 0x066B) {
      out.write('.');
    } else if (rune == 0x066C) {
      out.write(',');
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Reads the recogniser's text (spec §6.2). [now] bounds the date: a date
/// after today is a misread (or an expiry date) and is left out.
PhotoReading readPhotoText(String text, {required DateTime now}) {
  final lines = [
    for (final l in _latinDigits(text).split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  final isInstaPay = lines.any(_instaPayWord.hasMatch);
  return PhotoReading(
    amountPiastres: _readAmount(lines),
    date: _readDate(lines, now),
    reference: isInstaPay ? _readReference(lines) : null,
    isInstaPay: isInstaPay,
    direction: isInstaPay ? _readDirection(lines) : TransferDirection.sent,
    words: _readWords(lines),
  );
}

/// Which side of the transfer the user is on. The user's name or address
/// under a To label (a payer's "Sent to" screenshot included) or a
/// Received label says money in; the user under From says money out.
/// The user named with nothing to place them, or signals both ways, is
/// uncertain; a transfer that names someone else is sent.
TransferDirection _readDirection(List<String> lines) {
  var ownUnderTo = false, ownUnderFrom = false, ownNamed = false;
  var receivedWord = false;
  // The label the lines under it belong to, until the next label.
  bool? underTo;
  for (final line in lines) {
    if (_toLabel.hasMatch(line)) {
      underTo = true;
    } else if (_fromLabel.hasMatch(line)) {
      underTo = false;
    } else if (!_ownIdentity.hasMatch(line) && _referenceLabel.hasMatch(line)) {
      underTo = null;
    }
    if (_receivedWord.hasMatch(line)) receivedWord = true;
    if (_ownIdentity.hasMatch(line)) {
      ownNamed = true;
      if (underTo == true) ownUnderTo = true;
      if (underTo == false) ownUnderFrom = true;
    }
  }
  final receivedSignal = ownUnderTo || receivedWord;
  if (receivedSignal && ownUnderFrom) return TransferDirection.uncertain;
  if (receivedSignal) return TransferDirection.received;
  if (ownUnderFrom) return TransferDirection.sent;
  return ownNamed ? TransferDirection.uncertain : TransferDirection.sent;
}

int? _readAmount(List<String> lines) {
  int? best;
  void consider(String line) {
    for (final m in _amount.allMatches(line.replaceAll(_numericDate, ' '))) {
      final piastres = _piastres(m.group(1)!);
      if (piastres != null && piastres > 0 && (best == null || piastres > best!)) {
        best = piastres;
      }
    }
  }

  for (var i = 0; i < lines.length; i++) {
    if (!_moneyWord.hasMatch(lines[i])) continue;
    final before = best;
    consider(lines[i]);
    // "Total" on its own line with the figure under it.
    if (best == before && !_amount.hasMatch(lines[i]) && i + 1 < lines.length) {
      consider(lines[i + 1]);
    }
  }
  return best;
}

int? _piastres(String number) {
  String pounds;
  var fraction = '';
  if (RegExp(r',\d{3}').hasMatch(number)) {
    // Commas group thousands; a dot, if any, is the decimal point.
    final parts = number.replaceAll(',', '').split('.');
    pounds = parts.first;
    if (parts.length > 1) fraction = parts[1];
  } else {
    final parts = number.split(RegExp('[.,]'));
    pounds = parts.first;
    if (parts.length > 1) fraction = parts[1];
  }
  final whole = int.tryParse(pounds);
  if (whole == null) return null;
  final cents = fraction.isEmpty ? 0 : int.parse(fraction.padRight(2, '0'));
  return whole * 100 + cents;
}

DateTime? _readDate(List<String> lines, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime? valid(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    // DateTime rolls 31/02 over into March: that was not a real date.
    if (date.month != m || date.day != d) return null;
    return date.isAfter(today) ? null : date;
  }

  for (final raw in lines) {
    final line = raw.toLowerCase();
    for (final m in _numericDate.allMatches(line)) {
      final date = m.group(1) != null
          ? valid(int.parse(m.group(3)!), int.parse(m.group(2)!),
              int.parse(m.group(1)!))
          : valid(int.parse(m.group(4)!), int.parse(m.group(5)!),
              int.parse(m.group(6)!));
      if (date != null) return date;
    }
    for (final m in _dayMonthName.allMatches(line)) {
      final month = _months[m.group(2)!.substring(0, 3)];
      if (month == null) continue;
      final date =
          valid(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
      if (date != null) return date;
    }
    for (final m in _monthNameDay.allMatches(line)) {
      final month = _months[m.group(1)!.substring(0, 3)];
      if (month == null) continue;
      final date =
          valid(int.parse(m.group(3)!), month, int.parse(m.group(2)!));
      if (date != null) return date;
    }
  }
  return null;
}

/// The reference after its label, on the same line or the next. Digit
/// groups split by spaces ("1234 5678 9012") are one number.
String? _readReference(List<String> lines) {
  String? token(String text) {
    final joined = text.replaceAllMapped(
        RegExp(r'(\d)\s+(?=\d)'), (m) => m.group(1)!);
    for (final m in RegExp(r'[A-Za-z0-9]{6,}').allMatches(joined)) {
      final candidate = m.group(0)!;
      if (RegExp(r'\d').hasMatch(candidate)) return candidate.toUpperCase();
    }
    return null;
  }

  for (var i = 0; i < lines.length; i++) {
    final label = _referenceLabel.firstMatch(lines[i]);
    if (label == null) continue;
    final rest = lines[i].substring(label.end).replaceFirst(_labelFiller, '');
    final found = token(rest) ?? (i + 1 < lines.length ? token(lines[i + 1]) : null);
    if (found != null) return found;
  }
  return null;
}

List<String> _readWords(List<String> lines) => [
      for (final line in lines)
        for (final m in RegExp('[A-Za-z]{3,}').allMatches(line))
          if (!_stopWords.contains(m.group(0)!.toLowerCase()) &&
              !line.contains('@'))
            m.group(0)!.toLowerCase(),
    ];

/// The review lines a photo gives (spec §6.2):
///
/// - an InstaPay screenshot is one transfer line with its amount, date and
///   reference (the caller sets the payment method);
/// - a receipt total is one line, filed under the product when exactly one
///   known product is named on it;
/// - packaging with no total is one line per known product, priced at
///   [priceOf] (the item's last price) when it has one.
///
/// Brand words go through the parser's catalogue, so a Latin name linked
/// to an item in review is learned as an alias and matches next time.
List<ParsedLine> photoLines(
  PhotoReading reading,
  ParserCatalogue catalogue, {
  required DateTime day,
  required int? Function(String itemId) priceOf,
}) {
  final date = reading.date ?? day;
  final amount = reading.amountPiastres;
  if (reading.isInstaPay) {
    if (amount == null && reading.reference == null) return const [];
    final direction = reading.direction;
    return [
      ParsedLine(
        rawText: 'InstaPay',
        date: date,
        name: direction == TransferDirection.received
            ? 'تحويل وارد'
            : 'تحويل إنستاباي',
        amountPiastres: amount,
        reference: reading.reference,
        confidence: direction == TransferDirection.uncertain
            ? ParseConfidence.low
            : ParseConfidence.medium,
        flags: {
          ParseFlag.noCategory,
          if (amount == null) ParseFlag.noAmount,
          if (direction == TransferDirection.received) ParseFlag.incoming,
          if (direction == TransferDirection.uncertain)
            ParseFlag.maybeIncoming,
        },
      ),
    ];
  }

  final matches = <CatalogueMatch>[];
  final seen = <String>{};
  for (final word in reading.words) {
    final match = catalogue.match(word);
    final id = match.itemId;
    if (id != null && seen.add(id)) matches.add(match);
  }

  if (amount != null) {
    final only = matches.length == 1 ? matches.single : null;
    return [
      ParsedLine(
        rawText: reading.words.join(' '),
        date: date,
        name: only?.name ?? 'فاتورة',
        itemId: only?.itemId,
        categoryKey: only?.categoryKey,
        subcategoryKey: only?.subcategoryKey,
        amountPiastres: amount,
        confidence: only == null ? ParseConfidence.low : ParseConfidence.medium,
        flags: {if (only?.categoryKey == null) ParseFlag.noCategory},
      ),
    ];
  }

  return [
    for (final match in matches)
      ParsedLine(
        rawText: match.name,
        date: date,
        name: match.name,
        itemId: match.itemId,
        categoryKey: match.categoryKey,
        subcategoryKey: match.subcategoryKey,
        amountPiastres: priceOf(match.itemId!),
        confidence: ParseConfidence.medium,
        flags: {
          if (priceOf(match.itemId!) == null) ParseFlag.noAmount,
          if (match.fuzzy) ParseFlag.fuzzyMatch,
        },
      ),
  ];
}
