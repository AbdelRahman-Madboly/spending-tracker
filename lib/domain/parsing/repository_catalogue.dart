import '../spending_repository.dart';
import 'catalogue_matcher.dart';

/// The parser's catalogue as the repository holds it now: every live item,
/// every subcategory of every live category, and the learned aliases
/// (spec §6.5 step 8). Built fresh for each capture, so a line linked in
/// the last review matches in the next one.
Future<ParserCatalogue> loadParserCatalogue(SpendingRepository repo) async {
  final items = await repo.allItems();
  final categories = await repo.categories();
  final subcategories = [
    for (final c in categories) ...await repo.subcategories(c.key),
  ];
  return ParserCatalogue(
    items: [
      for (final i in items)
        CatalogueItem(
          i.id,
          i.nameAr,
          i.categoryKey,
          i.subcategoryKey,
          unit: i.unit,
          unitPricePiastres: i.defaultAmountPiastres,
          usualQuantityMilli: i.defaultQuantityMilli,
        ),
    ],
    subcategories: [
      for (final s in subcategories)
        CatalogueSubcategory(s.key, s.categoryKey, s.labelAr),
    ],
    aliases: await repo.itemAliases(),
  );
}
