import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../spending_repository.dart';
import 'import_pack.dart';
import 'import_review.dart';

/// The sample import packs shipped in `assets/import/`, in the order they
/// are imported.
const bundledPackFiles = [
  'samsung_notes_2026-09.json',
  'manual_2026-09.json',
];

/// The `app_settings` key set once the dashboard's offer to import the
/// bundled packs has been taken or dismissed.
const importOfferSettingKey = 'import_offer_done';

/// A file the user picked or shared to import: its name decides how it is
/// read (see `packFromFile`).
typedef PickedImportFile = ({String name, Uint8List bytes});

/// Reads an evidence file named relative to its pack's folder
/// (`evidence/...jpeg`); null when the pack came without it.
typedef EvidenceReader = Future<List<int>?> Function(String path);

/// Keeps evidence bytes in app storage; returns the stored relative path.
typedef EvidenceSaver =
    Future<String> Function(List<int> bytes, String fileName);

/// What one [Importer.apply] wrote.
class ImportSummary {
  final int entries;
  final int salaries;

  /// Rows or salaries the database refused (a reference or identity that
  /// turned up meanwhile). Nothing of a refused capture is written.
  final int failed;

  const ImportSummary({
    required this.entries,
    required this.salaries,
    required this.failed,
  });
}

/// Checks import packs against the database and writes what the user
/// confirmed (plan Task 13). Running an import twice adds nothing: every
/// row carries its `externalId`, and rows already present are skipped
/// again at write time, whatever the review said.
class Importer {
  final SpendingRepository repo;
  final EvidenceReader? readEvidence;
  final EvidenceSaver? saveEvidence;

  Importer(this.repo, {this.readEvidence, this.saveEvidence});

  /// What the database holds, for [reviewImport].
  Future<ImportContext> contextFor(ImportPack pack) async {
    final categories = [
      ...await repo.categories(),
      ...await repo.archivedCategories(),
    ];
    final subcategories = <String, String>{
      for (final c in categories)
        for (final s in await repo.subcategories(c.key)) s.key: s.categoryKey,
      for (final s in await repo.archivedSubcategories()) s.key: s.categoryKey,
    };
    final references = <String>{};
    for (final r in pack.rows) {
      final reference = r.reference;
      if (reference != null && await repo.referenceExists(reference)) {
        references.add(reference);
      }
    }
    return ImportContext(
      knownExternalIds: await repo.knownExternalIds(),
      knownReferences: references,
      entries: await repo.watchTransactions().first,
      salaries: [
        for (final period in await repo.watchPeriods().first)
          if (period.start != null) (period.start!, period.salaryPiastres),
      ],
      categoryKeys: {for (final c in categories) c.key},
      subcategoryCategories: subcategories,
      itemIds: {
        for (final i in await repo.allItems()) i.id,
        for (final i in await repo.archivedItems()) i.id,
      },
    );
  }

  Future<ImportReview> review(ImportPack pack) async =>
      reviewImport(pack, await contextFor(pack));

  /// Creates each category and subcategory of [additions] the catalogue
  /// lacks, by key, archived ones counting as present.
  Future<void> ensureCatalogue(CatalogueAdditions additions) async {
    final categories = {
      for (final c in await repo.categories()) c.key,
      for (final c in await repo.archivedCategories()) c.key,
    };
    for (final c in additions.categories) {
      if (categories.add(c.key)) {
        await repo.createCategory(
          key: c.key,
          labelAr: c.labelAr,
          iconName: c.iconName,
          colorKey: c.colorKey,
        );
      }
    }
    final subcategories = {
      for (final key in categories)
        for (final s in await repo.subcategories(key)) s.key,
      for (final s in await repo.archivedSubcategories()) s.key,
    };
    for (final s in additions.subcategories) {
      if (!categories.contains(s.categoryKey)) continue;
      if (subcategories.add(s.key)) {
        await repo.createSubcategory(
          key: s.key,
          categoryKey: s.categoryKey,
          labelAr: s.labelAr,
          iconName: s.iconName,
        );
      }
    }
  }

  /// Writes the [chosen] review items of [pack]: the catalogue additions
  /// first, then one capture per group with its evidence attached, then
  /// the salaries. Incomplete rows and anything already imported are
  /// skipped. A capture the database refuses is left out whole and
  /// counted in [ImportSummary.failed]; the rest still go in.
  Future<ImportSummary> apply(
    ImportPack pack,
    List<ImportReviewItem> chosen,
  ) async {
    await ensureCatalogue(pack.additions);
    final known = await repo.knownExternalIds();
    final rows = [
      for (final item in chosen)
        if (item.row case final row?)
          if (item.state != ImportRowState.incomplete &&
              row.amountPiastres != null &&
              row.categoryKey != null &&
              !known.contains(row.externalId))
            row,
    ];
    final salaries = [
      for (final item in chosen)
        if (item.salary case final salary?)
          if (!known.contains(salary.externalId)) salary,
    ];

    final evidence = <String, String>{};
    Future<String?> store(String? path) async {
      if (path == null) return null;
      if (evidence.containsKey(path)) return evidence[path];
      final read = readEvidence, save = saveEvidence;
      if (read == null || save == null) return null;
      final bytes = await read(path);
      if (bytes == null) return null;
      return evidence[path] = await save(bytes, p.basename(path));
    }

    for (final row in rows) {
      await store(row.evidence);
    }
    var entries = 0;
    var failed = 0;
    for (final draft in importDrafts(pack, rows, evidencePaths: evidence)) {
      try {
        await repo.saveCapture(draft);
        entries += draft.lines.length;
      } on Object {
        failed += draft.lines.length;
      }
    }
    var salaryCount = 0;
    for (final salary in salaries) {
      try {
        await repo.addSalaryPeriod(
          datePaid: salary.datePaid,
          amountPiastres: salary.amountPiastres,
          note: salary.note,
          evidencePhotoPath: await store(salary.evidence),
          externalId: salary.externalId,
        );
        salaryCount++;
      } on Object {
        failed++;
      }
    }
    return ImportSummary(
      entries: entries,
      salaries: salaryCount,
      failed: failed,
    );
  }
}

/// Every import item a user would get with nothing unticked.
List<ImportReviewItem> defaultSelection(ImportReview review) => [
  for (final i in review.items)
    if (i.selectedByDefault) i,
];
