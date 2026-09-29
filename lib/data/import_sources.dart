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

/// The system document picker, for a JSON pack, an `.sdocx` or a text
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

/// Something shared into the app from another one: text, or a file.
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
    for (final s in initial) {
      final share = await _read(s);
      if (share != null) yield share;
    }
    await for (final batch in intent.getMediaStream().handleError(
      (Object _) {},
    )) {
      for (final s in batch) {
        final share = await _read(s);
        if (share != null) yield share;
      }
    }
  }

  static Future<SharedImport?> _read(SharedMediaFile media) async {
    try {
      if (media.type == SharedMediaType.text ||
          media.type == SharedMediaType.url) {
        return SharedText(media.path);
      }
      if (media.type != SharedMediaType.file) return null;
      final file = File(media.path);
      return SharedFile(p.basename(media.path), await file.readAsBytes());
    } on Object {
      return null;
    }
  }
}
