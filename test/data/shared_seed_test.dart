import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';

/// The seed the shared build starts from (`assets/seed/seed_shared.json`,
/// written by `tool/build_shared_seed.py`): every category, subcategory
/// and generic item, and nothing of the owner's own money.
void main() {
  final text = File('assets/seed/seed_shared.json').readAsStringSync();
  final json = jsonDecode(text) as Map<String, dynamic>;

  test('holds no entries and no salary periods', () {
    expect(json['entries'], isEmpty);
    expect(json['salaryPeriods'], isEmpty);
  });

  test('items keep their default prices but no history of use', () {
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    expect(items.map((i) => i['nameAr']),
        containsAll(['تاكسي', 'شويبس', 'إندومي']));
    for (final item in items) {
      expect(item['useCount'], 0, reason: item['nameAr'] as String);
      expect(item['lastUsedAt'], isNull);
      expect(item['defaultAmountPiastres'], isA<int>());
    }
  });

  test('names no brand the owner pays or any detail of his life', () {
    for (final word in [
      'Vodafone',
      'Etisalat',
      'Orange',
      'Bekharo',
      'personal phone',
      'faka',
      'sampleuser',
      'Sample',
    ]) {
      expect(text.toLowerCase(), isNot(contains(word.toLowerCase())),
          reason: word);
    }
  });

  test('seeds every category and subcategory imports and the catalogue add',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(),
        seedJsonLoader: () async => text);
    addTearDown(db.close);

    expect(await db.select(db.entries).get(), isEmpty);
    expect(await db.select(db.salaryPeriods).get(), isEmpty);
    expect(await db.select(db.captureGroups).get(), isEmpty);
    expect(await db.select(db.attachments).get(), isEmpty);

    final categories = {
      for (final c in await db.select(db.categories).get()) c.key: c
    };
    expect(
        categories.keys,
        containsAll([
          'Drinks', 'Snacks', 'Food', 'Transport', 'Bills',
          'Personal Care', 'Shopping', 'Family/Social', 'Gifts', 'Loans',
          'Health', 'Home', 'Subscriptions',
        ]));
    expect(categories['Health']!.colorKey, 'Health');
    expect(categories['Home']!.colorKey, 'Home');

    final subcategories = {
      for (final s in await db.select(db.subcategories).get())
        s.key: s.categoryKey
    };
    expect(subcategories, containsPair('Medicine', 'Health'));
    expect(subcategories, containsPair('Cleaning', 'Home'));
    expect(subcategories, containsPair('Laundry', 'Personal Care'));
    expect(subcategories, containsPair('FamilySupport', 'Family/Social'));
    expect(subcategories, containsPair('Software', 'Subscriptions'));
    expect(subcategories, containsPair('Cloud', 'Subscriptions'));
    expect(subcategories, containsPair('Courses', 'Subscriptions'));
    expect(subcategories, containsPair('QuickMeals', 'Food'));
    expect(subcategories, containsPair('HomeInternet', 'Bills'));

    final items = await db.select(db.items).get();
    expect(items, isNotEmpty);
    expect(items.every((i) => i.useCount == 0 && i.lastUsedAt == null),
        isTrue);
  });
}
