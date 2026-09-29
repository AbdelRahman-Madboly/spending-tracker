import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/parsing/line_parser.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';
import 'package:spending_tracker/domain/parsing/repository_catalogue.dart';

void main() {
  test('the parser matches against the live catalogue and learned aliases',
      () async {
    final repo = FixtureSpendingRepository();
    await repo.learnAlias('الفرن', 'i5');
    final parser = ArabicLineParser(await loadParserCatalogue(repo));

    final lines = parser.parse('انودي ب 10\nالفرن ب 25\nمترو ب 8',
        capturedAt: DateTime(2026, 9, 22, 12));

    expect(lines[0].itemId, 'i2');
    expect(lines[0].name, 'إندومي');
    expect(lines[0].flags, contains(ParseFlag.fuzzyMatch));
    expect(lines[1].itemId, 'i5');
    expect(lines[1].categoryKey, 'Food');
    // A subcategory label or keyword files a line with no item.
    expect(lines[2].itemId, isNull);
    expect(lines[2].categoryKey, 'Transport');
  });
}
