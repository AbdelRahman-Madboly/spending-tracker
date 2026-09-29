import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/domain/barcode_scan.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';
import 'package:spending_tracker/domain/review.dart';

void main() {
  final day = DateTime(2026, 9, 29);

  group('BarcodeTally', () {
    final t0 = DateTime(2026, 9, 29, 12);
    Duration ms(int n) => Duration(milliseconds: n);

    test('a code held in front of the camera counts once', () {
      final tally = BarcodeTally();
      expect(tally.add('111', t0), isTrue);
      for (var i = 1; i <= 20; i++) {
        expect(tally.add('111', t0.add(ms(i * 200))), isFalse);
      }
      expect(tally.codes, ['111']);
    });

    test('the same code shown again after a gap counts again', () {
      final tally = BarcodeTally();
      tally.add('111', t0);
      tally.add('222', t0.add(ms(500)));
      expect(tally.add('111', t0.add(ms(2000))), isTrue);
      expect(tally.codes, ['111', '222', '111']);
      expect(tally.count, 3);
    });

    test('an empty code never counts', () {
      final tally = BarcodeTally();
      expect(tally.add('  ', t0), isFalse);
      expect(tally.codes, isEmpty);
    });
  });

  group('barcodeLines', () {
    late FixtureSpendingRepository repo;

    setUp(() => repo = FixtureSpendingRepository());

    test('a known code is its item at the price it was last bought at',
        () async {
      final item = await repo.createItem(
          nameAr: 'بيبسي كانز',
          categoryKey: 'Drinks',
          defaultAmountPiastres: 1500,
          barcode: '6221');
      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.barcode,
        date: day,
        lines: [
          CaptureLine(
              amountPiastres: 2000,
              categoryKey: 'Drinks',
              itemId: item.id,
              description: 'بيبسي كانز'),
        ],
      ));
      final lines = await barcodeLines(['6221'], repository: repo, day: day);
      final line = lines.single;
      expect(line.name, 'بيبسي كانز');
      expect(line.itemId, item.id);
      expect(line.categoryKey, 'Drinks');
      expect(line.amountPiastres, 2000);
      expect(line.barcode, '6221');
      expect(line.confidence, ParseConfidence.high);
      expect(line.flags, isEmpty);
      expect(line.date, day);
    });

    test('a code scanned twice is one line of two', () async {
      await repo.createItem(
          nameAr: 'تونة',
          categoryKey: 'Food',
          defaultAmountPiastres: 4500,
          barcode: '6222');
      final lines = await barcodeLines(['6222', '6222'],
          repository: repo, day: day);
      final line = lines.single;
      expect(line.quantityMilli, 2000);
      expect(line.unitPricePiastres, 4500);
      expect(line.amountPiastres, 9000);
    });

    test('an unknown code asks for its name, amount and category', () async {
      final lines = await barcodeLines(['9999'], repository: repo, day: day);
      final line = lines.single;
      expect(line.name, '');
      expect(line.itemId, isNull);
      expect(line.barcode, '9999');
      expect(line.amountPiastres, isNull);
      expect(line.confidence, ParseConfidence.low);
      expect(line.flags, {ParseFlag.noAmount, ParseFlag.noCategory});
    });

    test('an unknown code takes the looked-up name, once per code', () async {
      final asked = <String>[];
      final lines = await barcodeLines(['9999', '8888', '9999'],
          repository: repo, day: day, nameFor: (code) async {
        asked.add(code);
        return code == '9999' ? 'Juhayna 1 L' : null;
      });
      expect(asked, ['9999', '8888']);
      expect(lines.map((l) => l.name), ['Juhayna 1 L', '']);
      expect(lines.first.quantityMilli, 2000);
    });

    test('a lookup that fails leaves the name to type', () async {
      final lines = await barcodeLines(['9999'],
          repository: repo, day: day, nameFor: (_) async => throw 'offline');
      expect(lines.single.name, '');
    });
  });

  group('ReviewLine with a barcode', () {
    ParsedLine unknown({String name = ''}) => ParsedLine(
          rawText: '9999',
          date: day,
          name: name,
          confidence: ParseConfidence.low,
          flags: const {ParseFlag.noAmount, ParseFlag.noCategory},
          barcode: '9999',
        );

    test('an unknown product needs a name before it can be saved', () {
      final line = ReviewLine.fromParsed(unknown(), id: 'a')
          .withAmount(1000)
          .withCategory('Food');
      expect(line.problems, {ReviewProblem.missingName});
      expect(line.uncertain, contains(ReviewField.name));
      final named = line.withName('عصير');
      expect(named.isReady, isTrue);
      expect(named.toCaptureLine().barcode, '9999');
      expect(named.toCaptureLine().description, 'عصير');
    });

    test('a looked-up name is still a name to check', () {
      final line = ReviewLine.fromParsed(unknown(name: 'Juhayna 1 L'), id: 'a');
      expect(line.uncertain, contains(ReviewField.name));
      expect(line.problems, isNot(contains(ReviewProblem.missingName)));
    });

    test('linking an item keeps the code, so the item learns it', () {
      final line = ReviewLine.fromParsed(unknown(), id: 'a').withItem(
          const QuickPickItem(id: 'i1', nameAr: 'مياه', categoryKey: 'Drinks'));
      expect(line.problems, isNot(contains(ReviewProblem.missingName)));
      expect(line.withAmount(800).toCaptureLine().barcode, '9999');
      expect(line.withAmount(800).toCaptureLine().itemId, 'i1');
    });

    test('a line with no barcode may still be saved without a name', () {
      final line = ReviewLine.blank('a').withAmount(500).withCategory('Food');
      expect(line.isReady, isTrue);
    });
  });
}
