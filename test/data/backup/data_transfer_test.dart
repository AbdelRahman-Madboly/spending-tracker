import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spending_tracker/data/backup/backup_service.dart';
import 'package:spending_tracker/data/backup/data_transfer.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/data/export/spending_export.dart';
import 'package:spending_tracker/domain/models.dart';

class _Files implements DataFiles {
  final saved = <String, Uint8List>{};
  String? savedMime;
  bool cancelSave = false;
  File? toPick;

  @override
  Future<bool> save(String fileName, Uint8List bytes, String mimeType) async {
    if (cancelSave) return false;
    saved[fileName] = bytes;
    savedMime = mimeType;
    return true;
  }

  @override
  Future<File?> pickBackup() async => toPick;
}

/// Plays the app's part: owns the open database and reopens it.
class _Host implements DatabaseHost {
  _Host(this.docs) : database = _open(docs);

  final Directory docs;
  @override
  AppDatabase database;
  int reopened = 0;
  bool closedDuringSwap = false;

  static AppDatabase _open(Directory docs) => AppDatabase.forTesting(
    NativeDatabase(File(p.join(docs.path, 'spending.sqlite'))),
  );

  @override
  Future<Directory> documentsDirectory() async => docs;

  @override
  Future<void> reopenAfter(Future<void> Function() whileClosed) async {
    await database.close();
    try {
      await whileClosed();
    } finally {
      database = _open(docs);
      reopened++;
    }
  }
}

void main() {
  late Directory docs;
  late _Host host;
  late _Files files;
  late DataTransfer transfer;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  DriftSpendingRepository repo() => DriftSpendingRepository(host.database);

  Future<void> addEntry(String name) => repo().saveCapture(
    CaptureDraft(
      kind: CaptureKind.text,
      date: DateTime(2026, 9, 20),
      lines: [
        CaptureLine(
          amountPiastres: 500,
          categoryKey: 'Food',
          description: name,
        ),
      ],
    ),
  );

  Future<List<String>> names() async => (await repo().watchTransactions().first)
      .map((t) => t.description)
      .toList();

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('transfer-test');
    host = _Host(docs);
    files = _Files();
    transfer = DataTransfer(
      host: host,
      repository: repo,
      files: files,
      clock: () => DateTime(2026, 9, 29, 8, 1, 2),
    );
    await addEntry('قديم');
  });

  tearDown(() async {
    await host.database.close();
    await docs.delete(recursive: true);
  });

  test(
    'export saves the chosen scope as an xlsx where the user picks',
    () async {
      expect(
        await transfer.exportWorkbook(const ExportScope.month(2026, 9)),
        isTrue,
      );
      expect(files.saved.keys, ['masarify-2026-09.xlsx']);
      expect(
        files.savedMime,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final archive = ZipDecoder().decodeBytes(files.saved.values.single);
      expect(archive.findFile('xl/worksheets/sheet1.xml'), isNotNull);
    },
  );

  test(
    'a cancelled save reports it and leaves no temporary backup behind',
    () async {
      files.cancelSave = true;
      expect(await transfer.backupNow(), isFalse);
      final leftovers = docs
          .listSync(recursive: true)
          .where((e) => e.path.endsWith('.zip'));
      expect(leftovers, isEmpty);
    },
  );

  test('a backup is saved as a dated zip holding the database', () async {
    expect(await transfer.backupNow(), isTrue);
    final name = files.saved.keys.single;
    expect(name, 'masarify-backup-20260929-080102.zip');
    final archive = ZipDecoder().decodeBytes(files.saved[name]!);
    expect(archive.findFile('spending.sqlite'), isNotNull);
  });

  test('restore takes a pre-restore backup, then swaps the data in', () async {
    await transfer.backupNow();
    final zip = File(p.join(docs.parent.path, '${p.basename(docs.path)}.zip'))
      ..writeAsBytesSync(files.saved.values.single);
    addTearDown(zip.deleteSync);
    await addEntry('جديد');

    files.toPick = zip;
    final staged = await transfer.pickAndStage();
    expect(staged, isNotNull);
    expect(host.reopened, 0, reason: 'nothing changes before confirmation');

    final preRestore = await transfer.restore(staged!);

    expect(host.reopened, 1);
    expect(await names(), ['قديم']);
    expect(p.dirname(preRestore.path), p.join(docs.path, 'backups'));
    // The automatic backup holds the data as it was just before restoring.
    final before = File(p.join(docs.path, 'check.sqlite'))
      ..writeAsBytesSync(
        ZipDecoder()
            .decodeBytes(preRestore.readAsBytesSync())
            .findFile('spending.sqlite')!
            .content,
      );
    final beforeDb = AppDatabase.forTesting(NativeDatabase(before));
    addTearDown(beforeDb.close);
    final beforeNames = (await DriftSpendingRepository(
      beforeDb,
    ).watchTransactions().first).map((t) => t.description);
    expect(beforeNames, containsAll(['قديم', 'جديد']));
  });

  test('picking nothing stages nothing', () async {
    files.toPick = null;
    expect(await transfer.pickAndStage(), isNull);
  });

  test('an invalid file is refused before anything changes', () async {
    files.toPick = File(p.join(docs.path, 'x.zip'))..writeAsStringSync('no');
    await expectLater(
      transfer.pickAndStage(),
      throwsA(isA<BackupFormatException>()),
    );
    expect(host.reopened, 0);
    expect(await names(), ['قديم']);
  });
}
