import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/domain/import/import_pack.dart';
import 'package:spending_tracker/domain/import/importer.dart';
import 'package:spending_tracker/domain/models.dart';

const _bundled = [
  'samsung_notes_2026-09.json',
  'manual_2026-09.json',
];

ImportPack _pack(String file) =>
    parseImportPack(file, File('assets/import/$file').readAsStringSync());

void main() {
  late DriftSpendingRepository repo;
  late List<String> saved;
  late Importer importer;

  setUp(() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = DriftSpendingRepository(db);
    saved = [];
    importer = Importer(
      repo,
      readEvidence: (path) async {
        final file = File('assets/import/$path');
        return file.existsSync() ? file.readAsBytes() : null;
      },
      saveEvidence: (bytes, name) async {
        saved.add(name);
        return 'attachments/2026-09/${saved.length}${name.substring(name.lastIndexOf('.'))}';
      },
    );
  });

  Future<ImportSummary> importAll(ImportPack pack) async {
    final review = await importer.review(pack);
    return importer.apply(
        pack, review.items.where((i) => i.selectedByDefault).toList());
  }

  test('creates the packs\' missing categories and subcategories first',
      () async {
    final pack = _pack('samsung_notes_2026-09.json');
    await importAll(pack);
    final keys = (await repo.categories()).map((c) => c.key);
    for (final c in pack.additions.categories) {
      expect(keys, contains(c.key));
    }
    for (final s in pack.additions.subcategories) {
      final subs = await repo.subcategories(s.categoryKey);
      expect(subs.map((x) => x.key), contains(s.key));
    }
  });

  test('catalogue additions already present are not created twice', () async {
    final pack = _pack('samsung_notes_2026-09.json');
    await importer.ensureCatalogue(pack.additions);
    await importer.ensureCatalogue(pack.additions);
    final keys = (await repo.categories()).map((c) => c.key).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('every bundled row lands once, and a second run adds nothing',
      () async {
    var written = 0;
    var expected = 0;
    for (final file in _bundled) {
      final pack = _pack(file);
      final review = await importer.review(pack);
      final chosen =
          review.items.where((i) => i.selectedByDefault).toList();
      expected += chosen.where((i) => i.row != null).length;
      final summary = await importer.apply(pack, chosen);
      expect(summary.failed, 0, reason: file);
      written += summary.entries;
    }
    expect(written, expected);
    final entries = (await repo.watchTransactions().first).length;
    expect(entries, written);

    for (final file in _bundled) {
      final pack = _pack(file);
      final review = await importer.review(pack);
      expect(review.items.where((i) => i.selectedByDefault), isEmpty,
          reason: file);
      // Applying the whole list again anyway still writes nothing.
      final summary = await importer.apply(pack, review.items);
      expect(summary.entries + summary.salaries, 0, reason: file);
    }
    expect((await repo.watchTransactions().first).length, entries);
  });

  test('one manual order becomes one capture with its packing slip attached',
      () async {
    final pack = _pack('manual_2026-09.json');
    await importAll(pack);
    final entries = await repo.watchTransactions().first;
    final order = pack.rows
        .where((r) => r.groupKey.startsWith('group:sample-order-1001'))
        .map((r) => r.externalId)
        .toSet();
    expect(order.length, greaterThan(1));
    final ids = <String>[];
    for (final e in entries) {
      final record = await repo.entry(e.id);
      if (order.contains(record!.externalId)) ids.add(e.id);
    }
    expect(ids, hasLength(order.length));
    final groups = {
      for (final id in ids) (await repo.entry(id))!.captureGroupId,
    };
    expect(groups, hasLength(1));
    final attachments = await repo.attachmentsForEntry(ids.first);
    expect(
        attachments.where((a) => a.kind == AttachmentKind.file), hasLength(1));
    expect(saved.where((n) => n.endsWith('.pdf')), hasLength(1));
  });

  test('the manual pack\'s salary is recorded with its evidence', () async {
    final pack = _pack('manual_2026-09.json');
    final summary = await importAll(pack);
    expect(summary.salaries, 1);
    expect(await repo.knownExternalIds(),
        contains('pack:manual_2026-09.json:sal-2026-09-30'));
    expect(saved.where((n) => n.contains('Salary')), hasLength(1));
  });

  test('a row the user unticked is not written', () async {
    final pack = _pack('manual_2026-09.json');
    final review = await importer.review(pack);
    final chosen = review.items.where((i) => i.selectedByDefault).toList();
    final left = chosen.removeAt(0);
    await importer.apply(pack, chosen);
    final ids = await repo.knownExternalIds();
    expect(ids,
        isNot(contains(left.row?.externalId ?? left.salary!.externalId)));
  });
}
