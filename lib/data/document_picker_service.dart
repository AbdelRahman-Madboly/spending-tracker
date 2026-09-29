import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_storage.dart';

/// A document copied into app storage: where it is now, and the name it
/// had when picked, which is what the attachment shows.
class PickedDocument {
  const PickedDocument({required this.relativePath, required this.name});

  final String relativePath;
  final String name;
}

/// Picks a PDF (an invoice, a packing slip) to keep as a `file` attachment
/// (spec §6.2). Behind an interface for the same reason as
/// `PhotoCaptureService`: the picker is a platform channel that does not
/// run under `flutter test`.
abstract class DocumentPickerService {
  /// Null when the user backed out.
  Future<PickedDocument?> pickPdf();
}

class FilePickerDocumentService implements DocumentPickerService {
  @override
  Future<PickedDocument?> pickPdf() async {
    // The system document picker needs no storage permission.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked == null) return null;
    final documents = await getApplicationDocumentsDirectory();
    final storage = PhotoStorage(documents);
    final local = picked.path;
    final String relativePath;
    if (local != null) {
      relativePath = await storage.importFile(File(local));
    } else {
      // A content URI with no file behind it: copy its bytes out first.
      final temp = File(p.join(
          (await getTemporaryDirectory()).path, 'pick-${picked.name}'));
      await temp.writeAsBytes(await picked.xFile.readAsBytes());
      relativePath = await storage.importFile(temp);
      await temp.delete();
    }
    return PickedDocument(relativePath: relativePath, name: picked.name);
  }
}
