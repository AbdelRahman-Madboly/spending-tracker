import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:spending_tracker/data/photo_storage.dart';

void main() {
  late Directory tempRoot;
  late Directory documentsDir;
  late PhotoStorage storage;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('photo_storage_test');
    documentsDir = Directory(p.join(tempRoot.path, 'app_documents'))
      ..createSync(recursive: true);
    storage = PhotoStorage(documentsDir, clock: () => DateTime(2026, 9, 29, 12));
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<File> writeSourceFile(String name, List<int> bytes) async {
    final file = File(p.join(tempRoot.path, name));
    await file.writeAsBytes(bytes);
    return file;
  }

  test('importPhoto copies the source file into attachments/<yyyy-MM>/',
      () async {
    final source = await writeSourceFile('picked.jpg', [1, 2, 3, 4]);

    final relativePath = await storage.importPhoto(source);

    final expectedDir =
        Directory(p.join(documentsDir.path, 'attachments', '2026-09'));
    expect(await expectedDir.exists(), isTrue);
    final copied = File(p.join(documentsDir.path, relativePath));
    expect(await copied.exists(), isTrue);
    expect(await copied.readAsBytes(), [1, 2, 3, 4]);
  });

  test('importPhoto returns a path relative to the documents directory',
      () async {
    final source = await writeSourceFile('picked.png', [9, 9, 9]);

    final relativePath = await storage.importPhoto(source);

    expect(p.isAbsolute(relativePath), isFalse);
    expect(relativePath,
        startsWith(p.join('attachments', '2026-09') + p.separator));
  });

  test('importPhoto keeps the source file extension', () async {
    final source = await writeSourceFile('picked.PNG', [1]);

    final relativePath = await storage.importPhoto(source);

    expect(p.extension(relativePath).toLowerCase(), '.png');
  });

  test('importPhoto falls back to .jpg when the source has no extension',
      () async {
    final source = await writeSourceFile('picked_no_ext', [1]);

    final relativePath = await storage.importPhoto(source);

    expect(p.extension(relativePath), '.jpg');
  });

  test('importPhoto generates distinct filenames for successive imports',
      () async {
    final sourceA = await writeSourceFile('a.jpg', [1]);
    final sourceB = await writeSourceFile('b.jpg', [2]);

    final pathA = await storage.importPhoto(sourceA);
    final pathB = await storage.importPhoto(sourceB);

    expect(pathA, isNot(equals(pathB)));
  });

  test('a photo stored before v3 under photos/ still resolves', () async {
    final old = File(p.join(documentsDir.path, 'photos', 'old.jpg'))
      ..createSync(recursive: true);

    expect(storage.resolve('photos/old.jpg').path, old.path);
  });

  test('importFile keeps a document as it is, with its extension', () async {
    final source = await writeSourceFile('Invoice 12.PDF', [5, 6]);

    final relativePath = await storage.importFile(source);

    expect(relativePath,
        startsWith(p.join('attachments', '2026-09') + p.separator));
    expect(p.extension(relativePath), '.pdf');
    expect(await storage.resolve(relativePath).readAsBytes(), [5, 6]);
  });

  test('resolve turns a stored relative path back into the absolute file',
      () async {
    final source = await writeSourceFile('picked.jpg', [7, 7]);
    final relativePath = await storage.importPhoto(source);

    final resolved = storage.resolve(relativePath);

    expect(resolved.path, p.join(documentsDir.path, relativePath));
    expect(await resolved.exists(), isTrue);
  });

  test('delete removes a previously imported photo from disk', () async {
    final source = await writeSourceFile('picked.jpg', [1, 2, 3]);
    final relativePath = await storage.importPhoto(source);
    expect(await storage.resolve(relativePath).exists(), isTrue);

    await storage.delete(relativePath);

    expect(await storage.resolve(relativePath).exists(), isFalse);
  });

  test('delete does nothing (and does not throw) for a path that was never imported',
      () async {
    await storage.delete('photos/does-not-exist.jpg');
  });

  test('importBytes writes bytes under attachments/<yyyy-MM>/ with the extension',
      () async {
    final relativePath =
        await storage.importBytes([7, 8, 9], fileName: 'Packing-Slip.PDF');

    expect(p.dirname(relativePath), p.join('attachments', '2026-09'));
    expect(p.extension(relativePath), '.pdf');
    expect(await storage.resolve(relativePath).readAsBytes(), [7, 8, 9]);
  });

  group('importImage (an image shared in)', () {
    test('a large screenshot is scaled to 1600px on its long edge as JPEG',
        () async {
      final source = await writeSourceFile(
          'Screenshot.png', img.encodePng(img.Image(width: 1080, height: 2400)));

      final relativePath = await storage.importImage(source);

      expect(relativePath, startsWith(p.join('attachments', '2026-09')));
      expect(p.extension(relativePath), '.jpg');
      final stored =
          img.decodeImage(File(p.join(documentsDir.path, relativePath))
              .readAsBytesSync())!;
      expect(stored.height, 1600);
      expect(stored.width, 720);
      expect(img.findFormatForData(
              File(p.join(documentsDir.path, relativePath)).readAsBytesSync()),
          img.ImageFormat.jpg);
    });

    test('a small image keeps its size', () async {
      final source = await writeSourceFile(
          'small.png', img.encodePng(img.Image(width: 300, height: 200)));
      final relativePath = await storage.importImage(source);
      final stored = img.decodeImage(
          File(p.join(documentsDir.path, relativePath)).readAsBytesSync())!;
      expect((stored.width, stored.height), (300, 200));
    });

    test('a file that is not an image is copied as it is', () async {
      final source = await writeSourceFile('odd.heic', [1, 2, 3]);
      final relativePath = await storage.importImage(source);
      expect(File(p.join(documentsDir.path, relativePath)).readAsBytesSync(),
          [1, 2, 3]);
      expect(p.extension(relativePath), '.heic');
    });
  });
}
