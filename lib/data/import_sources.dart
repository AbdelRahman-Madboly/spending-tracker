import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../domain/import/import_pack.dart';
import '../domain/import/importer.dart';
import '../domain/spending_repository.dart';
import 'photo_storage.dart';

export '../domain/import/importer.dart'
    show bundledPackFiles, importOfferSettingKey;

Future<List<ImportPack>> loadBundledPacks([AssetBundle? bundle]) async {
  final assets = bundle ?? rootBundle;
  return [
    for (final file in bundledPackFiles)
      parseImportPack(file, await assets.loadString('assets/import/$file')),
  ];
}

/// An importer that reads evidence from the bundled `assets/import/`
/// folder and copies it into app storage as attachments.
Importer appImporter(SpendingRepository repository, [AssetBundle? bundle]) {
  final assets = bundle ?? rootBundle;
  return Importer(
    repository,
    readEvidence: (path) async {
      // Only files under the pack's own evidence folder are read.
      final normalized = p.posix.normalize(path);
      if (normalized.startsWith('..') || p.posix.isAbsolute(normalized)) {
        return null;
      }
      try {
        final data = await assets.load('assets/import/$normalized');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } on Object {
        return null;
      }
    },
    saveEvidence: (bytes, name) async => PhotoStorage(
      await getApplicationDocumentsDirectory(),
    ).importBytes(bytes, fileName: name),
  );
}

/// The system document picker, for a JSON or zip pack, an `.sdocx` or a text
/// file. Null when the user backed out.
Future<PickedImportFile?> pickImportFile() async {
  final picked = await FilePicker.pickFile(type: FileType.any);
  if (picked == null) return null;
  final path = picked.path;
  final bytes = path != null
      ? await File(path).readAsBytes()
      : await picked.xFile.readAsBytes();
  return (name: picked.name, bytes: bytes);
}

/// Something shared into the app from another one: text or a file to
/// import, or images to read as a photo capture.
sealed class SharedImport {
  const SharedImport();
}

class SharedText extends SharedImport {
  final String text;
  const SharedText(this.text);
}

class SharedFile extends SharedImport {
  final String name;
  final Uint8List bytes;
  const SharedFile(this.name, this.bytes);
}

/// Images shared in one go (an InstaPay screenshot, gallery photos): the
/// files the share plugin copied into the cache, read as one photo
/// capture (spec §6.2).
class SharedImages extends SharedImport {
  final List<String> paths;
  const SharedImages(this.paths);
}

/// What other apps share into this one (the Android share target), as a
/// stream. Behind an interface since the plugin is a platform channel.
abstract class ShareInbox {
  /// What launched the app, then everything shared while it runs.
  Stream<SharedImport> get shares;
}

class PluginShareInbox implements ShareInbox {
  @override
  Stream<SharedImport> get shares async* {
    final intent = ReceiveSharingIntent.instance;
    final List<SharedMediaFile> initial;
    try {
      initial = await intent.getInitialMedia();
      await intent.reset();
    } on Object {
      // No share plugin on this platform (tests, desktop): nothing shared.
      return;
    }
    yield* Stream.fromIterable(await sharedImportsOf(initial));
    await for (final batch in intent.getMediaStream().handleError(
      (Object _) {},
    )) {
      yield* Stream.fromIterable(await sharedImportsOf(batch));
    }
  }
}

/// What one share holds: its text and files one by one, for import, and
/// its images together as one [SharedImages]. A file that cannot be read
/// and anything else (a video) are left out.
Future<List<SharedImport>> sharedImportsOf(List<SharedMediaFile> batch) async {
  final shares = <SharedImport>[];
  final images = <String>[];
  for (final media in batch) {
    switch (media.type) {
      case SharedMediaType.text || SharedMediaType.url:
        shares.add(SharedText(media.path));
      case SharedMediaType.image:
        images.add(media.path);
      case SharedMediaType.file:
        try {
          shares.add(
            SharedFile(
              p.basename(media.path),
              await File(media.path).readAsBytes(),
            ),
          );
        } on Object {
          // Gone from the cache, or unreadable: nothing to import.
        }
      case SharedMediaType.video:
        break;
    }
  }
  if (images.isNotEmpty) shares.add(SharedImages(images));
  return shares;
}
