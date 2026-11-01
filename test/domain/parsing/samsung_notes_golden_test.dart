import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/arabic_text.dart';
import 'package:spending_tracker/domain/parsing/line_parser.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';

import 'parser_catalogue_fixture.dart';

/// Golden test: every line of the sample Samsung notes must parse
/// to the amount, cleaned name, quantity and date recorded for it in
/// `assets/import/samsung_notes_2026-09.json`, which was checked by hand.
///
/// Names are compared after [normalizeArabic], so "باتية" and "باتيه" are
/// one name, and without the "(٣ أشخاص)" the import appended to its
/// descriptions: the parser returns the count as quantity and unit instead.
/// Quantity is checked except where the import inferred it from the price
/// (flag `quantity_inferred`), because then the text states none. Rows the
/// import skips (`skip: true`, a duplicate) are still checked: skipping is
/// the import's decision, and the parser must read the line all the same.
void main() {
  final parser = ArabicLineParser(parserCatalogueFixture());
  final json =
      jsonDecode(
            File('assets/import/samsung_notes_2026-09.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final rows = (json['entries'] as List).cast<Map<String, dynamic>>();
  final notes =
      Directory('test/fixtures/samsung_notes')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('every fixture note has rows in the import file', () {
    expect(notes, hasLength(5));
    final covered = rows.map((r) => r['sourceNote']).toSet();
    for (final note in notes) {
      expect(covered, contains(_stem(note)));
    }
  });

  for (final note in notes) {
    final stem = _stem(note);
    group(stem, () {
      final expected = rows.where((r) => r['sourceNote'] == stem).toList();
      final lines = parser.parse(
        note.readAsStringSync(),
        capturedAt: _createdAt(stem),
      );

      test('gives one line per recorded row', () {
        expect(
          lines.map((l) => l.rawText.trim()),
          expected.map((r) => r['rawText']),
        );
      });

      for (var i = 0; i < expected.length; i++) {
        final row = expected[i];
        test('${row['ref']}: ${row['rawText']}', () {
          final line = lines[i];
          expect(line.amountPiastres, row['amountPiastres'], reason: '$line');
          expect(
            normalizeArabic(line.name),
            normalizeArabic(_withoutCount(row['description'] as String)),
            reason: '$line',
          );
          final flags = (row['flags'] as List).cast<String>();
          if (!flags.any((f) => f.startsWith('quantity_inferred'))) {
            expect(
              line.quantityMilli,
              (row['quantity'] as int) * 1000,
              reason: '$line',
            );
          }
          expect(
            line.date,
            DateTime.parse(row['date'] as String),
            reason: '$line',
          );
          if (row['ref'] == 'sn-007') {
            expect(line.confidence, ParseConfidence.low);
          }
        });
      }
    });
  }
}

String _stem(File f) => f.uri.pathSegments.last.replaceAll('.txt', '');

/// `Notes_YYMMDD_HHMMSS` is when Samsung Notes created the note.
DateTime _createdAt(String stem) {
  final m = RegExp(r'(\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)').firstMatch(stem)!;
  int g(int i) => int.parse(m.group(i)!);
  return DateTime(2000 + g(1), g(2), g(3), g(4), g(5), g(6));
}

String _withoutCount(String description) =>
    description.replaceAll(RegExp(r'\s*\(.*\)$'), '');
