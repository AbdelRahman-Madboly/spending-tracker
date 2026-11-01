import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:spending_tracker/data/import_sources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled packs load from the assets in import order', () async {
    final packs = await loadBundledPacks();
    expect(packs.map((p) => p.fileName), bundledPackFiles);
    expect(packs.first.rows, isNotEmpty);
  });

  group('what a share holds', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('share_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    String file(String name, List<int> bytes) {
      final f = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
      return f.path;
    }

    test('images shared together are one photo capture, by path', () async {
      final a = file('IMG_1.png', [1]);
      final b = file('IMG_2.jpg', [2]);
      final shares = await sharedImportsOf([
        SharedMediaFile(path: a, type: SharedMediaType.image),
        SharedMediaFile(path: b, type: SharedMediaType.image),
      ]);
      expect(shares, hasLength(1));
      expect((shares.single as SharedImages).paths, [a, b]);
    });

    test('text and files still go to import, images beside them', () async {
      final note = file('Notes_260913_224548.sdocx', [7, 8]);
      final img = file('IMG_1.png', [1]);
      final shares = await sharedImportsOf([
        SharedMediaFile(path: 'تاكسي ٤٥', type: SharedMediaType.text),
        SharedMediaFile(path: note, type: SharedMediaType.file),
        SharedMediaFile(path: img, type: SharedMediaType.image),
      ]);
      expect(shares, hasLength(3));
      expect((shares[0] as SharedText).text, 'تاكسي ٤٥');
      expect((shares[1] as SharedFile).name, 'Notes_260913_224548.sdocx');
      expect((shares[1] as SharedFile).bytes, [7, 8]);
      expect((shares[2] as SharedImages).paths, [img]);
    });

    test('a file that cannot be read and a video are left out', () async {
      final shares = await sharedImportsOf([
        SharedMediaFile(
            path: p.join(dir.path, 'gone.json'), type: SharedMediaType.file),
        SharedMediaFile(
            path: file('clip.mp4', [0]), type: SharedMediaType.video),
      ]);
      expect(shares, isEmpty);
    });
  });
}
