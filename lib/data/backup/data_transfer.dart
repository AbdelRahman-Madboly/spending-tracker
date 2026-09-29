import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../domain/spending_repository.dart';
import '../db/database.dart';
import '../export/spending_export.dart';
import 'backup_service.dart';

/// Where exported files go and where a backup to restore comes from: the
/// system's own save and open screens (Android's Storage Access Framework),
/// so the user chooses the folder or app and no storage permission is
/// needed. Behind an interface because the picker is a platform channel
/// that does not run under `flutter test`.
abstract class DataFiles {
  /// False when the user backed out of the save screen.
  Future<bool> save(String fileName, Uint8List bytes, String mimeType);

  /// A local copy of the picked zip, or null when the user backed out.
  Future<File?> pickBackup();
}

class PickerDataFiles implements DataFiles {
  const PickerDataFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes, String mimeType) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    return uri != null;
  }

  @override
  Future<File?> pickBackup() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (picked == null) return null;
    if (picked.path case final path?) return File(path);
    // A content URI with no file behind it: copy its bytes out first.
    final temp = await Directory.systemTemp.createTemp('restore-pick');
    final copy = File(p.join(temp.path, 'backup.zip'));
    await copy.writeAsBytes(await picked.xFile.readAsBytes());
    return copy;
  }
}

/// The part of the app that owns the open database: backup reads it, and
/// restore needs it closed while the files are swapped, then opened again
/// (which also migrates a backup taken on an older schema).
abstract class DatabaseHost {
  AppDatabase get database;

  Future<Directory> documentsDirectory();

  /// Closes the database, runs [whileClosed], and opens it again, even
  /// when [whileClosed] throws. Every screen reading the old database is
  /// rebuilt against the new one.
  Future<void> reopenAfter(Future<void> Function() whileClosed);
}

/// Makes the app's [DatabaseHost] reachable from Settings.
class DatabaseHostScope extends InheritedWidget {
  const DatabaseHostScope({
    super.key,
    required this.host,
    required super.child,
  });

  final DatabaseHost host;

  static DatabaseHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DatabaseHostScope>()?.host;

  @override
  bool updateShouldNotify(DatabaseHostScope oldWidget) =>
      host != oldWidget.host;
}

const xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Settings -> البيانات: export, backup and restore, each ending in the
/// system save or open screen.
class DataTransfer {
  DataTransfer({
    required this.host,
    required this.repository,
    this.files = const PickerDataFiles(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DatabaseHost host;

  /// Read each time: after a restore the app has a new repository.
  final SpendingRepository Function() repository;
  final DataFiles files;
  final DateTime Function() _clock;

  Future<BackupService> _service() async =>
      BackupService(documents: await host.documentsDirectory(), clock: _clock);

  Future<ExportPeriods> exportPeriods() =>
      SpendingExporter(repository()).availablePeriods();

  /// Builds the workbook for [scope] and hands it to the save screen.
  /// False when the user cancelled.
  Future<bool> exportWorkbook(ExportScope scope) async {
    final bytes = await SpendingExporter(repository()).workbook(scope);
    return files.save(scope.fileName, bytes, xlsxMimeType);
  }

  /// Writes a full backup and hands it to the save screen. False when the
  /// user cancelled. The temporary zip is removed either way.
  Future<bool> backupNow() async {
    final service = await _service();
    final temp = await Directory.systemTemp.createTemp('masarify-out');
    try {
      final name = 'masarify-backup-${_stamp(_clock())}.zip';
      final zip = await service.createBackup(
        host.database,
        File(p.join(temp.path, name)),
      );
      return await files.save(name, await zip.readAsBytes(), 'application/zip');
    } finally {
      await temp.delete(recursive: true);
    }
  }

  /// Lets the user pick a backup and checks it, changing nothing yet.
  /// Null when they backed out; throws [BackupFormatException] for a file
  /// that is not a usable backup.
  Future<StagedRestore?> pickAndStage() async {
    final zip = await files.pickBackup();
    if (zip == null) return null;
    return (await _service()).stageRestore(zip);
  }

  /// Drops a staged backup the user decided not to restore.
  Future<void> discard() async => (await _service()).discardStaged();

  /// Restores [staged] once the user confirmed: first a full backup of the
  /// current data into `backups/` (if that fails, nothing is replaced),
  /// then the swap with the database closed. Returns the automatic backup.
  Future<File> restore(StagedRestore staged) async {
    final service = await _service();
    final File before;
    try {
      before = await service.preRestoreBackup(host.database);
    } catch (_) {
      await service.discardStaged();
      rethrow;
    }
    await host.reopenAfter(() => service.applyRestore(staged));
    return before;
  }
}

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      '-${two(t.hour)}${two(t.minute)}${two(t.second)}';
}
