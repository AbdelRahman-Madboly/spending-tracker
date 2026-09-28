import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/db/pre_migration_backup.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../generated_migrations/schema_v2.dart' as v2;

/// The file copy that runs before drift opens (and so before it migrates)
/// the database on the phone. The real history lives in that one file, so
/// a migration that goes wrong must always leave a readable copy behind.
void main() {
  late Directory root;
  late File dbFile;
  late Directory backupsDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pre_migration_backup');
    dbFile = File(p.join(root.path, 'spending.sqlite'));
    backupsDir = Directory(p.join(root.path, 'backups'));
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  void writeRawDatabase(int userVersion) {
    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('CREATE TABLE t (x INTEGER)');
    raw.execute('INSERT INTO t VALUES (1), (2), (3)');
    raw.execute('PRAGMA user_version = $userVersion');
    raw.close();
  }

  int userVersionOf(File file) {
    final raw = sqlite.sqlite3.open(file.path);
    final version =
        raw.select('PRAGMA user_version').single.columnAt(0) as int;
    raw.close();
    return version;
  }

  group('readUserVersion', () {
    test('reads user_version straight from the file header', () {
      writeRawDatabase(2);
      expect(readUserVersion(dbFile), 2);
    });

    test('is null for a missing file (fresh install)', () {
      expect(readUserVersion(dbFile), isNull);
    });

    test('is null for a file too short to hold a SQLite header', () {
      dbFile.writeAsBytesSync([1, 2, 3]);
      expect(readUserVersion(dbFile), isNull);
    });
  });

  group('backupBeforeMigration', () {
    test('copies a v2 file to backups/pre-v3-<yyyyMMdd-HHmmss>.sqlite',
        () async {
      writeRawDatabase(2);

      final backup = await backupBeforeMigration(
        dbFile: dbFile,
        backupsDir: backupsDir,
        targetVersion: 3,
        now: DateTime(2026, 9, 29, 7, 5, 9),
      );

      expect(backup, isNotNull);
      expect(backup!.path,
          p.join(backupsDir.path, 'pre-v3-20260929-070509.sqlite'));
      expect(backup.readAsBytesSync(), dbFile.readAsBytesSync());
      expect(userVersionOf(backup), 2);
    });

    test('also backs up a v1 file', () async {
      writeRawDatabase(1);

      final backup = await backupBeforeMigration(
        dbFile: dbFile,
        backupsDir: backupsDir,
        targetVersion: 3,
      );

      expect(backup, isNotNull);
      expect(userVersionOf(backup!), 1);
    });

    test('does nothing when the file is already on the target version',
        () async {
      writeRawDatabase(3);

      final backup = await backupBeforeMigration(
        dbFile: dbFile,
        backupsDir: backupsDir,
        targetVersion: 3,
      );

      expect(backup, isNull);
      expect(backupsDir.existsSync(), isFalse);
    });

    test('does nothing on a fresh install with no database file yet',
        () async {
      final backup = await backupBeforeMigration(
        dbFile: dbFile,
        backupsDir: backupsDir,
        targetVersion: 3,
      );

      expect(backup, isNull);
    });

    test('never overwrites an earlier backup taken in the same second',
        () async {
      writeRawDatabase(2);
      final at = DateTime(2026, 9, 29, 7, 5, 9);

      final first = await backupBeforeMigration(
          dbFile: dbFile, backupsDir: backupsDir, targetVersion: 3, now: at);
      final second = await backupBeforeMigration(
          dbFile: dbFile, backupsDir: backupsDir, targetVersion: 3, now: at);

      expect(first!.path, isNot(second!.path));
      expect(first.existsSync(), isTrue);
      expect(second.existsSync(), isTrue);
    });
  });

  test(
      'opening a v2 database file through the app connection leaves a '
      'pre-migration copy of the v2 data, then migrates the file to v3',
      () async {
    final old = v2.DatabaseAtV2(NativeDatabase(dbFile));
    await old.into(old.categories).insert(v2.CategoriesCompanion.insert(
        key: 'Food', labelAr: 'أكل', iconName: 'restaurant'));
    await old.into(old.entries).insert(v2.EntriesCompanion.insert(
          id: 'e1',
          date: '2026-09-01',
          amountPiastres: 2500,
          categoryKey: 'Food',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ));
    await old.close();
    expect(readUserVersion(dbFile), 2);

    final db = AppDatabase.forTesting(
      openDatabaseFileWithBackup(dbFile: dbFile, backupsDir: backupsDir),
    );
    final entries = await db.select(db.entries).get();
    await db.close();

    expect(entries.single.amountPiastres, 2500);
    expect(readUserVersion(dbFile), 3);

    final backups = backupsDir.listSync().whereType<File>().toList();
    expect(backups, hasLength(1));
    expect(p.basename(backups.single.path), startsWith('pre-v3-'));
    expect(userVersionOf(backups.single), 2);
    final copy = sqlite.sqlite3.open(backups.single.path);
    expect(copy.select('SELECT amount_piastres FROM entries').single.columnAt(0),
        2500);
    copy.close();
  });
}
