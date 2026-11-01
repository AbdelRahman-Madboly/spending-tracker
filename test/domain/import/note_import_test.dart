import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/import/note_import.dart';
import 'package:spending_tracker/domain/parsing/line_parser.dart';

import '../parsing/parser_catalogue_fixture.dart';

/// A `note.note` shaped like Samsung Notes writes it: binary header
/// fields, a UUID as a uint16-length-prefixed ASCII string, then the body
/// as a uint32 count of UTF-16 code units followed by the UTF-16LE text,
/// then more binary. Built here rather than copied from a real note so the
/// fixture carries nothing from the phone but the layout.
Uint8List _noteFile(String body) {
  final out = BytesBuilder();
  out.add([0x8b, 0x03, 0, 0, 0x04, 0x08, 0, 0, 0, 0x04, 0x80, 0x0a]);
  const uuid = 'a9d915a0-afab-11f1-8d74-c7fc4e8af8cc';
  out.add([uuid.length, 0]);
  out.add(ascii.encode(uuid));
  out.add(List.filled(40, 0));
  final units = body.codeUnits;
  out.add((ByteData(4)..setUint32(0, units.length, Endian.little))
      .buffer
      .asUint8List());
  final text = ByteData(units.length * 2);
  for (var i = 0; i < units.length; i++) {
    text.setUint16(i * 2, units[i], Endian.little);
  }
  out.add(text.buffer.asUint8List());
  out.add([0x02, 0, 0, 0, 0x18, 0, 0x03, 0, 0xff, 0xff, 0xff, 0xff]);
  return out.toBytes();
}

Uint8List _sdocx(String body) {
  final archive = Archive()
    ..add(ArchiveFile.bytes('note.note', _noteFile(body)))
    ..add(ArchiveFile.bytes('media/mediaInfo.dat', Uint8List(10)))
    ..add(ArchiveFile.bytes('end_tag.bin', Uint8List(16)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('readSdocxNote', () {
    test('reads the body of note.note', () {
      const body = '١١/٩\nحلاقة ١٢٠\nزيارة ٢٠٠';
      expect(readSdocxNote(_sdocx(body)), body);
    });

    test('reads Latin text too', () {
      const body = '30 swhipps \nIndomi two 24\nChips 15';
      expect(readSdocxNote(_sdocx(body)), body);
    });

    test('gives null for a file that is not a note', () {
      expect(readSdocxNote(Uint8List.fromList([1, 2, 3])), isNull);
      final zip = Archive()..add(ArchiveFile.bytes('other.txt', [65]));
      expect(
          readSdocxNote(Uint8List.fromList(ZipEncoder().encode(zip))), isNull);
    });
  });

  group('noteCreatedAt', () {
    test('reads Notes_YYMMDD_HHMMSS', () {
      expect(noteCreatedAt('Notes_260913_224548.sdocx'),
          DateTime(2026, 9, 13, 22, 45, 48));
      expect(noteCreatedAt('/x/y/Notes_260928_040716'),
          DateTime(2026, 9, 28, 4, 7, 16));
    });

    test('gives null for any other name', () {
      expect(noteCreatedAt('shopping.txt'), isNull);
      expect(noteCreatedAt('Notes_261399_000000.sdocx'), isNull);
    });
  });

  group('noteImportPack', () {
    final parser = ArabicLineParser(parserCatalogueFixture());

    test('parses each line with the local parser, dated by the note', () {
      final pack = noteImportPack(
        fileName: 'Notes_260928_040716.sdocx',
        text: 'فيروز ٥٥\nاندومي ٢٥',
        capturedAt: DateTime(2026, 9, 28, 4, 7, 16),
        parser: parser,
      );
      expect(pack.fromNote, isTrue);
      expect(pack.rows, hasLength(2));
      // Written at 04:07: it belongs to the evening before.
      expect(pack.rows.map((r) => r.date).toSet(), {DateTime(2026, 9, 27)});
      expect(pack.rows.map((r) => r.amountPiastres), [5500, 2500]);
      expect(pack.rows.first.externalId,
          'note:Notes_260928_040716.sdocx:0');
      expect(pack.rows[1].externalId, 'note:Notes_260928_040716.sdocx:1');
      expect(pack.rows.first.groupKey, pack.rows[1].groupKey);
      expect(pack.rawTextByGroup[pack.rows.first.groupKey],
          'فيروز ٥٥\nاندومي ٢٥');
    });

    test('a d/m line in the note dates the lines after it', () {
      final pack = noteImportPack(
        fileName: 'Notes_260913_224548.sdocx',
        text: '١١/٩\nحلاقة ١٢٠',
        capturedAt: DateTime(2026, 9, 13, 22, 45),
        parser: parser,
      );
      expect(pack.rows.single.date, DateTime(2026, 9, 11));
      expect(pack.rows.single.flags, contains('date_from_note_text'));
    });

    test('a line with no price is kept, flagged, with no amount', () {
      final pack = noteImportPack(
        fileName: 'Notes_260913_224548.sdocx',
        text: 'حلاقة',
        capturedAt: DateTime(2026, 9, 13, 22),
        parser: parser,
      );
      expect(pack.rows.single.amountPiastres, isNull);
      expect(pack.rows.single.flags, contains('no_amount'));
    });

    test('plain text is identified by a hash of the whole text', () {
      final a = noteImportPack(
          text: 'تاكسي ٤٥', capturedAt: DateTime(2026, 9, 20, 12),
          parser: parser);
      final b = noteImportPack(
          text: 'تاكسي ٤٥', capturedAt: DateTime(2026, 9, 21, 12),
          parser: parser);
      final c = noteImportPack(
          text: 'تاكسي ٣٦', capturedAt: DateTime(2026, 9, 20, 12),
          parser: parser);
      expect(a.rows.single.externalId, startsWith('text:'));
      expect(a.rows.single.externalId, b.rows.single.externalId);
      expect(a.rows.single.externalId, isNot(c.rows.single.externalId));
    });
  });

  group('packFromFile', () {
    final parser = ArabicLineParser(parserCatalogueFixture());
    final now = DateTime(2026, 9, 29, 12);

    test('an .sdocx is read and dated by its name', () {
      final pack = packFromFile('Notes_260928_040716.sdocx',
          _sdocx('فيروز ٥٥'), parser: parser, now: now);
      expect(pack.rows.single.date, DateTime(2026, 9, 27));
      expect(pack.rows.single.externalId, 'note:Notes_260928_040716.sdocx:0');
    });

    test('an .sdocx with another name is dated now', () {
      final pack = packFromFile('shopping.sdocx', _sdocx('فيروز ٥٥'),
          parser: parser, now: now);
      expect(pack.rows.single.date, DateTime(2026, 9, 29));
    });

    test('an .sdocx that is not a note is refused', () {
      expect(
          () => packFromFile('x.sdocx', Uint8List.fromList([1, 2]),
              parser: parser, now: now),
          throwsFormatException);
    });

    test('a text file is parsed as a note', () {
      final pack = packFromFile(
          'list.txt', Uint8List.fromList(utf8.encode('تاكسي ٤٥')),
          parser: parser, now: now);
      expect(pack.fromNote, isTrue);
      expect(pack.rows.single.amountPiastres, 4500);
      expect(pack.rows.single.externalId, startsWith('text:'));
    });

    test('a JSON file is read as an import pack', () {
      final json = '{"format":"manual-import/1","entries":[{"ref":"a",'
          '"date":"2026-09-01","amountPiastres":500,"categoryKey":"Food"}]}';
      final pack = packFromFile(
          'm.json', Uint8List.fromList(utf8.encode(json)),
          parser: parser, now: now);
      expect(pack.rows.single.externalId, 'pack:m.json:a');
    });
  });
}
