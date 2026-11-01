# مصاريفي (Spending Tracker)

An Android app for logging personal spending in Egyptian pounds, built in
Flutter. The interface is Arabic and right to left. A purchase is meant to be
logged at the till in a few seconds: a known item takes two taps and the
digits, and voice, photo, barcode and text notes all end in one review sheet
before anything is saved.

Everything works offline on one phone with no account.

## Screens

| Screen | What it does |
|---|---|
| الرئيسية (Home) | Salary period header, what is left and the safe amount per day, today's entries, a spending trend, top categories, upcoming bills, this month against the last |
| السجل (Transactions) | Every entry grouped by day, with search across names, notes, photo text and voice transcripts, and filter chips |
| الإحصائيات (Statistics) | A donut of the selected month by category and a history of every month with spending |
| الإعدادات (Settings) | Appearance, online features, recurring bills, import, export to .xlsx, full backup and restore |
| Add sheet | Category, subcategory and item strips with a keypad; products sold by the litre, kilo or gram open a quantity step |
| Capture | Voice note, photo of a receipt, barcode scan or a typed note, each parsed into lines and shown in the review sheet |
| امسح واعرف (scan and check) | Scan a barcode to see the last price paid and the catalogue price without logging anything |
| المنتجات (Products) | Edit a product's name, category, price, unit and barcode, with its price history |

## How data is stored

| What | Where |
|---|---|
| Entries, categories, products, salary periods, bills, settings | One SQLite database (Drift, schema v4) in the app's documents directory |
| Photos, voice notes, imported files | Folders under the same documents directory |
| Online API key | Android secure storage, never in the database, exports or backups |
| Backups | A zip of the database and the attachment folders, saved where the user picks |

Money is stored as whole piastres, never as a floating point number.
Quantities are stored in milli-units (1500 is 1.5 kilo). Deleted entries are
soft deleted and left out of every total. Before a schema migration the app
copies the database file to `backups/` and checks the copy.

Nothing reaches the network unless the master online switch and the feature's
own switch are both on. Both are off by default. The online features are
smarter parsing and photo reading through the Google Gemini API (with the
user's own key), product lookup by barcode on Open Food Facts, and online
speech recognition.

## Builds

There are two flavours on one application id:

| Flavour | Ships with |
|---|---|
| `personal` (default) | The owner's history, his import packs and his own defaults. Private, never published |
| `shared` | Every category, subcategory and generic item and the product catalogue, no entries. A short welcome asks for the salary |

## Build and test

Requires Flutter 3.44.4 (see `.fvmrc`), JDK 17 and the Android SDK.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug                      # personal flavour
flutter build apk --release --flavor shared    # for anyone else
```

After changing `lib/data/db/tables.dart`, regenerate the Drift code with
`dart run build_runner build`.

## What it does not do

- No accounts, sync or cloud storage. One phone holds the data; move it with
  a backup file.
- No bank or card connection. Entries are typed, spoken, scanned or imported.
- No iOS build. Only Android is configured and tested.
- Prices in the bundled catalogue are typical shelf prices from September 2026,
  not live prices.

## Docs

Design specs and implementation plans are in `docs/specs/` and `docs/plans/`.
`CHANGELOG.md` lists the versions.

## Status

Version 3.1.0. In daily use on the owner's phone. Analyzer clean; the test
suite covers money math, parsing, import, the database migrations from v1 to
v4 and every screen.
