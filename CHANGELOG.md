# Changelog

## 3.1.1 (2026-11-02)

- Settings, About showed version 1.0.0; it now shows the real version.

## 3.1.0 (2026-11-01)

- Two flavours from one codebase: `personal` with a populated history
  (sample data in this repository) and `shared` with categories, items and
  the catalogue but no entries.
- Schema v4: products sold loose by the litre, kilo or gram, with a usual
  quantity and a price per unit across the add sheet, parser, review and
  scan and check.
- Barcode menu: log a purchase, scan and check a price, or open the products.
- InstaPay transfers in are told from transfers out by the name set in
  Settings.
- Bundled product catalogue by barcode (a 20-product sample in this
  repository); its new categories are created on start.
- A welcome card in the shared build asks for the salary on first run.
- Fixes: the transactions list follows new attachments at once; a product
  whose name carries its size is matched by its whole name.
- README, pubspec description and this changelog; a date-independent home
  screen test; direct tests for the .xlsx writer.
- Public release: personal records removed from every commit and replaced
  with made-up sample data; MIT licence and CI.

## 3.0.0 (2026-09-29)

- Bottom navigation with Home, Transactions, Statistics and Settings.
- Voice, photo (on-device text recognition), barcode and text note capture,
  all ending in one review sheet; drafts are kept when a capture cannot be
  parsed.
- Opt-in online features, all off by default.
- Recurring bills with reminders, export to .xlsx, full backup and restore.
- Schema v3 with capture groups and attachments, and a database copy before
  every migration.

## v2 (2026-09-07, released as 1.0.0+1 with no version bump)

- Category, subcategory and item structure with a real migration.
- Camera, gallery and barcode capture in the add sheet.
- Settings for categories, subcategories and items.

## 1.0.0 (2026-09-06)

- Offline Arabic spending tracker with salary periods, categories and
  statistics.
