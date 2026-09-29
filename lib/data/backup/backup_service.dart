import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../domain/models.dart';
import '../db/database.dart';
import '../db/pre_migration_backup.dart';

/// Thrown when a file picked for restore is not a backup this app can
/// read. Nothing has been changed when it is thrown.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// A backup unpacked and checked, waiting to replace the live data.
class StagedRestore {
  const StagedRestore(this.directory);

  final Directory directory;
}

const _manifestName = 'backup.json';
const _format = 'masarify-backup';

/// The folders under the documents directory that hold attachment files
/// (`photos/` is where pre-v3 photos live). A backup carries these and
/// nothing else besides the database: `backups/` would nest old backups
/// inside new ones, and the Gemini key is in secure storage, not on disk
/// here at all.
const _fileFolders = ['attachments', 'photos'];

/// Full backup and restore: the database plus the attachment folders, as
/// one zip.
///
/// The database is copied with `VACUUM INTO`, which SQLite runs as one
/// read transaction: the copy is a consistent snapshot even while the app
/// keeps writing, unlike copying the file (and its journal) byte by byte.
class BackupService {
  BackupService({
    required this.documents,
    this.dbFileName = 'spending.sqlite',
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Directory documents;
  final String dbFileName;
  final DateTime Function() _clock;

  Directory get _staging =>
      Directory(p.join(documents.path, 'restore-staging'));
  Directory get _previous =>
      Directory(p.join(documents.path, 'restore-previous'));

  /// Writes a full backup of [db] and the attachment folders to [target]
  /// and returns it.
  Future<File> createBackup(AppDatabase db, File target) async {
    final work = await Directory.systemTemp.createTemp('masarify-backup');
    try {
      final snapshot = File(p.join(work.path, dbFileName));
      await db.customStatement('VACUUM INTO ?', [snapshot.path]);
      _dropSecrets(snapshot);

      await target.parent.create(recursive: true);
      final partial = File('${target.path}.part');
      final encoder = ZipFileEncoder()..create(partial.path);
      try {
        await encoder.addFile(snapshot, dbFileName);
        final manifest = jsonEncode({
          'format': _format,
          'version': 1,
          'schemaVersion': readUserVersion(snapshot),
          'createdAt': _clock().toIso8601String(),
        });
        encoder.addArchiveFile(
          ArchiveFile.bytes(_manifestName, utf8.encode(manifest)),
        );
        for (final folder in _fileFolders) {
          final dir = Directory(p.join(documents.path, folder));
          if (!dir.existsSync()) continue;
          await for (final entity in dir.list(recursive: true)) {
            if (entity is! File) continue;
            final name = p.posix.joinAll(
              p.split(p.relative(entity.path, from: documents.path)),
            );
            await encoder.addFile(entity, name);
          }
        }
      } finally {
        await encoder.close();
      }
      // Only a finished zip ever takes the target's name.
      return await partial.rename(target.path);
    } finally {
      await work.delete(recursive: true);
    }
  }

  /// The automatic backup taken before a restore replaces anything:
  /// `backups/pre-restore-<yyyyMMdd-HHmmss>.zip`.
  Future<File> preRestoreBackup(AppDatabase db) {
    final base = 'pre-restore-${_stamp(_clock())}';
    final dir = p.join(documents.path, 'backups');
    var target = File(p.join(dir, '$base.zip'));
    for (var n = 2; target.existsSync(); n++) {
      target = File(p.join(dir, '$base-$n.zip'));
    }
    return createBackup(db, target);
  }

  /// Unpacks [zip] into a staging folder and checks it is a backup this
  /// app can open. Throws [BackupFormatException] (leaving no staging
  /// folder behind) when it is not. The live data is not touched.
  Future<StagedRestore> stageRestore(File zip) async {
    await discardStaged();
    await _staging.create(recursive: true);
    try {
      await _extract(zip);
      if (!File(p.join(_staging.path, _manifestName)).existsSync()) {
        throw const BackupFormatException('الملف ده مش نسخة احتياطية');
      }
      final manifest = _readManifest();
      if (manifest['format'] != _format) {
        throw const BackupFormatException('الملف ده مش نسخة احتياطية');
      }
      final formatVersion = manifest['version'];
      if (formatVersion is! int || formatVersion > 1) {
        throw const BackupFormatException('النسخة دي من إصدار أحدث من التطبيق');
      }
      final version = readUserVersion(File(p.join(_staging.path, dbFileName)));
      if (version == null || version == 0) {
        throw const BackupFormatException('النسخة مفيهاش قاعدة بيانات سليمة');
      }
      if (version > AppDatabase.latestSchemaVersion) {
        throw const BackupFormatException('النسخة دي من إصدار أحدث من التطبيق');
      }
      return StagedRestore(_staging);
    } catch (_) {
      await discardStaged();
      rethrow;
    }
  }

  /// Replaces the live database and attachment folders with [staged].
  /// The database must be closed first. On any failure the previous files
  /// are put back and the error is rethrown.
  ///
  /// A restored database on an older schema is migrated on the next open,
  /// with the usual pre-migration copy.
  Future<void> applyRestore(StagedRestore staged) async {
    if (_previous.existsSync()) await _previous.delete(recursive: true);
    await _previous.create(recursive: true);

    // Everything that is replaced, by name under the documents folder.
    final names = [
      dbFileName,
      for (final suffix in const ['-wal', '-shm', '-journal'])
        '$dbFileName$suffix',
      ..._fileFolders,
    ];
    final moved = <String>[];
    final placed = <String>[];
    try {
      for (final name in names) {
        final path = p.join(documents.path, name);
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.notFound) continue;
        await _rename(path, p.join(_previous.path, name), type);
        moved.add(name);
      }
      for (final name in [dbFileName, ..._fileFolders]) {
        final from = p.join(staged.directory.path, name);
        final type = FileSystemEntity.typeSync(from);
        if (type == FileSystemEntityType.notFound) continue;
        await _rename(from, p.join(documents.path, name), type);
        placed.add(name);
      }
    } catch (_) {
      // Put the staged pieces back where they came from, then the live
      // ones back in place, so the app opens on exactly what it had.
      for (final name in placed) {
        final path = p.join(documents.path, name);
        await _rename(
          path,
          p.join(staged.directory.path, name),
          FileSystemEntity.typeSync(path),
        );
      }
      for (final name in moved) {
        final from = p.join(_previous.path, name);
        await _rename(
          from,
          p.join(documents.path, name),
          FileSystemEntity.typeSync(from),
        );
      }
      rethrow;
    }
    await _previous.delete(recursive: true);
    await discardStaged();
  }

  /// Removes a staged restore that will not be applied.
  Future<void> discardStaged() async {
    if (_staging.existsSync()) await _staging.delete(recursive: true);
  }

  Future<void> _extract(File zip) async {
    final Archive archive;
    final input = InputFileStream(zip.path);
    try {
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw const BackupFormatException('الملف ده مش ملف zip سليم');
      }
      final root = p.canonicalize(_staging.path);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name;
        final parts = p.posix.split(name);
        final allowed =
            name == dbFileName ||
            name == _manifestName ||
            (parts.length > 1 && _fileFolders.contains(parts.first));
        final target = p.canonicalize(p.join(root, p.joinAll(parts)));
        if (p.posix.isAbsolute(name) ||
            parts.contains('..') ||
            !p.isWithin(root, target)) {
          throw const BackupFormatException('النسخة فيها مسارات غير سليمة');
        }
        if (!allowed) continue;
        await File(target).parent.create(recursive: true);
        final output = OutputFileStream(target);
        try {
          entry.writeContent(output);
        } finally {
          await output.close();
        }
      }
    } finally {
      await input.close();
    }
  }

  Map<String, Object?> _readManifest() {
    try {
      final decoded = jsonDecode(
        File(p.join(_staging.path, _manifestName)).readAsStringSync(),
      );
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Falls through to the refusal below.
    }
    throw const BackupFormatException('الملف ده مش نسخة احتياطية');
  }
}

/// Deletes any secret-looking setting from the snapshot and vacuums it, so
/// not even a freed page still holds the value. `app_settings` already
/// refuses such keys; this keeps a backup clean even if one slipped in.
void _dropSecrets(File snapshot) {
  final db = sqlite.sqlite3.open(snapshot.path);
  try {
    final keys = db
        .select('SELECT key FROM app_settings')
        .map((row) => row['key'] as String)
        .where(isSecretSettingKey)
        .toList();
    if (keys.isEmpty) return;
    for (final key in keys) {
      db.execute('DELETE FROM app_settings WHERE key = ?', [key]);
    }
    db.execute('VACUUM');
  } finally {
    db.close();
  }
}

Future<void> _rename(String from, String to, FileSystemEntityType type) async {
  await Directory(p.dirname(to)).create(recursive: true);
  if (type == FileSystemEntityType.directory) {
    await Directory(from).rename(to);
  } else {
    await File(from).rename(to);
  }
}

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      '-${two(t.hour)}${two(t.minute)}${two(t.second)}';
}
