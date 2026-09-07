import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    storage = PhotoStorage(documentsDir);
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

  test('importPhoto copies the source file into a photos/ subfolder',
      () async {
    final source = await writeSourceFile('picked.jpg', [1, 2, 3, 4]);

    final relativePath = await storage.importPhoto(source);

    final expectedDir = Directory(p.join(documentsDir.path, 'photos'));
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
    expect(relativePath, startsWith('photos${p.separator}'));
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

  test('resolve turns a stored relative path back into the absolute file',
      () async {
    final source = await writeSourceFile('picked.jpg', [7, 7]);
    final relativePath = await storage.importPhoto(source);

    final resolved = storage.resolve(relativePath);

    expect(resolved.path, p.join(documentsDir.path, relativePath));
    expect(await resolved.exists(), isTrue);
  });
}
