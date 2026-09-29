import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One cell of an exported sheet. Numbers are written from their exact
/// decimal text, never through a double, so 30.5 pounds stays 30.5.
sealed class XlsxCell {
  const XlsxCell();
}

class XlsxText extends XlsxCell {
  const XlsxText(this.value);
  final String value;
}

/// A number given as its decimal text (`'30.5'`, `'2'`).
class XlsxNumber extends XlsxCell {
  const XlsxNumber(this.decimal, {this.money = false});
  final String decimal;

  /// Shown with two decimals and thousands separators.
  final bool money;
}

/// A calendar day, stored as an Excel date serial and shown yyyy-mm-dd.
class XlsxDate extends XlsxCell {
  const XlsxDate(this.day);
  final DateTime day;
}

class XlsxEmpty extends XlsxCell {
  const XlsxEmpty();
}

/// The Excel serial of [day]: days since 1899-12-30, counted on the
/// calendar in UTC so a daylight-saving change never shifts a date.
int excelSerial(DateTime day) => DateTime.utc(
  day.year,
  day.month,
  day.day,
).difference(DateTime.utc(1899, 12, 30)).inDays;

/// Writes a one-sheet workbook with a bold header row, frozen under it.
///
/// A small hand-written writer rather than a package: the export needs text,
/// numbers and dates only, and inline strings keep the file readable by
/// Excel, LibreOffice, OnlyOffice and Google Sheets alike.
Uint8List buildXlsx({
  required String sheetName,
  required List<String> headers,
  required List<List<XlsxCell>> rows,
  List<int> columnWidths = const [],
}) {
  final archive = Archive();
  void add(String name, String content) =>
      archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));

  add('[Content_Types].xml', _contentTypes);
  add('_rels/.rels', _rootRels);
  add('xl/workbook.xml', _workbook(sheetName));
  add('xl/_rels/workbook.xml.rels', _workbookRels);
  add('xl/styles.xml', _styles);
  add('xl/worksheets/sheet1.xml', _sheet(headers, rows, columnWidths));

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

// Style indexes in [_styles]' cellXfs.
const _header = 1;
const _date = 2;
const _money = 3;

String _sheet(
  List<String> headers,
  List<List<XlsxCell>> rows,
  List<int> widths,
) {
  final out = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/'
      'spreadsheetml/2006/main">',
    )
    ..write(
      '<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" '
      'state="frozen"/></sheetView></sheetViews>',
    );
  if (widths.isNotEmpty) {
    out.write('<cols>');
    for (var i = 0; i < widths.length; i++) {
      out.write(
        '<col min="${i + 1}" max="${i + 1}" '
        'width="${widths[i]}" customWidth="1"/>',
      );
    }
    out.write('</cols>');
  }
  out.write('<sheetData>');
  out.write('<row r="1">');
  for (var c = 0; c < headers.length; c++) {
    out.write(_text('${_column(c)}1', headers[c], style: _header));
  }
  out.write('</row>');
  for (var r = 0; r < rows.length; r++) {
    final rowNumber = r + 2;
    out.write('<row r="$rowNumber">');
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final ref = '${_column(c)}$rowNumber';
      out.write(switch (row[c]) {
        XlsxText(:final value) => _text(ref, value),
        XlsxNumber(:final decimal, :final money) =>
          '<c r="$ref"${money ? ' s="$_money"' : ''}><v>$decimal</v></c>',
        XlsxDate(:final day) =>
          '<c r="$ref" s="$_date"><v>${excelSerial(day)}</v></c>',
        XlsxEmpty() => '',
      });
    }
    out.write('</row>');
  }
  out.write('</sheetData></worksheet>');
  return out.toString();
}

String _text(String ref, String value, {int? style}) =>
    '<c r="$ref"${style == null ? '' : ' s="$style"'} t="inlineStr">'
    '<is><t xml:space="preserve">${_escape(value)}</t></is></c>';

/// A, B, ... Z, AA ...
String _column(int index) {
  var n = index + 1;
  var name = '';
  while (n > 0) {
    final rem = (n - 1) % 26;
    name = String.fromCharCode(65 + rem) + name;
    n = (n - 1) ~/ 26;
  }
  return name;
}

/// Escapes XML's special characters and drops the control characters XML
/// 1.0 cannot carry at all (a stray one would make the file unreadable).
String _escape(String value) => value
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _workbook(String sheetName) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="${_escape(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
    '</workbook>';

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

const _workbookRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<numFmts count="1"><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/></numFmts>'
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="4">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';
