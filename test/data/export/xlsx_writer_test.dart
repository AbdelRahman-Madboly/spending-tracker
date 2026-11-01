import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/export/xlsx_writer.dart';

String _sheetXml(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.findFile('xl/worksheets/sheet1.xml')!;
  return utf8.decode(file.content as List<int>);
}

void main() {
  group('excelSerial', () {
    test('counts days from 1899-12-30', () {
      expect(excelSerial(DateTime(1899, 12, 31)), 1);
      expect(excelSerial(DateTime(2025, 1, 1)), 45658);
      expect(excelSerial(DateTime(2026, 1, 1)), 46023);
    });

    test('ignores the time of day', () {
      expect(excelSerial(DateTime(2026, 9, 4, 23, 59)),
          excelSerial(DateTime(2026, 9, 4)));
    });
  });

  group('buildXlsx', () {
    test('writes the parts a spreadsheet reader needs', () {
      final bytes = buildXlsx(sheetName: 'S', headers: ['a'], rows: []);
      final names =
          ZipDecoder().decodeBytes(bytes).files.map((f) => f.name).toSet();
      expect(
          names,
          containsAll([
            '[Content_Types].xml',
            '_rels/.rels',
            'xl/workbook.xml',
            'xl/_rels/workbook.xml.rels',
            'xl/styles.xml',
            'xl/worksheets/sheet1.xml',
          ]));
    });

    test('keeps a money amount as its exact decimal text', () {
      final xml = _sheetXml(buildXlsx(
        sheetName: 'S',
        headers: ['amount'],
        rows: [
          [const XlsxNumber('30.5', money: true)],
          [const XlsxNumber('0.1')],
        ],
      ));
      expect(xml, contains('<c r="A2" s="3"><v>30.5</v></c>'));
      expect(xml, contains('<c r="A3"><v>0.1</v></c>'));
    });

    test('stores a date as its serial with the date style', () {
      final xml = _sheetXml(buildXlsx(
        sheetName: 'S',
        headers: ['day'],
        rows: [
          [XlsxDate(DateTime(2026, 1, 1))],
        ],
      ));
      expect(xml, contains('<c r="A2" s="2"><v>46023</v></c>'));
    });

    test('names columns past Z as AA, AB', () {
      final headers = List.generate(28, (i) => 'h$i');
      final xml = _sheetXml(
          buildXlsx(sheetName: 'S', headers: headers, rows: []));
      expect(xml, contains('r="Z1"'));
      expect(xml, contains('r="AA1"'));
      expect(xml, contains('r="AB1"'));
    });

    test('escapes markup and drops control characters XML cannot hold', () {
      final xml = _sheetXml(buildXlsx(
        sheetName: 'S',
        headers: ['note'],
        rows: [
          [const XlsxText('<a> & "b"\u0001')],
        ],
      ));
      expect(xml, contains('&lt;a&gt; &amp; &quot;b&quot;</t>'));
      expect(xml, isNot(contains('\u0001')));
    });

    test('an empty cell writes nothing, and the header row is frozen', () {
      final xml = _sheetXml(buildXlsx(
        sheetName: 'S',
        headers: ['a', 'b'],
        rows: [
          [const XlsxEmpty(), const XlsxText('x')],
        ],
      ));
      expect(xml, isNot(contains('r="A2"')));
      expect(xml, contains('r="B2"'));
      expect(xml, contains('state="frozen"'));
    });
  });
}
