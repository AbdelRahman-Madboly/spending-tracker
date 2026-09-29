import 'models.dart';

/// A line's quantity, unit, price per unit and total once it is linked to
/// a product sold loose by a unit.
class UnitPricing {
  const UnitPricing({
    required this.quantityMilli,
    required this.unit,
    this.unitPricePiastres,
    this.amountPiastres,
  });

  final int quantityMilli;
  final String unit;
  final int? unitPricePiastres;
  final int? amountPiastres;
}

/// Prices a line linked to a product sold by [unit] at
/// [itemUnitPricePiastres] a unit, usually [usualQuantityMilli] of it.
///
/// - A unit price the line already has (the text said "الكيلو ب ٢٠") wins;
///   the total follows the quantity when the line has none.
/// - With no price at all the line takes the item's price per unit, and
///   the usual quantity when none was [quantityStated].
/// - A price after a stated quantity that equals the item's price per unit
///   ("٢ لتر لبن ب ٢٥" with milk at 25 a litre) is read as that price per
///   unit, since nobody pays 12.50 a litre for milk that costs 25; any other
///   price stays the total paid.
///
/// The total rounds to the piastre like [totalForQuantity].
UnitPricing priceByUnit({
  required String unit,
  int? itemUnitPricePiastres,
  int? usualQuantityMilli,
  required int quantityMilli,
  required bool quantityStated,
  int? amountPiastres,
  int? unitPricePiastres,
}) {
  if (unitPricePiastres != null) {
    return UnitPricing(
      quantityMilli: quantityMilli,
      unit: unit,
      unitPricePiastres: unitPricePiastres,
      amountPiastres:
          amountPiastres ?? totalForQuantity(unitPricePiastres, quantityMilli),
    );
  }
  final itemPrice = itemUnitPricePiastres;
  if (amountPiastres == null) {
    final quantity =
        quantityStated ? quantityMilli : (usualQuantityMilli ?? quantityMilli);
    return UnitPricing(
      quantityMilli: quantity,
      unit: unit,
      unitPricePiastres: itemPrice,
      amountPiastres:
          itemPrice == null ? null : totalForQuantity(itemPrice, quantity),
    );
  }
  if (quantityStated &&
      quantityMilli != 1000 &&
      itemPrice != null &&
      amountPiastres == itemPrice) {
    return UnitPricing(
      quantityMilli: quantityMilli,
      unit: unit,
      unitPricePiastres: itemPrice,
      amountPiastres: totalForQuantity(itemPrice, quantityMilli),
    );
  }
  return UnitPricing(
    quantityMilli: quantityMilli,
    unit: unit,
    amountPiastres: amountPiastres,
  );
}
