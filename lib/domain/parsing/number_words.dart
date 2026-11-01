import '../../core/arabic_text.dart';

/// Reads spoken and written number words (spec §6.5 step 4): Egyptian and
/// MSA spellings of 1-19, the tens, the hundreds and the thousands, English
/// one to ten and twenty, and compounds joined with و ("خمسة وعشرين",
/// "مية و خمسين"). Whole numbers only: halves and quarters (ونص, ربع) are
/// the line parser's business, because they mean half a pound after جنيه
/// and half a kilo after كيلو. Pure Dart.
///
/// Every table is keyed on [normalizeArabic] output, so ة/ه, أ/ا and ى/ي
/// spellings all land on the same entry.

/// Words below a hundred, and the hundreds, which simply add up.
const Map<String, int> _additive = {
  // 1-10.
  'واحد': 1, 'واحده': 1,
  'اتنين': 2, 'اثنين': 2, 'اتنان': 2, 'اثنان': 2,
  'تلاته': 3, 'ثلاثه': 3, 'تلات': 3, 'ثلاث': 3,
  'اربعه': 4, 'اربع': 4,
  'خمسه': 5, 'خمس': 5,
  'سته': 6,
  'سبعه': 7,
  // No short "تمن": in Egyptian speech it is "price", not eight.
  'تمانيه': 8, 'ثمانيه': 8,
  'تسعه': 9,
  'عشره': 10,
  // 11-19.
  'حداشر': 11, 'احداشر': 11, 'حداشير': 11,
  'اتناشر': 12, 'اطناشر': 12, 'اثناشر': 12,
  'تلتاشر': 13, 'تلطاشر': 13, 'ثلتاشر': 13,
  'اربعتاشر': 14, 'اربعطاشر': 14, 'اربتاشر': 14,
  'خمستاشر': 15, 'خمسطاشر': 15,
  'ستاشر': 16, 'سطاشر': 16,
  'سبعتاشر': 17, 'سبعطاشر': 17,
  'تمنتاشر': 18, 'تمنطاشر': 18,
  'تسعتاشر': 19, 'تسعطاشر': 19,
  // Tens, with the MSA nominative -ون forms.
  'عشرين': 20, 'عشرون': 20,
  'تلاتين': 30, 'ثلاثين': 30, 'ثلاثون': 30,
  'اربعين': 40, 'اربعون': 40,
  'خمسين': 50, 'خمسون': 50,
  'ستين': 60, 'ستون': 60,
  'سبعين': 70, 'سبعون': 70,
  'تمانين': 80, 'ثمانين': 80, 'ثمانون': 80,
  'تسعين': 90, 'تسعون': 90,
  // Hundreds. ميت is the construct form ("ميت جنيه").
  'ميه': 100, 'مايه': 100, 'مائه': 100, 'ماءه': 100, 'ميت': 100,
  'ميتين': 200, 'مايتين': 200, 'مائتين': 200, 'مائتان': 200,
  'تلتميه': 300, 'ثلاثميه': 300, 'ثلاثمائه': 300, 'تلاتميه': 300,
  'ربعميه': 400, 'اربعميه': 400, 'اربعمائه': 400,
  'خمسميه': 500, 'خمسمائه': 500,
  'ستميه': 600, 'ستمائه': 600,
  'سبعميه': 700, 'سبعمائه': 700,
  'تمنميه': 800, 'ثمانميه': 800, 'ثمانمائه': 800,
  'تسعميه': 900, 'تسعمائه': 900,
  // English.
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  'twenty': 20,
};

/// "الف" multiplies what came before it (or stands for one thousand);
/// "الفين" is a dual and adds two thousand outright.
const Set<String> _thousand = {'الف', 'الاف', 'الوف', 'thousand'};
const Map<String, int> _thousandDual = {'الفين': 2000, 'الفان': 2000};

/// True when [word] (already normalised) is a number word on its own.
bool isNumberWord(String word) =>
    _additive.containsKey(word) ||
    _thousand.contains(word) ||
    _thousandDual.containsKey(word);

/// The result of [readNumberWords]: the number read and how many words it
/// took.
class NumberWordRead {
  const NumberWordRead(this.value, this.length);

  final int value;
  final int length;
}

/// Reads the longest number phrase in [words] starting at [start].
///
/// [words] may be raw or normalised; each is normalised here. A و joins two
/// number words whether it stands alone ("خمسة و عشرين") or is attached
/// ("وعشرين"), but a و followed by anything else ends the phrase and is
/// left for the caller, which is what keeps "عشرين و عيش" from eating the
/// و that separates two items. A digit token only takes part when a
/// thousands word follows it ("3 الاف"); plain digits are read by the
/// caller. Null when the word at [start] starts no number.
NumberWordRead? readNumberWords(List<String> words, int start) {
  var total = 0;
  var current = 0;
  var i = start;
  var any = false;

  String at(int index) => normalizeArabic(words[index]);

  // "3 الاف": a digit count multiplied by the next word.
  if (i < words.length &&
      RegExp(r'^\d+$').hasMatch(at(i)) &&
      i + 1 < words.length &&
      _thousand.contains(at(i + 1))) {
    current = int.parse(at(i)) * 1000;
    total += current;
    current = 0;
    i += 2;
    any = true;
  }

  while (i < words.length) {
    var word = at(i);
    var width = 1;
    if (any) {
      // Only a و (attached or standalone) can continue a phrase.
      if (word == 'و' && i + 1 < words.length && isNumberWord(at(i + 1))) {
        word = at(i + 1);
        width = 2;
      } else if (word.length > 1 &&
          word.startsWith('و') &&
          isNumberWord(word.substring(1))) {
        word = word.substring(1);
      } else if (_thousand.contains(word)) {
        // "عشرين الف": a thousands word right after a number, no و.
      } else {
        break;
      }
    }

    final additive = _additive[word];
    if (additive != null) {
      current += additive;
    } else if (_thousand.contains(word)) {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
    } else if (_thousandDual.containsKey(word)) {
      total += _thousandDual[word]!;
    } else {
      break;
    }
    any = true;
    i += width;
  }

  if (!any) return null;
  return NumberWordRead(total + current, i - start);
}

/// Reads [text] as one whole number phrase, or null when any part of it is
/// not a number word.
int? parseNumberWords(String text) {
  final words = text.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return null;
  final read = readNumberWords(words, 0);
  if (read == null || read.length != words.length) return null;
  return read.value;
}
