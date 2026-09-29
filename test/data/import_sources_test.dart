import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/import_sources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled packs load from the assets in import order', () async {
    final packs = await loadBundledPacks();
    expect(packs.map((p) => p.fileName), bundledPackFiles);
    expect(packs.first.rows, isNotEmpty);
  });
}
