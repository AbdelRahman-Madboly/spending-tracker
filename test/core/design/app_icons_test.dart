import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:spending_tracker/core/design/app_icons.dart';
import 'package:spending_tracker/data/db/database.dart';

void main() {
  test('every seeded category and subcategory icon resolves to its own '
      'Rounded symbol rather than the fallback', () async {
    // The real seed, which is what the installed app's rows came from.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final names = {
      for (final c in await db.select(db.categories).get()) c.iconName,
      for (final s in await db.select(db.subcategories).get()) s.iconName,
    };
    expect(names, isNotEmpty);
    for (final name in names) {
      final icon = iconFor(name);
      expect(icon.fontFamily, 'MaterialSymbolsRounded', reason: name);
      expect(icon, isNot(Symbols.category_rounded), reason: name);
    }
  });

  test('the three names with no Symbols glyph are remapped', () {
    expect(iconFor('cake'), Symbols.bakery_dining_rounded);
    expect(iconFor('tapas'), Symbols.lunch_dining_rounded);
    expect(iconFor('emoji_food_beverage'), Symbols.glass_cup_rounded);
  });

  test('distinct seeded icon names never render as the same glyph', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final names = {
      for (final c in await db.select(db.categories).get()) c.iconName,
      for (final s in await db.select(db.subcategories).get()) s.iconName,
    }.toList();
    final byGlyph = <IconData, List<String>>{};
    for (final name in names) {
      byGlyph.putIfAbsent(iconFor(name), () => []).add(name);
    }
    // Spec §7.2 itself remaps tapas (Chips) onto lunch_dining (Lunch);
    // that one shared glyph is the spec's call, not an accident.
    expect(byGlyph.values.where((n) => n.length > 1), [
      ['tapas', 'lunch_dining'],
    ]);
  });

  test('an unknown name falls back to category', () {
    expect(iconFor('no_such_icon'), Symbols.category_rounded);
    expect(iconFor(''), Symbols.category_rounded);
    // The v2 picker's own fallback name.
    expect(iconFor('category_outlined'), Symbols.category_rounded);
  });

  test('the picker offers the §7.2 symbol of every colour family', () {
    expect(
      curatedIconNames,
      containsAll(const [
        'local_drink',
        'cookie',
        'restaurant',
        'directions_bus',
        'receipt_long',
        'content_cut',
        'shopping_bag',
        'groups',
        'redeem',
        'handshake',
        'medication',
        'school',
        'home',
        'category',
      ]),
    );
  });

  test('the picker offers no remapped legacy name and no duplicate glyph', () {
    expect(curatedIconNames,
        isNot(anyElement(isIn(const [
      'cake',
      'tapas',
      'emoji_food_beverage',
      'category_outlined',
      'card_giftcard',
      'local_grocery_store',
      'free_breakfast',
    ]))));
    final glyphs = curatedIconNames.map(iconFor).toList();
    expect(glyphs.toSet(), hasLength(glyphs.length));
    expect(curatedIconNames.toSet(), hasLength(curatedIconNames.length));
  });

  test('every picker name resolves to a Rounded symbol', () {
    for (final name in curatedIconNames) {
      expect(iconFor(name).fontFamily, 'MaterialSymbolsRounded',
          reason: name);
    }
  });

  test('the capture icons are Rounded symbols', () {
    expect(AppIcons.mic, Symbols.mic_rounded);
    expect(AppIcons.camera, Symbols.photo_camera_rounded);
    expect(AppIcons.barcode, Symbols.barcode_scanner_rounded);
    expect(AppIcons.textNote, Symbols.edit_note_rounded);
    expect(AppIcons.gallery, Symbols.image_rounded);
    expect(AppIcons.voiceNote, Symbols.graphic_eq_rounded);
    expect(AppIcons.enhance, Symbols.auto_awesome_rounded);
    expect(AppIcons.online, Symbols.cloud_rounded);
  });

  test('arrow-type icons mirror in right-to-left', () {
    expect(AppIcons.back.matchTextDirection, isTrue);
    expect(AppIcons.forward.matchTextDirection, isTrue);
  });

  test('no screen draws from the old Material Icons font', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'\bIcons\.').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
