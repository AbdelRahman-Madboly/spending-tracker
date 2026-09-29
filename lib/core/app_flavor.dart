import 'package:flutter/services.dart' show appFlavor;

/// Which of the two builds this is. Both come from one codebase and differ
/// only in what they start with:
///
/// - [personal] starts populated: a history seeded on first run, two
///   September import packs, and its own defaults (an InstaPay identity
///   and a home internet bill). In this repository all of it is sample
///   data.
/// - [shared] is for anyone else: every category, subcategory, generic item
///   and the product catalogue, but none of the owner's data, and a short
///   welcome that asks for the salary instead.
///
/// The flavour is chosen at build time (`--flavor personal|shared`; the
/// pubspec's `default-flavor` is personal). A build or a test run without
/// one is the personal build.
enum AppFlavor {
  personal,
  shared;

  static AppFlavor fromName(String? name) =>
      name == 'shared' ? AppFlavor.shared : AppFlavor.personal;

  /// The running build. Tests set it to exercise the shared build and put
  /// it back afterwards.
  static AppFlavor current = fromName(appFlavor);

  /// The JSON the database is seeded from on first run.
  String get seedAsset => switch (this) {
        AppFlavor.personal => 'assets/seed/seed.json',
        AppFlavor.shared => 'assets/seed/seed_shared.json',
      };

  /// Whether the September packs under `assets/import/` ship with the app,
  /// so the dashboard and the import screen may offer them.
  bool get bundlesImportPacks => this == AppFlavor.personal;

  /// Whether «الفواتير» may suggest the owner's own bills with no history
  /// behind them (his home internet plan).
  bool get suggestsSeedBills => this == AppFlavor.personal;

  /// Whether the dashboard asks a new user for the salary on first run.
  bool get offersWelcome => this == AppFlavor.shared;

  /// Whether `assets/personal/defaults.json` ships, holding the owner's
  /// defaults for settings he never typed in.
  bool get hasPersonalDefaults => this == AppFlavor.personal;
}
