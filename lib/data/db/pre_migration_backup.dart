import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Thrown when the copy taken before a migration does not match the
/// original file. The caller must not go on to migrate: without a verified
/// copy there is nothing to roll back to if the migration goes wrong.
class PreMigrationBackupException implements IOException {
  const PreMigrationBackupException(this.message);

  final String message;

  @override
  String toString() => 'PreMigrationBackupException: $message';
}

/// Reads SQLite's `user_version` (drift's schema version) straight from
/// the file header, without opening the database.
///
/// Opening the file through sqlite just to ask would already be "opening
/// the database", which is exactly what must not happen before the backup
/// is taken. The header layout is fixed by the file format: the magic
/// string `SQLite format 3\0` at offset 0 and `user_version` as a 4-byte
/// big-endian integer at offset 60.
///
/// Returns null when the file does not exist or is not a SQLite database.
int? readUserVersion(File dbFile) {
  if (!dbFile.existsSync()) return null;
  final raf = dbFile.openSync();
  try {
    if (raf.lengthSync() < 100) return null;
    final header = raf.readSync(100);
    const magic = 'SQLite format 3\u0000';
    for (var i = 0; i < magic.length; i++) {
      if (header[i] != magic.codeUnitAt(i)) return null;
    }
    return ByteData.sublistView(header).getUint32(60, Endian.big);
  } finally {
    raf.closeSync();
  }
}

/// Copies [dbFile] to `<backupsDir>/pre-v<targetVersion>-<yyyyMMdd-HHmmss>.sqlite`
/// when its stored schema version is below [targetVersion], and returns the
/// copy. Returns null (and copies nothing) on a fresh install, for a file
/// drift has not initialised yet (`user_version` 0), or when the file is
/// already on [targetVersion].
///
/// Journal sidecars (`-wal`, `-journal`) are copied alongside when present,
/// because the main file alone may not hold the last committed writes after
/// a crash. Every copy's size is checked against its original; a mismatch
/// deletes all the copies and throws [PreMigrationBackupException].
Future<File?> backupBeforeMigration({
  required File dbFile,
  required Directory backupsDir,
  required int targetVersion,
  DateTime? now,
}) async {
  final version = readUserVersion(dbFile);
  if (version == null || version == 0 || version >= targetVersion) {
    return null;
  }

  await backupsDir.create(recursive: true);
  final base = 'pre-v$targetVersion-${_stamp(now ?? DateTime.now())}';
  var target = File(p.join(backupsDir.path, '$base.sqlite'));
  // Two opens in the same second (a crash loop, say) must never overwrite
  // the first, oldest copy: it is the one taken before anything went wrong.
  for (var n = 2; target.existsSync(); n++) {
    target = File(p.join(backupsDir.path, '$base-$n.sqlite'));
  }

  final copies = <File>[];
  try {
    await _copyVerified(dbFile, target, copies);
    for (final suffix in const ['-wal', '-journal']) {
      final sidecar = File('${dbFile.path}$suffix');
      if (sidecar.existsSync()) {
        await _copyVerified(sidecar, File('${target.path}$suffix'), copies);
      }
    }
  } on PreMigrationBackupException {
    // A sidecar can hold the last committed writes, so a short copy of one
    // is as bad as a short main file: drop the whole set, not just the
    // file that failed, so no half-backup is left looking usable.
    for (final copy in copies) {
      if (copy.existsSync()) await copy.delete();
    }
    rethrow;
  }
  return target;
}

/// Copies [source] to [target], records the copy in [copies], and throws
/// [PreMigrationBackupException] when the copy's size differs.
Future<void> _copyVerified(File source, File target, List<File> copies) async {
  await source.copy(target.path);
  copies.add(target);
  final expected = await source.length();
  final actual = await target.length();
  if (actual != expected) {
    throw PreMigrationBackupException(
        'backup of ${source.path} is $actual bytes, expected $expected');
  }
}

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      '-${two(t.hour)}${two(t.minute)}${two(t.second)}';
}
