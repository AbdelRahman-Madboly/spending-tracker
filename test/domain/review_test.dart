import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/parsing/catalogue_matcher.dart';
import 'package:spending_tracker/domain/parsing/line_parser.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';
import 'package:spending_tracker/domain/photo_reading.dart';
import 'package:spending_tracker/domain/review.dart';

ParsedLine _parsed({
  String name = 'طماطم',
  int? amount = 3000,
  String? category = 'Food',
  String? subcategory = 'Groceries',
  String? itemId,
  int quantity = 1000,
  String? unit,
  int? unitPrice,
  Set<ParseFlag> flags = const {},
  ParseConfidence confidence = ParseConfidence.high,
}) =>
    ParsedLine(
      rawText: name,
      date: DateTime(2026, 9, 22),
      name: name,
      itemId: itemId,
      categoryKey: category,
      subcategoryKey: subcategory,
      quantityMilli: quantity,
      unit: unit,
      amountPiastres: amount,
      unitPricePiastres: unitPrice,
      confidence: confidence,
      flags: flags,
    );

void main() {
  group('ReviewLine.fromParsed', () {
    test('keeps what the parser read', () {
      final line = ReviewLine.fromParsed(
          _parsed(quantity: 2000, unit: 'kg', unitPrice: 1500),
          id: 'a');
      expect(line.id, 'a');
      expect(line.name, 'طماطم');
      expect(line.amountPiastres, 3000);
      expect(line.quantityMilli, 2000);
      expect(line.unit, 'kg');
      expect(line.unitPricePiastres, 1500);
      expect(line.categoryKey, 'Food');
      expect(line.subcategoryKey, 'Groceries');
      expect(line.uncertain, isEmpty);
      expect(line.problems, isEmpty);
    });

    test('marks the fields the parser was unsure of', () {
      expect(
          ReviewLine.fromParsed(
                  _parsed(amount: null, flags: {ParseFlag.noAmount}),
                  id: 'a')
              .uncertain,
          {ReviewField.amount});
      expect(
          ReviewLine.fromParsed(
                  _parsed(flags: {ParseFlag.ambiguousAmount}), id: 'a')
              .uncertain,
          {ReviewField.amount, ReviewField.quantity});
      expect(
          ReviewLine.fromParsed(
                  _parsed(category: null, flags: {ParseFlag.noCategory}),
                  id: 'a')
              .uncertain,
          {ReviewField.category});
      // A name corrected by edit distance is a guess worth a look.
      expect(
          ReviewLine.fromParsed(
                  _parsed(itemId: 'i2', flags: {ParseFlag.fuzzyMatch}),
                  id: 'a')
              .uncertain,
          {ReviewField.name});
    });
  });

  group('transfers in', () {
    test('a received transfer is marked with the photo it was read from', () {
      final line = ReviewLine.fromParsed(
          _parsed(category: null, flags: {ParseFlag.incoming}),
          id: 'a',
          photoPath: 'attachments/2026-09/1.jpg');
      expect(line.transfer, TransferDirection.received);
      expect(line.photoPath, 'attachments/2026-09/1.jpg');
    });

    test('an uncertain one is marked and its name is worth a look', () {
      final line = ReviewLine.fromParsed(
          _parsed(flags: {ParseFlag.maybeIncoming}),
          id: 'a',
          photoPath: 'p.jpg');
      expect(line.transfer, TransferDirection.uncertain);
      expect(line.uncertain, contains(ReviewField.name));
    });

    test('any other line has no transfer, and edits keep the mark', () {
      expect(ReviewLine.fromParsed(_parsed(), id: 'a').transfer, isNull);
      final edited = ReviewLine.fromParsed(
              _parsed(category: null, flags: {ParseFlag.incoming}),
              id: 'a',
              photoPath: 'p.jpg')
          .withAmount(900)
          .withCategory('Food');
      expect(edited.transfer, TransferDirection.received);
      expect(edited.photoPath, 'p.jpg');
    });

    test('a salary needs only an amount above zero', () {
      final line = ReviewLine.fromParsed(
          _parsed(category: null, flags: {ParseFlag.incoming}), id: 'a');
      expect(line.canBeSalary, isTrue);
      expect(line.withAmount(0).canBeSalary, isFalse);
    });
  });

  group('problems block saving', () {
    test('a line needs an amount above zero and a category', () {
      final blank = ReviewLine.blank('b');
      expect(blank.problems,
          {ReviewProblem.missingAmount, ReviewProblem.missingCategory});
      expect(blank.withAmount(0).problems, contains(ReviewProblem.missingAmount));
      final ready = blank.withAmount(500).withCategory('Food');
      expect(ready.problems, isEmpty);
    });

    test('canSaveReview needs at least one line and every line ready', () {
      final ready = ReviewLine.fromParsed(_parsed(), id: 'a');
      final missing = ReviewLine.blank('b');
      expect(canSaveReview(const []), isFalse);
      expect(canSaveReview([ready]), isTrue);
      expect(canSaveReview([ready, missing]), isFalse);
    });
  });

  group('editing', () {
    final base = ReviewLine.fromParsed(
        _parsed(
          quantity: 2000,
          unit: 'kg',
          unitPrice: 1500,
          flags: {ParseFlag.ambiguousAmount},
        ),
        id: 'a');

    test('a typed amount drops the unit price and the doubt', () {
      final edited = base.withAmount(4000);
      expect(edited.amountPiastres, 4000);
      expect(edited.unitPricePiastres, isNull);
      expect(edited.uncertain, {ReviewField.quantity});
    });

    test('a new quantity with a unit price recomputes the amount', () {
      final edited = base.withQuantity(3500);
      expect(edited.quantityMilli, 3500);
      expect(edited.amountPiastres, 5250);
      expect(edited.uncertain, {ReviewField.amount});
    });

    test('a new quantity without a unit price keeps the amount', () {
      final edited = base.withAmount(4000).withQuantity(3000);
      expect(edited.amountPiastres, 4000);
    });

    test('a new category clears the subcategory and the item', () {
      final linked = base.withItem(const QuickPickItem(
          id: 'i9', nameAr: 'عصير', categoryKey: 'Drinks',
          subcategoryKey: 'Juice'));
      final moved = linked.withCategory('Snacks');
      expect(moved.categoryKey, 'Snacks');
      expect(moved.subcategoryKey, isNull);
      expect(moved.itemId, isNull);
      // The same category again changes nothing.
      expect(linked.withCategory('Drinks'), linked);
    });

    test('linking an item takes its name and filing and settles doubts', () {
      final line = ReviewLine.fromParsed(
          _parsed(
              name: 'انودي',
              category: null,
              subcategory: null,
              flags: {ParseFlag.noCategory}),
          id: 'a');
      final linked = line.withItem(const QuickPickItem(
          id: 'i2', nameAr: 'إندومي', categoryKey: 'Food',
          subcategoryKey: 'Lunch'));
      expect(linked.name, 'إندومي');
      expect(linked.itemId, 'i2');
      expect(linked.categoryKey, 'Food');
      expect(linked.subcategoryKey, 'Lunch');
      expect(linked.uncertain, isEmpty);
    });

    test('a new subcategory unlinks an item filed elsewhere', () {
      final linked = base.withItem(const QuickPickItem(
          id: 'i9', nameAr: 'عصير', categoryKey: 'Drinks',
          subcategoryKey: 'Juice'));
      expect(linked.withSubcategory('Juice').itemId, 'i9');
      expect(linked.withSubcategory('Soda').itemId, isNull);
      expect(linked.withSubcategory('Soda').subcategoryKey, 'Soda');
    });
  });

  group('toCaptureLine', () {
    test('writes the line, one unit stored as no quantity', () {
      final line = ReviewLine.fromParsed(_parsed(name: ' عيش '), id: 'a');
      expect(
        line.toCaptureLine(),
        const CaptureLine(
          amountPiastres: 3000,
          categoryKey: 'Food',
          subcategoryKey: 'Groceries',
          description: 'عيش',
        ),
      );
    });

    test('keeps a quantity and unit', () {
      final line = ReviewLine.fromParsed(
          _parsed(quantity: 2000, unit: 'kg', unitPrice: 1500),
          id: 'a');
      final capture = line.toCaptureLine();
      expect(capture.quantityMilli, 2000);
      expect(capture.unit, 'kg');
      expect(capture.unitPricePiastres, 1500);
    });

    test('learns the captured words as an alias for an item linked in review',
        () {
      final parsed = ReviewLine.fromParsed(
          _parsed(name: 'انودي', category: null, subcategory: null),
          id: 'a');
      expect(parsed.toCaptureLineOrNull()?.aliasToLearn, isNull);
      final linked = parsed.withItem(const QuickPickItem(
          id: 'i2', nameAr: 'إندومي', categoryKey: 'Food'));
      expect(linked.toCaptureLine().aliasToLearn, 'انودي');
      expect(linked.toCaptureLine().itemId, 'i2');
      // A line the parser linked needs nothing learned.
      final matched = ReviewLine.fromParsed(
          _parsed(name: 'إندومي', itemId: 'i2'), id: 'b');
      expect(matched.toCaptureLine().aliasToLearn, isNull);
      // A line added in review has no captured words to learn.
      final added = ReviewLine.blank('c').withAmount(500).withItem(
          const QuickPickItem(id: 'i2', nameAr: 'إندومي', categoryKey: 'Food'));
      expect(added.toCaptureLine().aliasToLearn, isNull);
    });

    test('refuses a line that is not ready', () {
      expect(ReviewLine.blank('b').toCaptureLineOrNull(), isNull);
      expect(() => ReviewLine.blank('b').toCaptureLine(), throwsStateError);
    });
  });

  test('reviewTotal adds the amounts it has', () {
    expect(
      reviewTotal([
        ReviewLine.blank('a').withAmount(1250),
        ReviewLine.blank('b'),
        ReviewLine.blank('c').withAmount(300),
      ]),
      1550,
    );
  });

  test('reviewDraftText writes lines the parser reads back the same', () {
    final lines = [
      ReviewLine.fromParsed(
          _parsed(name: 'طماطم', quantity: 2000, unit: 'kg', amount: 3000),
          id: 'a'),
      ReviewLine.fromParsed(_parsed(name: 'عيش', amount: 1050), id: 'b'),
      ReviewLine.blank('c').withName('هدية'),
    ];
    final text = reviewDraftText(lines);
    final back = ArabicLineParser(ParserCatalogue.empty())
        .parse(text, capturedAt: DateTime(2026, 9, 22, 12));
    expect(back.map((l) => l.name), ['طماطم', 'عيش', 'هدية']);
    expect(back.map((l) => l.amountPiastres), [3000, 1050, null]);
    expect(back.map((l) => l.quantityMilli), [2000, 1000, 1000]);
    expect(back.first.unit, 'kg');
  });

  test('a payment reference read off a photo is saved with its line, and '
      'survives edits', () {
    final line = ReviewLine.fromParsed(
      ParsedLine(
        rawText: 'InstaPay',
        date: DateTime(2026, 9, 28),
        name: 'تحويل إنستاباي',
        amountPiastres: 125000,
        reference: '512345678901',
        confidence: ParseConfidence.medium,
      ),
      id: 'l0',
    ).withCategory('Family/Social').withAmount(120000);

    expect(line.reference, '512345678901');
    expect(line.toCaptureLine().reference, '512345678901');
  });

  group('withReadReferences', () {
    ParsedLine read(String reference, int? amount) => ParsedLine(
          rawText: 'InstaPay',
          date: DateTime(2026, 9, 28),
          name: 'تحويل إنستاباي',
          amountPiastres: amount,
          confidence: ParseConfidence.high,
          reference: reference,
        );
    ReviewLine line(String id, int? amount) => ReviewLine.fromParsed(
        _parsed(name: 'تحويل $id', amount: amount), id: id);

    test('gives a reference to the line with the amount the photo showed',
        () {
      final lines = withReadReferences(
          [line('a', 3000), line('b', 125000)], [read('512345678901', 125000)]);
      expect(lines[0].reference, isNull);
      expect(lines[1].reference, '512345678901');
      expect(lines[1].name, 'تحويل b');
    });

    test('gives a single reference to a single line whose amount was edited',
        () {
      final lines =
          withReadReferences([line('a', 120000)], [read('512345678901', 125000)]);
      expect(lines.single.reference, '512345678901');
    });

    test('does not guess among several lines', () {
      final lines = withReadReferences(
          [line('a', 3000), line('b', 4000)], [read('512345678901', 125000)]);
      expect([for (final l in lines) l.reference], [null, null]);
    });

    test('leaves a reference a line already has', () {
      final lines = withReadReferences(
          [line('a', 125000).withReference('512345678901')],
          [read('512345678901', 125000)]);
      expect(lines.single.reference, '512345678901');
    });
  });
}
