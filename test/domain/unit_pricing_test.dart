import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/unit_pricing.dart';

/// How a line linked to a product sold by a unit (milk by the litre at 25,
/// usually 2 litres) gets its unit, price per unit and total.
void main() {
  UnitPricing milk({
    int quantityMilli = 1000,
    bool quantityStated = false,
    int? amount,
    int? unitPrice,
    int? itemPrice = 2500,
    int? usual = 2000,
  }) =>
      priceByUnit(
        unit: 'liter',
        itemUnitPricePiastres: itemPrice,
        usualQuantityMilli: usual,
        quantityMilli: quantityMilli,
        quantityStated: quantityStated,
        amountPiastres: amount,
        unitPricePiastres: unitPrice,
      );

  test('a stated quantity with no price is priced at the item price', () {
    final p = milk(quantityMilli: 2000, quantityStated: true);
    expect(p.unit, 'liter');
    expect(p.quantityMilli, 2000);
    expect(p.unitPricePiastres, 2500);
    expect(p.amountPiastres, 5000);
  });

  test('no quantity and no price is the usual quantity at the item price', () {
    final p = milk();
    expect(p.quantityMilli, 2000);
    expect(p.amountPiastres, 5000);
  });

  test('half a litre is 12.50, rounded to the piastre', () {
    expect(milk(quantityMilli: 500, quantityStated: true).amountPiastres, 1250);
    expect(
        milk(quantityMilli: 333, quantityStated: true).amountPiastres, 833);
  });

  test('a unit price the text gave wins over the item price', () {
    final p = milk(quantityMilli: 2000, quantityStated: true, unitPrice: 2700);
    expect(p.unitPricePiastres, 2700);
    expect(p.amountPiastres, 5400);
  });

  test('a price equal to the item price per litre, after a stated quantity, '
      'is read as the price per litre', () {
    final p = milk(quantityMilli: 2000, quantityStated: true, amount: 2500);
    expect(p.unitPricePiastres, 2500);
    expect(p.amountPiastres, 5000);
  });

  test('any other price stays the total paid', () {
    final p = milk(quantityMilli: 2000, quantityStated: true, amount: 6000);
    expect(p.amountPiastres, 6000);
    expect(p.unitPricePiastres, isNull);
    expect(p.quantityMilli, 2000);
    final plain = milk(amount: 5000);
    expect(plain.amountPiastres, 5000);
    expect(plain.quantityMilli, 1000);
  });

  test('an item with no price yet leaves the amount to the user', () {
    final p = milk(itemPrice: null, quantityMilli: 2000, quantityStated: true);
    expect(p.unit, 'liter');
    expect(p.amountPiastres, isNull);
    expect(p.unitPricePiastres, isNull);
  });

  test('with no usual quantity, one unit', () {
    expect(milk(usual: null).quantityMilli, 1000);
    expect(milk(usual: null).amountPiastres, 2500);
  });
}
