import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Spec §6.2: photos are stored downscaled to 1600px on the long edge at
/// JPEG quality 85. For the camera and the gallery image_picker does the
/// scaling (it keeps the aspect ratio inside both bounds); an image shared
/// in from another app goes through [PhotoStorage.importImage].
const double photoMaxEdge = 1600;
const int photoJpegQuality = 85;

/// Copies a picked photo or document into the app's documents directory
/// under `attachments/<yyyy-MM>/` (spec §5) and hands back a path RELATIVE
/// to that directory.
///
/// Only a relative path is ever stored on an entry — Android can reassign
/// the app's data directory on restore, which would silently break an
/// absolute path saved today. Photos attached before v3 live under
/// `photos/`; they are relative paths too and resolve the same way.
class PhotoStorage {
  const PhotoStorage(this.documentsDirectory, {this.clock = DateTime.now});

  final Directory documentsDirectory;

  /// Picks the month folder a new file goes into.
  final DateTime Function() clock;

  /// Copies [source] into this month's attachments folder under a
  /// generated, collision-free filename and returns the path of the copy
  /// relative to [documentsDirectory] (e.g. `attachments/2026-09/172...jpg`).
  Future<String> importPhoto(File source) =>
      _import(source, fallbackExtension: '.jpg');

  /// As [importPhoto], for an image another app shared in (a screenshot,
  /// a gallery photo): stored as the camera's photos are, JPEG at quality
  /// 85, no more than 1600px on its long edge. A file the decoder cannot
  /// read (a format it does not know) is kept as it came.
  Future<String> importImage(File source) async {
    final bytes = await source.readAsBytes();
    final jpeg = await Isolate.run(() => _downscaledJpeg(bytes));
    if (jpeg == null) return importFile(source);
    return importBytes(jpeg, fileName: 'shared.jpg');
  }

  static List<int>? _downscaledJpeg(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on Object {
      return null;
    }
    if (decoded == null) return null;
    final edge = photoMaxEdge.toInt();
    final image = decoded.width <= edge && decoded.height <= edge
        ? decoded
        : decoded.width >= decoded.height
            ? img.copyResize(decoded, width: edge)
            : img.copyResize(decoded, height: edge);
    return img.encodeJpg(image, quality: photoJpegQuality);
  }

  /// As [importPhoto], for a document (a PDF invoice): the file is kept as
  /// it is, with its own extension in lower case.
  Future<String> importFile(File source) =>
      _import(source, fallbackExtension: '');

  /// As [importFile], for a file that is bytes in memory rather than on
  /// disk (an import pack's evidence, read from the bundled assets):
  /// [fileName] gives only the extension.
  Future<String> importBytes(List<int> bytes, {required String fileName}) async {
    final (destination, relativePath) =
        await _destination(p.extension(fileName).toLowerCase());
    await destination.writeAsBytes(bytes, flush: true);
    return relativePath;
  }

  Future<String> _import(File source, {required String fallbackExtension}) async {
    var extension = p.extension(source.path).toLowerCase();
    if (extension.isEmpty) extension = fallbackExtension;
    final (destination, relativePath) = await _destination(extension);
    await source.copy(destination.path);
    return relativePath;
  }

  /// A fresh file in this month's attachments folder, and its path
  /// relative to [documentsDirectory].
  Future<(File, String)> _destination(String extension) async {
    final now = clock();
    final month = now.month.toString().padLeft(2, '0');
    final folder = p.join('attachments', '${now.year}-$month');
    final targetDir = Directory(p.join(documentsDirectory.path, folder));
    await targetDir.create(recursive: true);

    // Two files in the same microsecond (a multi-pick) would collide on the
    // clock alone: step past any name already taken.
    var stamp = DateTime.now().microsecondsSinceEpoch;
    var destination = File(p.join(targetDir.path, '$stamp$extension'));
    while (await destination.exists()) {
      stamp++;
      destination = File(p.join(targetDir.path, '$stamp$extension'));
    }
    return (destination, p.join(folder, '$stamp$extension'));
  }

  /// Resolves a relative path previously returned by [importPhoto] or
  /// [importFile] back into the absolute [File] it lives at right now.
  File resolve(String relativePath) =>
      File(p.join(documentsDirectory.path, relativePath));

  /// Deletes a previously imported file, if it still exists. Used to clean
  /// up a photo that was attached during a sheet but never ended up saved,
  /// or one refused as a duplicate — safe to call when the file is gone.
  Future<void> delete(String relativePath) async {
    final file = resolve(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
