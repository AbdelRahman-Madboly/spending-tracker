import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The single map from a stored icon name (`Categories.iconName`,
/// `Subcategories.iconName`) to the glyph it renders as.
///
/// Every glyph is Material Symbols **Rounded** (spec §7.2). The keys are the
/// same English names v1 and v2 stored, so existing rows on the phone keep
/// their icons without any data migration. Its order is the icon picker's
/// display order.
const Map<String, IconData> _symbolsByName = {
  // The §7.2 symbol of each colour family, first so the picker leads with
  // them.
  'local_drink': Symbols.local_drink_rounded,
  'cookie': Symbols.cookie_rounded,
  'restaurant': Symbols.restaurant_rounded,
  'directions_bus': Symbols.directions_bus_rounded,
  'receipt_long': Symbols.receipt_long_rounded,
  'content_cut': Symbols.content_cut_rounded,
  'shopping_bag': Symbols.shopping_bag_rounded,
  'groups': Symbols.groups_rounded,
  'redeem': Symbols.redeem_rounded,
  'handshake': Symbols.handshake_rounded,
  'medication': Symbols.medication_rounded,
  'school': Symbols.school_rounded,
  'home': Symbols.home_rounded,
  'category': Symbols.category_rounded,
  // The rest of the seeded category and subcategory names (see
  // `_seedSubcategoryRows` in `lib/data/db/database.dart`).
  'local_bar': Symbols.local_bar_rounded,
  'water_drop': Symbols.water_drop_rounded,
  'glass_cup': Symbols.glass_cup_rounded,
  'local_cafe': Symbols.local_cafe_rounded,
  'lunch_dining': Symbols.lunch_dining_rounded,
  'bakery_dining': Symbols.bakery_dining_rounded,
  'icecream': Symbols.icecream_rounded,
  'fastfood': Symbols.fastfood_rounded,
  'breakfast_dining': Symbols.breakfast_dining_rounded,
  'dinner_dining': Symbols.dinner_dining_rounded,
  'grocery': Symbols.grocery_rounded,
  'local_taxi': Symbols.local_taxi_rounded,
  'smartphone': Symbols.smartphone_rounded,
  'wifi': Symbols.wifi_rounded,
  'spa': Symbols.spa_rounded,
  'checkroom': Symbols.checkroom_rounded,
  'devices': Symbols.devices_rounded,
  'shopping_cart': Symbols.shopping_cart_rounded,
  'flight': Symbols.flight_rounded,
  'people': Symbols.people_rounded,
  // General-purpose names for categories and subcategories the user adds.
  'directions_car': Symbols.directions_car_rounded,
  'pets': Symbols.pets_rounded,
  'sports_soccer': Symbols.sports_soccer_rounded,
  'fitness_center': Symbols.fitness_center_rounded,
  'medical_services': Symbols.medical_services_rounded,
  'local_pharmacy': Symbols.local_pharmacy_rounded,
  'work': Symbols.work_rounded,
  'savings': Symbols.savings_rounded,
  'attach_money': Symbols.attach_money_rounded,
  'celebration': Symbols.celebration_rounded,
  'child_care': Symbols.child_care_rounded,
  'movie': Symbols.movie_rounded,
  'sports_esports': Symbols.sports_esports_rounded,
  'book': Symbols.book_rounded,
  'phone_android': Symbols.phone_android_rounded,
  'local_hospital': Symbols.local_hospital_rounded,
  'star': Symbols.star_rounded,
};

/// Stored names that no longer map to a glyph of their own, pointed at the
/// nearest one. They resolve but are never offered in the picker, which
/// offers the canonical name instead.
const Map<String, String> _legacyNames = {
  // No Symbols counterpart (spec §7.2).
  'cake': 'bakery_dining',
  'tapas': 'lunch_dining',
  'emoji_food_beverage': 'glass_cup',
  // The Symbols font draws these with the same codepoint as a sibling
  // (redeem, shopping_cart, local_cafe), so Groceries would look like
  // Online shopping and Breakfast like Hot drinks. Gifts takes §7.2's
  // redeem; the other two move to a glyph of their own.
  'card_giftcard': 'redeem',
  'local_grocery_store': 'grocery',
  'free_breakfast': 'breakfast_dining',
  // The v2 picker's own fallback glyph.
  'category_outlined': 'category',
};

/// Every icon name the icon picker offers, in display order. Each resolves
/// through [iconFor] to a distinct glyph.
final List<String> curatedIconNames = _symbolsByName.keys.toList();

/// The glyph for a stored icon name. Unknown names fall back to `category`,
/// so a row never renders with no icon.
IconData iconFor(String name) =>
    _symbolsByName[_legacyNames[name] ?? name] ?? Symbols.category_rounded;

/// Interface glyphs, all Material Symbols Rounded. Draw them outlined
/// (the theme's default `fill: 0`); pass `fill: 1` only for a selected nav
/// item or a selected chip.
///
/// Arrow-type glyphs ([back], [forward]) carry `matchTextDirection`, so they
/// mirror in the app's right-to-left layout on their own.
abstract final class AppIcons {
  static const add = Symbols.add_rounded;
  static const addCircle = Symbols.add_circle_rounded;
  static const close = Symbols.close_rounded;
  static const check = Symbols.check_rounded;
  static const back = Symbols.arrow_back_rounded;
  static const forward = Symbols.arrow_forward_rounded;
  static const expandMore = Symbols.expand_more_rounded;
  static const expandLess = Symbols.expand_less_rounded;
  static const settings = Symbols.settings_rounded;
  static const stats = Symbols.bar_chart_rounded;
  static const all = Symbols.apps_rounded;
  static const archive = Symbols.archive_rounded;
  static const unarchive = Symbols.unarchive_rounded;

  // Import (settings -> البيانات).
  static const importData = Symbols.download_rounded;
  static const importBundled = Symbols.inventory_2_rounded;
  static const importFile = Symbols.file_open_rounded;
  static const importPaste = Symbols.content_paste_rounded;
  static const brokenImage = Symbols.broken_image_rounded;
  static const keyboard = Symbols.keyboard_rounded;
  static const warning = Symbols.warning_rounded;
  static const backspace = Symbols.backspace_rounded;
  static const payment = Symbols.payments_rounded;

  // السجل and the entry detail sheet.
  static const search = Symbols.search_rounded;
  static const delete = Symbols.delete_rounded;
  static const edit = Symbols.edit_rounded;
  static const calendar = Symbols.calendar_month_rounded;
  static const duplicate = Symbols.content_copy_rounded;
  static const repeat = Symbols.event_repeat_rounded;
  static const attach = Symbols.attach_file_rounded;
  static const pdf = Symbols.picture_as_pdf_rounded;
  static const reference = Symbols.tag_rounded;
  static const play = Symbols.play_arrow_rounded;
  static const pause = Symbols.pause_rounded;
  static const stop = Symbols.stop_rounded;
  static const checkCircle = Symbols.check_circle_rounded;
  static const recategorize = Symbols.drive_file_move_rounded;
  static const filter = Symbols.filter_list_rounded;

  /// Chevrons pointing toward the start and the end side. Both carry
  /// `matchTextDirection`, so "left" draws pointing right in the app's
  /// right-to-left layout, toward the start.
  static const chevronStart = Symbols.chevron_left_rounded;
  static const chevronEnd = Symbols.chevron_right_rounded;
  static const bill = Symbols.event_upcoming_rounded;
  static const review = Symbols.rate_review_rounded;
  static const trendDown = Symbols.trending_down_rounded;
  static const trendUp = Symbols.trending_up_rounded;
  static const trendFlat = Symbols.trending_flat_rounded;
  static const emptyReceipt = Symbols.receipt_long_rounded;

  // Bottom navigation.
  static const navHome = Symbols.home_rounded;
  static const navTransactions = Symbols.receipt_long_rounded;
  static const navStats = Symbols.bar_chart_rounded;
  static const navSettings = Symbols.settings_rounded;

  // Capture (spec §7.2).
  static const mic = Symbols.mic_rounded;
  static const camera = Symbols.photo_camera_rounded;
  static const barcode = Symbols.barcode_scanner_rounded;

  /// The scanner's torch, off and on.
  static const torchOff = Symbols.flashlight_off_rounded;
  static const torchOn = Symbols.flashlight_on_rounded;
  static const textNote = Symbols.edit_note_rounded;
  static const gallery = Symbols.image_rounded;
  static const voiceNote = Symbols.graphic_eq_rounded;

  /// تحسين: send a capture through the smart (online) path.
  static const enhance = Symbols.auto_awesome_rounded;

  /// The online marker, shown only while online features are on.
  static const online = Symbols.cloud_rounded;

  // Appearance setting.
  static const themeSystem = Symbols.brightness_auto_rounded;
  static const themeLight = Symbols.light_mode_rounded;
  static const themeDark = Symbols.dark_mode_rounded;
}
