# Bundled product catalogue: sample

`egypt_products.json` (format `product-catalog/1`) is a small made-up sample
of 20 everyday products so the barcode features have something to find.
Every barcode starts with 200, a prefix reserved for in-store use, so none
of them belongs to a real product. Names, sizes and prices are typical
examples, not data from any store.

To ship a real catalogue, replace the file with one in the same format:

| Field | Meaning |
|---|---|
| `barcode` | EAN-13, EAN-8 or UPC-A digits |
| `nameAr`, `nameEn`, `brand`, `size` | How the product is shown |
| `categoryKey`, `subcategoryKey` | The app's English keys |
| `pricePiastres` | A typical price in whole piastres, or null |
| `priceSource`, `priceDate` | Where and when the price was seen |

`catalogueAdditions` lists the categories and subcategories the app creates
the first time a product needs one.
