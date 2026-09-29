import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/app.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/product_catalog_source.dart';
import 'package:spending_tracker/domain/product_catalog.dart';
import 'package:spending_tracker/core/design/tokens.dart';
import 'package:spending_tracker/features/shell/app_shell.dart';

void main() {
  /// SpendingApp owns a real drift database. Unmount it inside the test
  /// (rather than letting the harness tear the tree down after the
  /// callback returns) and pump once more so dispose() can close the
  /// database and drift's stream-cleanup timer fires before the test ends.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('app renders right-to-left in Arabic', (tester) async {
    await tester.pumpWidget(const SpendingApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context).languageCode, 'ar');
    // The app opens on the navigation shell, home tab first.
    expect(find.byType(AppShell), findsOneWidget);

    await unmount(tester);
  });

  for (final (system, palette) in [
    (Brightness.light, AppPalette.light),
    (Brightness.dark, AppPalette.dark),
  ]) {
    testWidgets('follows a ${system.name} system theme by default',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = system;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const SpendingApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).first);
      expect(context.palette, same(palette));
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        palette.bg,
      );

      await unmount(tester);
    });
  }

  testWidgets(
      'on start, creates the categories and subcategories the bundled '
      'catalogue adds', (tester) async {
    final previous = ProductCatalogSource.shared;
    ProductCatalogSource.shared = ProductCatalogSource.fixed(
        ProductCatalog.parse(File('test/fixtures/catalog/'
                'egypt_products_sample.json')
            .readAsStringSync()));
    addTearDown(() => ProductCatalogSource.shared = previous);
    late AppDatabase db;

    await tester.pumpWidget(SpendingApp(
      openDatabase: () => db = AppDatabase.forTesting(NativeDatabase.memory()),
    ));
    await tester.pumpAndSettle();

    final keys = await tester.runAsync(() async => {
          for (final c in await db.select(db.categories).get()) c.key,
          for (final s in await db.select(db.subcategories).get()) s.key,
        });
    expect(keys, containsAll(['Pantry', 'Pasta', 'Nectar']));

    await unmount(tester);
  });
}
