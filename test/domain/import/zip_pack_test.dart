import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/domain/import/importer.dart';
import 'package:spending_tracker/domain/import/note_import.dart';
import 'package:spending_tracker/domain/parsing/line_parser.dart';

import '../parsing/parser_catalogue_fixture.dart';

/// A pack as the manual one is written (`assets/import/manual_2026-09.json`),
/// small: two rows of one order with its evidence, a new subcategory, a
/// salary with its own evidence.
const _pack = {
  'format': 'manual-import/1',
  'salaryPeriods': [
    {
      'ref': 'sal-2026-10-23',
      'datePaid': '2026-09-23',
      'amountPiastres': 900000,
      'evidencePhotoPath': 'evidence/salary.jpeg',
      'note': 'InstaPay reference SAMPLE-0001',
    },
  ],
  'entries': [
    {
      'ref': 'z-001',
      'date': '2026-09-20',
      'amountPiastres': 4500,
      'description': 'دوا',
      'categoryKey': 'Health',
      'subcategoryKey': 'Medicine',
      'paymentMethod': 'InstaPay',
      'reference': '833754342999',
      'captureGroup': 'order-1',
      'evidencePhotoPath': 'evidence/order-1.jpeg',
      'flags': ['category: new catalogue addition, see catalogueAdditions'],
    },
    {
      'ref': 'z-002',
      'date': '2026-09-20',
      'amountPiastres': 1500,
      'description': 'بلاستر',
      'categoryKey': 'Health',
      'subcategoryKey': 'Medicine',
      'paymentMethod': 'InstaPay',
      'captureGroup': 'order-1',
      'evidencePhotoPath': 'evidence/order-1.jpeg',
    },
  ],
  'catalogueAdditions': {
    'categories': [
      {
        'key': 'Health',
        'labelAr': 'صحة',
        'iconName': 'medication',
        'colorKey': 'Health',
      },
    ],
    'subcategories': [
      {
        'key': 'Medicine',
        'categoryKey': 'Health',
        'labelAr': 'أدوية',
        'iconName': 'medication',
      },
    ],
  },
};

Uint8List _zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: bytes) in files.entries) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

final _packZip = _zip({
  'manual_2026-10.json': utf8.encode(jsonEncode(_pack)),
  'evidence/order-1.jpeg': [1, 1, 1],
  'evidence/salary.jpeg': [2, 2],
});

final _now = DateTime(2026, 9, 29, 12);
final _parser = ArabicLineParser(parserCatalogueFixture());

void main() {
  test('a zip is read as the pack JSON at its root, named by that file', () {
    final pack = packFromFile(
      'pack_from_phone.zip',
      _packZip,
      parser: _parser,
      now: _now,
    );
    expect(pack.fileName, 'manual_2026-10.json');
    expect(
      [for (final r in pack.rows) r.externalId],
      ['pack:manual_2026-10.json:z-001', 'pack:manual_2026-10.json:z-002'],
    );
    expect(pack.rows.first.reference, '833754342999');
    expect(
      pack.salaries.single.externalId,
      'pack:manual_2026-10.json:sal-2026-10-23',
    );
    expect(pack.additions.categories.single.key, 'Health');
  });

  test('evidence paths resolve to files inside the zip', () async {
    final pack = packFromFile('p.zip', _packZip, parser: _parser, now: _now);
    final read = pack.readEvidence!;
    expect(await read('evidence/order-1.jpeg'), [1, 1, 1]);
    expect(await read('./evidence/salary.jpeg'), [2, 2]);
    expect(await read('evidence/missing.jpeg'), isNull);
  });

  test('a path escaping the zip is refused', () async {
    final zip = _zip({
      'pack.json': utf8.encode(jsonEncode(_pack)),
      'evidence/a.jpeg': [1],
    });
    final read = packFromFile(
      'p.zip',
      zip,
      parser: _parser,
      now: _now,
    ).readEvidence!;
    expect(await read('../pack.json'), isNull);
    expect(await read('evidence/../../etc/passwd'), isNull);
    expect(await read('/evidence/a.jpeg'), isNull);
    expect(await read(r'evidence\..\..\x'), isNull);
  });

  test('a zip with no pack JSON at its root, or two, is not an import', () {
    expect(
      () => packFromFile(
        'p.zip',
        _zip({
          'evidence/a.jpeg': [1],
        }),
        parser: _parser,
        now: _now,
      ),
      throwsFormatException,
    );
    expect(
      () => packFromFile(
        'p.zip',
        _zip({
          'a.json': utf8.encode(jsonEncode(_pack)),
          'b.json': utf8.encode(jsonEncode(_pack)),
        }),
        parser: _parser,
        now: _now,
      ),
      throwsFormatException,
    );
    expect(
      () => packFromFile(
        'p.zip',
        Uint8List.fromList([1, 2, 3]),
        parser: _parser,
        now: _now,
      ),
      throwsFormatException,
    );
  });

  test('importing it copies the zip\'s evidence in, once, and a second run '
      'adds nothing', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftSpendingRepository(db);
    final saved = <(String, List<int>)>[];
    final importer = Importer(
      repo,
      // The bundled assets have none of this pack's evidence.
      readEvidence: (_) async => null,
      saveEvidence: (bytes, name) async {
        saved.add((name, bytes));
        return 'attachments/2026-09/${saved.length}.jpeg';
      },
    );
    Future<ImportSummary> run() async {
      final pack = packFromFile('p.zip', _packZip, parser: _parser, now: _now);
      final review = await importer.review(pack);
      return importer.apply(
        pack,
        review.items.where((i) => i.selectedByDefault).toList(),
      );
    }

    final first = await run();
    expect(first.entries, 2);
    expect(first.salaries, 1);
    expect(
      [for (final (name, _) in saved) name],
      ['order-1.jpeg', 'salary.jpeg'],
    );
    expect(
      [for (final (_, bytes) in saved) bytes.toList()],
      [
        [1, 1, 1],
        [2, 2],
      ],
    );
    expect(await repo.referenceExists('833754342999'), isTrue);
    final entries = await repo.watchEntriesForDay(DateTime(2026, 9, 20)).first;
    expect(entries, hasLength(2));
    final evidence = await repo.attachmentsForEntry(entries.first.id);
    expect(evidence.single.path, 'attachments/2026-09/1.jpeg');

    final second = await run();
    expect(second.entries + second.salaries, 0);
    expect(saved, hasLength(2));
  });
}
