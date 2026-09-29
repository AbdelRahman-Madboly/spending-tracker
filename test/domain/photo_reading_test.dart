import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/parsing/catalogue_matcher.dart';
import 'package:spending_tracker/domain/parsing/parsed_line.dart';
import 'package:spending_tracker/domain/photo_reading.dart';

final _now = DateTime(2026, 9, 29, 12);

PhotoReading _read(String text) => readPhotoText(text, now: _now);

const _instaPay = '''
InstaPay
Transaction Successful
EGP 1,250.00
Sent to
Ahmed M***
ahmed.m@instapay
Reference Number
512345678901
Date
28 Sep 2026 10:15 PM
''';

const _instaPayReceived = '''
InstaPay
Transaction Successful
EGP 9,000.00
From
Ahmed M***
ahmed.m@instapay
To
Mostafa Sample
sampleuser@instapay
Reference Number
512345678999
Date
28 Sep 2026 10:15 PM
''';

void main() {
  group('amounts', () {
    test('a total next to a currency word is read in piastres', () {
      expect(_read('Total 85.50 EGP').amountPiastres, 8550);
      expect(_read('LE 40').amountPiastres, 4000);
      expect(_read('120 جنيه').amountPiastres, 12000);
    });

    test('a comma with one or two digits after it is a decimal point', () {
      expect(_read('Total 12,5 EGP').amountPiastres, 1250);
      expect(_read('Total 12,50 EGP').amountPiastres, 1250);
    });

    test('a comma before three digits groups thousands', () {
      expect(_read('EGP 1,250.00').amountPiastres, 125000);
      expect(_read('EGP 1,250').amountPiastres, 125000);
    });

    test('a label on one line and the amount on the next are read together',
        () {
      expect(_read('Total\n230.00').amountPiastres, 23000);
      expect(_read('Amount\n75').amountPiastres, 7500);
    });

    test('the largest total is preferred over subtotals and tax', () {
      const receipt = '''
Subtotal 200.00 EGP
VAT 28.00 EGP
Total 228.00 EGP
Cash 300.00
''';
      // Cash 300.00 has no money word near it: it is the note handed
      // over, not a total.
      expect(_read(receipt).amountPiastres, 22800);
      expect(_read('Subtotal 200.00\nTotal 228.00').amountPiastres, 22800);
    });

    test('numbers with no money word near them are not amounts', () {
      expect(_read('Pepsi 330 ml\nBatch 20260901').amountPiastres, isNull);
    });

    test('a long reference number is never taken for an amount', () {
      expect(_read('EGP 512345678901').amountPiastres, isNull);
    });

    test('Eastern Arabic digits are read too', () {
      expect(_read('الإجمالي ٤٥٫٥٠').amountPiastres, 4550);
    });
  });

  group('dates', () {
    test('day/month/year and ISO dates', () {
      expect(_read('Date 27/09/2026').date, DateTime(2026, 9, 27));
      expect(_read('2026-09-25 13:40').date, DateTime(2026, 9, 25));
      expect(_read('27-9-2026').date, DateTime(2026, 9, 27));
    });

    test('month names, either order', () {
      expect(_read('28 Sep 2026 10:15 PM').date, DateTime(2026, 9, 28));
      expect(_read('Sept 3, 2026').date, DateTime(2026, 9, 3));
      expect(_read('3 September 2026').date, DateTime(2026, 9, 3));
    });

    test('a date after today or an impossible one is ignored', () {
      expect(_read('Date 30/09/2026').date, isNull);
      expect(_read('Date 31/02/2026').date, isNull);
    });
  });

  group('InstaPay', () {
    test('a screenshot gives the amount, date and reference', () {
      final reading = _read(_instaPay);
      expect(reading.isInstaPay, isTrue);
      expect(reading.amountPiastres, 125000);
      expect(reading.date, DateTime(2026, 9, 28));
      expect(reading.reference, '512345678901');
    });

    test('the reference may sit on the label line, under other names', () {
      expect(_read('instapay\nRef. No: 99887766554').reference, '99887766554');
      expect(_read('InstaPay\nTransaction ID 1234 5678 9012').reference,
          '123456789012');
      expect(_read('InstaPay\nTransaction reference:\nFT26271ABC99').reference,
          'FT26271ABC99');
    });

    test('an IPA address alone says InstaPay', () {
      expect(_read('Sent to sara@instapay\nEGP 50').isInstaPay, isTrue);
    });

    group('direction', () {
      test('a transfer sent to someone else is sent', () {
        expect(_read(_instaPay).direction, TransferDirection.sent);
      });

      test('the user under To is money received', () {
        expect(_read(_instaPayReceived).direction, TransferDirection.received);
      });

      test('a payer\'s "Sent to" screenshot naming the user is received', () {
        expect(
            _read('InstaPay\nSent to\nMostafa M***\n'
                    'sampleuser@instapay\nEGP 500')
                .direction,
            TransferDirection.received);
      });

      test('the user under From is sent', () {
        expect(
            _read('InstaPay\nFrom\nsampleuser@instapay\nTo\n'
                    'sara@instapay\nEGP 50')
                .direction,
            TransferDirection.sent);
      });

      test('a Received label is money received', () {
        expect(
            _read('InstaPay\nMoney Received\nfrom ahmed.m@instapay\nEGP 700')
                .direction,
            TransferDirection.received);
        expect(_read('InstaPay\nتم استلام\nEGP 700').direction,
            TransferDirection.received);
      });

      test('the user named with no label to place them is uncertain', () {
        expect(
            _read('InstaPay\nsampleuser@instapay\nEGP 700').direction,
            TransferDirection.uncertain);
      });

      test('signals both ways are uncertain', () {
        expect(
            _read('InstaPay\nReceived\nFrom\nsampleuser@instapay\nEGP 700')
                .direction,
            TransferDirection.uncertain);
      });

      test('a receipt that is not InstaPay has no direction', () {
        expect(_read('Received with thanks\nTotal 20 EGP').direction,
            TransferDirection.sent);
      });
    });

    test('an ordinary receipt is not InstaPay and has no reference', () {
      final reading = _read('Carrefour\nTotal 228.00 EGP');
      expect(reading.isInstaPay, isFalse);
      expect(reading.reference, isNull);
    });
  });

  group('brand words', () {
    test('Latin words are kept, receipt vocabulary is not', () {
      final reading = _read('PEPSI 330ml\nTotal 20.00 EGP\nThank you');
      expect(reading.words, contains('pepsi'));
      expect(reading.words, isNot(contains('total')));
      expect(reading.words, isNot(contains('egp')));
      expect(reading.words, isNot(contains('thank')));
    });
  });

  group('photoLines', () {
    final catalogue = ParserCatalogue(
      items: const [
        CatalogueItem('pepsi', 'بيبسي', 'Drinks', 'SoftDrinks'),
        CatalogueItem('indomie', 'إندومي', 'Food', 'Snacks'),
      ],
      subcategories: const [],
      aliases: const {'pepsi': 'pepsi', 'indomie': 'indomie'},
    );
    int? price(String id) => {'pepsi': 2000, 'indomie': null}[id];
    final day = DateTime(2026, 9, 29);

    test('InstaPay makes one line with the amount and the reference', () {
      final lines =
          photoLines(_read(_instaPay), catalogue, day: day, priceOf: price);
      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line.amountPiastres, 125000);
      expect(line.reference, '512345678901');
      expect(line.date, DateTime(2026, 9, 28));
      expect(line.name, 'تحويل إنستاباي');
      expect(line.flags, contains(ParseFlag.noCategory));
    });

    test('a transfer received is one incoming line, not an expense', () {
      final lines = photoLines(_read(_instaPayReceived), catalogue,
          day: day, priceOf: price);
      final line = lines.single;
      expect(line.amountPiastres, 900000);
      expect(line.reference, '512345678999');
      expect(line.name, 'تحويل وارد');
      expect(line.flags, contains(ParseFlag.incoming));
    });

    test('an uncertain direction stays an expense line with low confidence',
        () {
      final lines = photoLines(
          _read('InstaPay\nsampleuser@instapay\nEGP 700'), catalogue,
          day: day, priceOf: price);
      final line = lines.single;
      expect(line.name, 'تحويل إنستاباي');
      expect(line.confidence, ParseConfidence.low);
      expect(line.flags, contains(ParseFlag.maybeIncoming));
      expect(line.flags, isNot(contains(ParseFlag.incoming)));
    });

    test('a transfer sent carries neither incoming flag', () {
      final line = photoLines(_read(_instaPay), catalogue,
              day: day, priceOf: price)
          .single;
      expect(line.flags, isNot(contains(ParseFlag.incoming)));
      expect(line.flags, isNot(contains(ParseFlag.maybeIncoming)));
      expect(line.confidence, ParseConfidence.medium);
    });

    test('a receipt total takes the one brand it names', () {
      final lines = photoLines(_read('PEPSI\nTotal 25.00 EGP'), catalogue,
          day: day, priceOf: price);
      expect(lines, hasLength(1));
      expect(lines.single.amountPiastres, 2500);
      expect(lines.single.itemId, 'pepsi');
      expect(lines.single.categoryKey, 'Drinks');
      expect(lines.single.date, day);
    });

    test('a receipt total with no known brand is one uncategorised line', () {
      final lines = photoLines(_read('Carrefour\nTotal 228.00 EGP'), catalogue,
          day: day, priceOf: price);
      expect(lines.single.amountPiastres, 22800);
      expect(lines.single.name, 'فاتورة');
      expect(lines.single.flags, contains(ParseFlag.noCategory));
    });

    test('packaging with no price makes one line per known product', () {
      final lines = photoLines(_read('Pepsi\nIndomie Chicken\nPepsi'),
          catalogue, day: day, priceOf: price);
      expect([for (final l in lines) l.itemId], ['pepsi', 'indomie']);
      expect(lines.first.amountPiastres, 2000);
      expect(lines.last.amountPiastres, isNull);
      expect(lines.last.flags, contains(ParseFlag.noAmount));
    });

    test('nothing readable makes no lines', () {
      expect(photoLines(_read(''), catalogue, day: day, priceOf: price),
          isEmpty);
    });
  });
}
