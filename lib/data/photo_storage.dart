import 'dart:io';

import 'package:path/path.dart' as p;

/// Copies a picked image into the app's documents directory under a
/// `photos/` subfolder and hands back a path RELATIVE to that directory.
///
/// Only a relative path is ever stored on an entry — Android can reassign
/// the app's data directory on restore, which would silently break an
/// absolute path saved today.
class PhotoStorage {
  const PhotoStorage(this.documentsDirectory);

  final Directory documentsDirectory;

  static const String subfolder = 'photos';

  /// Copies [source] into `<documentsDirectory>/photos/` under a
  /// generated, collision-free filename and returns the path of the copy
  /// relative to [documentsDirectory] (e.g. `photos/172...-0.jpg`).
  Future<String> importPhoto(File source) async {
    final targetDir = Directory(p.join(documentsDirectory.path, subfolder));
    await targetDir.create(recursive: true);

    var extension = p.extension(source.path);
    if (extension.isEmpty) extension = '.jpg';
    final filename =
        '${DateTime.now().microsecondsSinceEpoch}$extension';
    final destination = File(p.join(targetDir.path, filename));

    await source.copy(destination.path);
    return p.join(subfolder, filename);
  }

  /// Resolves a relative path previously returned by [importPhoto] (as
  /// stored in `DraftEntry.photoPath`) back into the absolute [File] it
  /// lives at right now.
  File resolve(String relativePath) =>
      File(p.join(documentsDirectory.path, relativePath));

  /// Deletes a previously imported photo, if it still exists. Used to
  /// clean up a photo that was attached during an add-sheet session but
  /// never ended up in a saved entry — safe to call even when the file is
  /// already gone.
  Future<void> delete(String relativePath) async {
    final file = resolve(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
