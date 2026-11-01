import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/import/import_pack.dart';
import 'package:spending_tracker/domain/import/import_review.dart';
import 'package:spending_tracker/domain/models.dart';

ImportRow _row(
  String ref, {
  int? amount = 4500,
  String? category = 'Transport',
  String? subcategory,
  String? item,
  String description = 'تاكسي',
  DateTime? date,
  String? reference,
  List<String> flags = const [],
  String? evidence,
  String? group,
}) =>
    ImportRow(
      externalId: 'pack:p.json:$ref',
      ref: ref,
      date: date ?? DateTime(2026, 9, 8),
      amountPiastres: amount,
      categoryKey: category,
      subcategoryKey: subcategory,
      itemId: item,
      description: description,
      reference: reference,
      flags: flags,
      evidence: evidence,
      groupKey: group ?? 'row:$ref',
    );

TransactionView _entry({
  required DateTime date,
  required int amount,
  String description = '',
  String? item,
}) =>
    TransactionView(
      id: 'e-${date.day}-$amount',
      date: date,
      createdAt: date,
      amountPiastres: amount,
      categoryKey: 'Transport',
      categoryLabelAr: 'مواصلات',
      description: description,
      itemNameAr: item,
      paymentMethod: 'Cash',
      source: EntrySource.manual,
    );

ImportContext _context({
  Set<String> externalIds = const {},
  Set<String> references = const {},
  List<TransactionView> entries = const [],
  List<(DateTime, int)> salaries = const [],
}) =>
    ImportContext(
      knownExternalIds: externalIds,
      knownReferences: references,
      entries: entries,
      salaries: salaries,
      categoryKeys: const {'Transport', 'Food', 'Shopping'},
      subcategoryCategories: const {'Taxi': 'Transport', 'Lunch': 'Food'},
      itemIds: const {'item-07'},
    );

void main() {
  test('a row nobody has seen is new and selected', () {
    final review = reviewImport(
        ImportPack(fileName: 'p.json', rows: [_row('a')]), _context());
    final item = review.items.single;
    expect(item.state, ImportRowState.fresh);
    expect(item.selectable, isTrue);
    expect(item.selectedByDefault, isTrue);
  });

  test('a row with flags is flagged, still selected, flags kept', () {
    final review = reviewImport(
      ImportPack(fileName: 'p.json', rows: [
        _row('a', flags: ['date_ambiguous'])
      ]),
      _context(),
    );
    final item = review.items.single;
    expect(item.state, ImportRowState.flagged);
    expect(item.selectedByDefault, isTrue);
    expect(item.row!.flags, ['date_ambiguous']);
  });

  test('a row already imported cannot be selected', () {
    final review = reviewImport(
      ImportPack(fileName: 'p.json', rows: [_row('a')]),
      _context(externalIds: {'pack:p.json:a'}),
    );
    final item = review.items.single;
    expect(item.state, ImportRowState.duplicate);
    expect(item.selectable, isFalse);
    expect(item.problems.single, contains('اتستورد قبل كده'));
  });

  test('a row whose payment reference is recorded cannot be selected', () {
    final review = reviewImport(
      ImportPack(fileName: 'p.json', rows: [_row('a', reference: 'IP-1')]),
      _context(references: {'IP-1'}),
    );
    expect(review.items.single.state, ImportRowState.duplicate);
    expect(review.items.single.selectable, isFalse);
  });

  test('same day, amount and description is a duplicate left unselected',
      () {
    final review = reviewImport(
      ImportPack(fileName: 'p.json', rows: [
        _row('a', description: 'تاكسى'),
        _row('b', amount: 4000),
      ]),
      _context(entries: [
        _entry(date: DateTime(2026, 9, 8), amount: 4500, description: 'تاكسي'),
        // Named only by its item: the name a row shows is what counts.
        _entry(date: DateTime(2026, 9, 8), amount: 4000, item: 'تاكسي'),
      ]),
    );
    for (final item in review.items) {
      expect(item.state, ImportRowState.duplicate);
      expect(item.selectable, isTrue);
      expect(item.selectedByDefault, isFalse);
    }
  });

  test('a different day or amount is not a duplicate', () {
    final review = reviewImport(
      ImportPack(fileName: 'p.json', rows: [
        _row('a', date: DateTime(2026, 9, 9)),
        _row('b', amount: 3600),
      ]),
      _context(entries: [
        _entry(date: DateTime(2026, 9, 8), amount: 4500, description: 'تاكسي'),
      ]),
    );
    expect(review.items.map((i) => i.state).toSet(), {ImportRowState.fresh});
  });

  test('a row with no amount or no known category is incomplete', () {
    final review = reviewImport(
      ImportPack(fileName: 'p.json', rows: [
        _row('a', amount: null),
        _row('b', category: null),
        _row('c', category: 'Health'),
      ]),
      _context(),
    );
    for (final item in review.items) {
      expect(item.state, ImportRowState.incomplete);
      expect(item.selectable, isFalse);
    }
  });

  test('a catalogue addition makes its category and subcategory known', () {
    final review = reviewImport(
      ImportPack(
        fileName: 'p.json',
        rows: [_row('a', category: 'Health', subcategory: 'Medicine')],
        additions: const CatalogueAdditions(
          categories: [
            CategoryAddition(key: 'Health', labelAr: 'صحة', iconName: 'x')
          ],
          subcategories: [
            SubcategoryAddition(
                key: 'Medicine',
                categoryKey: 'Health',
                labelAr: 'أدوية',
                iconName: 'x'),
          ],
        ),
      ),
      _context(),
    );
    final item = review.items.single;
    expect(item.state, ImportRowState.fresh);
    expect(item.row!.subcategoryKey, 'Medicine');
  });

  test('an unknown item or subcategory is dropped, the row kept', () {
    final review = reviewImport(
      ImportPack(fileName: 'p.json', rows: [
        _row('a', item: 'item-99', subcategory: 'Lunch'),
      ]),
      _context(),
    );
    final row = review.items.single.row!;
    expect(row.itemId, isNull);
    // Lunch belongs to Food, not Transport.
    expect(row.subcategoryKey, isNull);
    expect(review.items.single.selectable, isTrue);
  });

  test('salaries: new, imported, or the same day and amount', () {
    final review = reviewImport(
      ImportPack(fileName: 'p.json', rows: const [], salaries: [
        ImportSalary(
            externalId: 's1',
            ref: 's1',
            datePaid: DateTime(2026, 9, 23),
            amountPiastres: 900000),
        ImportSalary(
            externalId: 's2',
            ref: 's2',
            datePaid: DateTime(2026, 9, 4),
            amountPiastres: 900000),
        ImportSalary(
            externalId: 's3',
            ref: 's3',
            datePaid: DateTime(2026, 8, 2),
            amountPiastres: 900000),
      ]),
      _context(externalIds: {'s2'}, salaries: [(DateTime(2026, 8, 2), 900000)]),
    );
    final states = [for (final i in review.items) (i.state, i.selectable)];
    expect(states, [
      (ImportRowState.fresh, true),
      (ImportRowState.duplicate, false),
      (ImportRowState.duplicate, true),
    ]);
  });

  group('importDrafts', () {
    test('one import capture per group, lines in order', () {
      final pack = ImportPack(
        fileName: 'p.json',
        rows: [
          _row('a', group: 'g1'),
          _row('b', group: 'g1', amount: 1500),
          _row('c', group: 'g2', date: DateTime(2026, 9, 9)),
        ],
        rawTextByGroup: const {'g1': '٤٥ تاكسي\n١٥ مترو'},
      );
      final drafts = importDrafts(pack, pack.rows);
      expect(drafts, hasLength(2));
      final first = drafts.first;
      expect(first.kind, CaptureKind.import);
      expect(first.date, DateTime(2026, 9, 8));
      expect(first.rawText, '٤٥ تاكسي\n١٥ مترو');
      expect(first.lines.map((l) => l.externalId),
          ['pack:p.json:a', 'pack:p.json:b']);
      expect(first.lines.map((l) => l.amountPiastres), [4500, 1500]);
      expect(drafts[1].date, DateTime(2026, 9, 9));
    });

    test('a reference shared by one order is kept on its first line', () {
      final pack = ImportPack(fileName: 'p.json', rows: [
        _row('a', group: 'g', reference: 'order 1'),
        _row('b', group: 'g', reference: 'order 1'),
      ]);
      final lines = importDrafts(pack, pack.rows).single.lines;
      expect(lines.map((l) => l.reference), ['order 1', null]);
    });

    test('each evidence file attaches once to its group, a PDF as a file',
        () {
      final pack = ImportPack(fileName: 'p.json', rows: [
        _row('a', group: 'g', evidence: 'evidence/slip.pdf'),
        _row('b', group: 'g', evidence: 'evidence/slip.pdf'),
        _row('c', group: 'h', evidence: 'evidence/shot.jpeg'),
        _row('d', group: 'i', evidence: 'evidence/missing.png'),
      ]);
      final drafts = importDrafts(pack, pack.rows, evidencePaths: const {
        'evidence/slip.pdf': 'attachments/2026-09/1.pdf',
        'evidence/shot.jpeg': 'attachments/2026-09/2.jpeg',
      });
      expect(drafts[0].attachments, const [
        DraftAttachment(
            kind: AttachmentKind.file, path: 'attachments/2026-09/1.pdf'),
      ]);
      expect(drafts[1].attachments, const [
        DraftAttachment(
            kind: AttachmentKind.photo, path: 'attachments/2026-09/2.jpeg'),
      ]);
      // An evidence file that could not be copied is left out.
      expect(drafts[2].attachments, isEmpty);
    });
  });
}
