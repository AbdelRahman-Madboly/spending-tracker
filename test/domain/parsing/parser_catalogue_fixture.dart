import 'package:spending_tracker/domain/parsing/catalogue_matcher.dart';

/// The catalogue the parser tests match against: the seeded items and
/// subcategories, plus what importing the September Samsung notes adds
/// (`catalogueAdditions` in `assets/import/samsung_notes_2026-09.json`, and
/// the items and aliases the user linked while reviewing that import). The
/// golden test depends on these, so the cleaned names it checks are the
/// ones this catalogue produces.
ParserCatalogue parserCatalogueFixture() => ParserCatalogue(
  items: const [
    CatalogueItem('item-01', 'مخبز', 'Food', 'Breakfast'),
    CatalogueItem('item-02', 'أكل', 'Food', 'Lunch'),
    CatalogueItem('item-03', 'شويبس', 'Drinks', 'Soda'),
    CatalogueItem('item-04', 'لبن', 'Drinks', 'Milk'),
    CatalogueItem('item-05', 'إندومي', 'Food', 'Lunch'),
    CatalogueItem('item-06', 'شوكولاتة', 'Snacks', 'Chocolate'),
    CatalogueItem('item-07', 'تاكسي', 'Transport', 'Taxi'),
    CatalogueItem('item-08', 'مواصلات', 'Transport', 'PublicTransport'),
    CatalogueItem('item-09', 'حلاقة', 'Personal Care', 'Haircut'),
    CatalogueItem('item-10', 'شحن رصيد', 'Bills', 'HomeInternet'),
    CatalogueItem('item-11', 'فاتورة موبايل', 'Bills', 'PhoneBill'),
    CatalogueItem('item-12', 'إنترنت', 'Bills', 'HomeInternet'),
    // Added by the import.
    CatalogueItem('item-13', 'كشري', 'Food', 'Lunch'),
    CatalogueItem('item-14', 'شيبسي', 'Snacks', 'Chips'),
    CatalogueItem('item-15', 'مياه', 'Drinks', 'Water'),
    CatalogueItem('item-16', 'مولتو ماندولين شوكولاتة', 'Snacks', 'Chocolate'),
  ],
  subcategories: const [
    CatalogueSubcategory('Soda', 'Drinks', 'صودا'),
    CatalogueSubcategory('Water', 'Drinks', 'مياه'),
    CatalogueSubcategory('Milk', 'Drinks', 'لبن'),
    CatalogueSubcategory('Juice', 'Drinks', 'عصير'),
    CatalogueSubcategory('HotDrinks', 'Drinks', 'مشروبات ساخنة'),
    CatalogueSubcategory('Chips', 'Snacks', 'شيبسي'),
    CatalogueSubcategory('Chocolate', 'Snacks', 'شوكولاتة'),
    CatalogueSubcategory('Biscuits', 'Snacks', 'بسكوت'),
    CatalogueSubcategory('Sweets', 'Snacks', 'حلويات'),
    CatalogueSubcategory('FastFood', 'Snacks', 'وجبات سريعة'),
    CatalogueSubcategory('Breakfast', 'Food', 'فطار'),
    CatalogueSubcategory('Lunch', 'Food', 'غدا'),
    CatalogueSubcategory('Dinner', 'Food', 'عشا'),
    CatalogueSubcategory('Groceries', 'Food', 'بقالة'),
    CatalogueSubcategory('PublicTransport', 'Transport', 'مواصلات عامة'),
    CatalogueSubcategory('Taxi', 'Transport', 'تاكسي'),
    CatalogueSubcategory('PhoneBill', 'Bills', 'فاتورة موبايل'),
    CatalogueSubcategory('HomeInternet', 'Bills', 'إنترنت المنزل'),
    CatalogueSubcategory('Haircut', 'Personal Care', 'حلاقة'),
    CatalogueSubcategory('Cosmetics', 'Personal Care', 'مستحضرات'),
    CatalogueSubcategory('Laundry', 'Personal Care', 'مغسلة'),
    CatalogueSubcategory('Clothes', 'Shopping', 'ملابس'),
    CatalogueSubcategory('Electronics', 'Shopping', 'إلكترونيات'),
    CatalogueSubcategory('OnlineShopping', 'Shopping', 'تسوق أونلاين'),
    CatalogueSubcategory('Trips', 'Family/Social', 'رحلات'),
    CatalogueSubcategory('Visits', 'Family/Social', 'زيارات'),
    CatalogueSubcategory('Gifts', 'Gifts', 'هدايا'),
    CatalogueSubcategory('Loans', 'Loans', 'سلف'),
    CatalogueSubcategory('Medicine', 'Health', 'أدوية'),
  ],
  aliases: const {
    'swhipps': 'item-03',
    'indomi': 'item-05',
    'chips': 'item-14',
    'ماية': 'item-15',
    'ماندولين شيكولاته': 'item-16',
  },
);
