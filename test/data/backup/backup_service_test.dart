import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spending_tracker/data/backup/backup_service.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/domain/models.dart';

void main() {
  late Directory docs;
  late File dbFile;
  late AppDatabase db;
  late BackupService service;

  AppDatabase open() => AppDatabase.forTesting(NativeDatabase(dbFile));

  Future<void> addEntry(AppDatabase db, String name) =>
      DriftSpendingRepository(db).saveCapture(
        CaptureDraft(
          kind: CaptureKind.text,
          date: DateTime(2026, 9, 20),
          lines: [
            CaptureLine(
              amountPiastres: 1250,
              categoryKey: 'Food',
              description: name,
            ),
          ],
        ),
      );

  Future<List<String>> descriptions(AppDatabase db) async =>
      (await DriftSpendingRepository(
        db,
      ).watchTransactions().first).map((t) => t.description).toList();

  File docFile(String relative) => File(p.join(docs.path, relative));

  Archive readZip(File zip) => ZipDecoder().decodeBytes(zip.readAsBytesSync());

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('backup-test');
    dbFile = File(p.join(docs.path, 'spending.sqlite'));
    db = open();
    await addEntry(db, 'طماطم');
    docFile('attachments/2026-09/1.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    docFile('photos/old.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([4, 5]);
    docFile('backups/pre-v3-20260101-000000.sqlite')
      ..createSync(recursive: true)
      ..writeAsStringSync('old');
    service = BackupService(
      documents: docs,
      clock: () => DateTime(2026, 9, 29, 14, 5, 9),
    );
  });

  tearDown(() async {
    await db.close();
    if (docs.existsSync()) await docs.delete(recursive: true);
  });

  group('createBackup', () {
    test('holds the database, a manifest, attachments and photos', () async {
      final zip = await service.createBackup(
        db,
        File(p.join(docs.path, '..', '${p.basename(docs.path)}.zip')),
      );
      addTearDown(() => zip.deleteSync());
      final archive = readZip(zip);
      final names = archive.files.where((f) => f.isFile).map((f) => f.name);
      expect(
        names,
        containsAll([
          'spending.sqlite',
          'backup.json',
          'attachments/2026-09/1.jpg',
          'photos/old.jpg',
        ]),
      );
      expect(names.where((n) => n.startsWith('backups/')), isEmpty);
      final manifest =
          jsonDecode(utf8.decode(archive.findFile('backup.json')!.content))
              as Map;
      expect(manifest['schemaVersion'], AppDatabase.latestSchemaVersion);
      expect(archive.findFile('attachments/2026-09/1.jpg')!.content, [1, 2, 3]);
    });

    test(
      'the copied database holds the data and no secret-looking setting',
      () async {
        // setSetting refuses these; write one behind its back to prove the
        // backup would still never carry it.
        await db.customStatement(
          "INSERT INTO app_settings (key, value) VALUES ('gemini_key', 'AIza-secret')",
        );
        await DriftSpendingRepository(db).setSetting('theme_mode', 'dark');
        final zip = await service.createBackup(
          db,
          File(p.join(docs.path, 'out', 'b.zip')),
        );
        final copy = File(p.join(docs.path, 'copy.sqlite'))
          ..writeAsBytesSync(readZip(zip).findFile('spending.sqlite')!.content);
        final copied = AppDatabase.forTesting(NativeDatabase(copy));
        addTearDown(copied.close);
        expect(await descriptions(copied), ['طماطم']);
        final repo = DriftSpendingRepository(copied);
        expect(await repo.setting('gemini_key'), isNull);
        expect(await repo.setting('theme_mode'), 'dark');
        expect(
          zip.readAsBytesSync().toString(),
          isNot(contains(utf8.encode('AIza-secret').toString())),
        );
      },
    );

    test('an automatic pre-restore backup lands in backups/', () async {
      final zip = await service.preRestoreBackup(db);
      expect(p.dirname(zip.path), p.join(docs.path, 'backups'));
      expect(p.basename(zip.path), 'pre-restore-20260929-140509.zip');
      expect(readZip(zip).findFile('spending.sqlite'), isNotNull);
    });
  });

  group('restore', () {
    late File backup;

    setUp(() async {
      backup = await service.createBackup(
        db,
        File(p.join(docs.path, 'backups', 'mine.zip')),
      );
    });

    test('brings back the database and attachments as they were', () async {
      await addEntry(db, 'بعد النسخة');
      docFile('attachments/2026-09/1.jpg').deleteSync();
      docFile('attachments/2026-09/new.jpg').writeAsBytesSync([9]);

      final staged = await service.stageRestore(backup);
      await db.close();
      File('${dbFile.path}-wal').writeAsStringSync('stale');
      await service.applyRestore(staged);
      db = open();

      expect(await descriptions(db), ['طماطم']);
      expect(docFile('attachments/2026-09/1.jpg').readAsBytesSync(), [1, 2, 3]);
      expect(docFile('attachments/2026-09/new.jpg').existsSync(), isFalse);
      expect(docFile('photos/old.jpg').existsSync(), isTrue);
      expect(File('${dbFile.path}-wal').existsSync(), isFalse);
      // The backups folder is never touched by a restore.
      expect(docFile('backups/mine.zip').existsSync(), isTrue);
      expect(
        docFile('backups/pre-v3-20260101-000000.sqlite').existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(docs.path, 'restore-staging')).existsSync(),
        isFalse,
      );
    });

    Future<File> zipOf(Map<String, List<int>> files) async {
      final archive = Archive();
      files.forEach(
        (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)),
      );
      final file = File(p.join(docs.path, 'bad.zip'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      return file;
    }

    List<int> dbBytes() => readZip(backup).findFile('spending.sqlite')!.content;
    final manifest = utf8.encode('{"format":"masarify-backup","version":1}');

    test('refuses a zip that is not a backup, touching nothing', () async {
      final notBackup = await zipOf({'hello.txt': utf8.encode('hi')});
      await expectLater(
        service.stageRestore(notBackup),
        throwsA(isA<BackupFormatException>()),
      );
      final noDb = await zipOf({'backup.json': manifest});
      await expectLater(
        service.stageRestore(noDb),
        throwsA(isA<BackupFormatException>()),
      );
      final junkDb = await zipOf({
        'backup.json': manifest,
        'spending.sqlite': utf8.encode('nope'),
      });
      await expectLater(
        service.stageRestore(junkDb),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await descriptions(db), ['طماطم']);
      expect(
        Directory(p.join(docs.path, 'restore-staging')).existsSync(),
        isFalse,
      );
    });

    test('refuses a database from a newer version of the app', () async {
      final bytes = List<int>.of(dbBytes());
      bytes[63] = AppDatabase.latestSchemaVersion + 1; // user_version, BE
      final newer = await zipOf({
        'backup.json': manifest,
        'spending.sqlite': bytes,
      });
      await expectLater(
        service.stageRestore(newer),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('refuses a backup format newer than this app reads', () async {
      final newer = await zipOf({
        'backup.json': utf8.encode('{"format":"masarify-backup","version":2}'),
        'spending.sqlite': dbBytes(),
      });
      await expectLater(
        service.stageRestore(newer),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('refuses a file that is not a zip at all', () async {
      final garbage = File(p.join(docs.path, 'x.zip'))
        ..writeAsStringSync('not a zip');
      await expectLater(
        service.stageRestore(garbage),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('never writes outside the documents folder', () async {
      final evil = await zipOf({
        'backup.json': manifest,
        'spending.sqlite': dbBytes(),
        'attachments/../../evil.txt': utf8.encode('x'),
      });
      await expectLater(
        service.stageRestore(evil),
        throwsA(isA<BackupFormatException>()),
      );
      expect(File(p.join(docs.parent.path, 'evil.txt')).existsSync(), isFalse);
    });
  });
}
