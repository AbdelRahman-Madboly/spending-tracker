import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../parsing/line_parser.dart';
import '../parsing/parsed_line.dart';
import 'import_pack.dart';

/// The text body of a Samsung Notes `.sdocx` file, or null when [bytes]
/// is not one (not a zip, or a zip with no `note.note`).
///
/// An `.sdocx` is a zip whose `note.note` holds the body as a uint32
/// little-endian count of UTF-16 code units followed by that many UTF-16LE
/// units, between binary fields that carry no documented layout. So the
/// body is found by shape rather than by offset: of every run that
/// decodes as a count plus text with no control characters but tab and
/// line breaks, the longest is the body. The other strings in the file
/// (page ids) are short ASCII with a 16-bit length, which never qualify.
/// Checked against fifteen real notes, each read back exactly.
String? readSdocxNote(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return null;
  }
  final entry = archive.findFile('note.note');
  if (entry == null) return null;
  final Uint8List data;
  try {
    data = entry.readBytes() ?? Uint8List(0);
  } catch (_) {
    return null;
  }
  return _longestUtf16Run(data);
}

bool _isTextUnit(int u) =>
    u == 0x09 ||
    u == 0x0a ||
    u == 0x0d ||
    (u >= 0x20 && u < 0xd800) ||
    // Past the surrogates and the private use area, short of the
    // non-characters.
    (u >= 0xf900 && u < 0xfffe);

String? _longestUtf16Run(Uint8List data) {
  final view = ByteData.sublistView(data);
  String? best;
  for (var i = 0; i + 4 <= data.length; i++) {
    final count = view.getUint32(i, Endian.little);
    if (count == 0 || count <= (best?.length ?? 0)) continue;
    final end = i + 4 + count * 2;
    if (end > data.length) continue;
    final units = <int>[];
    for (var j = i + 4; j < end; j += 2) {
      final u = view.getUint16(j, Endian.little);
      if (!_isTextUnit(u)) break;
      units.add(u);
    }
    if (units.length == count) best = String.fromCharCodes(units);
  }
  return best;
}

final _noteName = RegExp(r'Notes_(\d{2})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})');

/// When a Samsung note was created, from its file name
/// `Notes_YYMMDD_HHMMSS`, or null for any other name.
DateTime? noteCreatedAt(String fileName) {
  final m = _noteName.firstMatch(p.basename(fileName));
  if (m == null) return null;
  final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  final at = DateTime(2000 + v[0], v[1], v[2], v[3], v[4], v[5]);
  // 31/2 or 13/13 rolls over in DateTime; a real name never does.
  if (at.month != v[1] || at.day != v[2] || at.hour != v[3]) return null;
  return at;
}

const _flagCodes = {
  ParseFlag.noAmount: 'no_amount',
  ParseFlag.noCategory: 'no_category',
  ParseFlag.ambiguousAmount: 'amount_ambiguous',
  ParseFlag.fuzzyMatch: 'fuzzy_match',
  ParseFlag.dateFromText: 'date_from_note_text',
};

/// FNV-1a, 32 bits, as eight hex digits: a stable id for a text, the same
/// on every run and every device (unlike [String.hashCode]).
String _fnv1a(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// The lines of a note, read by the local [parser] (spec §6.5), as an
/// import pack. [capturedAt] dates them (before 05:00 counts as the day
/// before) until a `d/m` line in the note changes the date.
///
/// Rows of an `.sdocx` note are identified by its file name and line
/// number (`note:Notes_260913_224548.sdocx:0`); rows of plain text, which
/// has no name, by a hash of the whole text (`text:<hash>:0`). Either way
/// sharing the same note twice finds its rows already there.
ImportPack noteImportPack({
  String? fileName,
  required String text,
  required DateTime capturedAt,
  required ArabicLineParser parser,
}) {
  final lines = parser.parse(text, capturedAt: capturedAt);
  final identity = fileName != null
      ? 'note:${p.basename(fileName)}'
      : 'text:${_fnv1a(text.trim())}';
  final rows = <ImportRow>[];
  final groups = <String>{};
  for (final (i, line) in lines.indexed) {
    final day = line.date;
    final groupKey = '$identity|${day.year}-${day.month}-${day.day}';
    groups.add(groupKey);
    final plainCount = line.quantityMilli == 1000 && line.unit == null;
    rows.add(
      ImportRow(
        externalId: '$identity:$i',
        ref: '${i + 1}',
        date: day,
        amountPiastres: line.amountPiastres,
        categoryKey: line.categoryKey,
        subcategoryKey: line.subcategoryKey,
        itemId: line.itemId,
        description: line.name,
        quantityMilli: plainCount ? null : line.quantityMilli,
        unit: line.unit,
        unitPricePiastres: line.unitPricePiastres,
        rawText: line.rawText,
        flags: [
          for (final f in ParseFlag.values)
            if (line.flags.contains(f)) _flagCodes[f]!,
          if (capturedAt.hour < 5 &&
              !line.flags.contains(ParseFlag.dateFromText))
            'date_after_midnight',
        ],
        groupKey: groupKey,
      ),
    );
  }
  return ImportPack(
    fileName: fileName == null ? 'text' : p.basename(fileName),
    rows: rows,
    fromNote: true,
    rawTextByGroup: {for (final g in groups) g: text.trim()},
  );
}

/// The pack a file the user picked or shared holds, by its extension: a
/// `.json` import pack, a Samsung Notes `.sdocx` (dated by its name, or
/// [now] when the name is not `Notes_YYMMDD_HHMMSS`), or anything else as
/// UTF-8 text read like a note captured [now]. Throws [FormatException]
/// for a file that is none of these.
ImportPack packFromFile(
  String fileName,
  Uint8List bytes, {
  required ArabicLineParser parser,
  required DateTime now,
}) {
  final name = p.basename(fileName);
  switch (p.extension(name).toLowerCase()) {
    case '.json':
      return parseImportPack(name, utf8.decode(bytes, allowMalformed: true));
    case '.sdocx':
      final text = readSdocxNote(bytes);
      if (text == null) throw const FormatException('not a Samsung note');
      return noteImportPack(
        fileName: name,
        text: text,
        capturedAt: noteCreatedAt(name) ?? now,
        parser: parser,
      );
    default:
      final String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        throw const FormatException('not a text file');
      }
      return noteImportPack(text: text, capturedAt: now, parser: parser);
  }
}
