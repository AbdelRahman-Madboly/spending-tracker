import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spending_tracker/app.dart';
import 'package:spending_tracker/data/backup/data_transfer.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/features/shell/app_shell.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('the app hands Settings a host that reopens its database', (
    tester,
  ) async {
    final docs = Directory.systemTemp.createTempSync('app-reopen');
    addTearDown(() => docs.deleteSync(recursive: true));
    final file = File(p.join(docs.path, 'spending.sqlite'));
    final opened = <AppDatabase>[];

    await tester.pumpWidget(
      SpendingApp(
        openDatabase: () {
          final db = AppDatabase.forTesting(NativeDatabase(file));
          opened.add(db);
          return db;
        },
        documentsDirectory: () async => docs,
      ),
    );
    await tester.pumpAndSettle();

    final host = DatabaseHostScope.maybeOf(
      tester.element(find.byType(AppShell)),
    )!;
    expect(await host.documentsDirectory(), docs);
    expect(host.database, same(opened.single));

    var ranWhileClosed = false;
    final shellBefore = tester.widget<AppShell>(find.byType(AppShell));
    final done = host.reopenAfter(() async {
      // The old connection is closed while the files are swapped.
      try {
        await opened.first.customSelect('SELECT 1').get();
      } on StateError {
        ranWhileClosed = true;
      }
    });
    // The frame that takes every screen off the old database.
    await tester.pump();
    expect(find.byType(AppShell), findsNothing);
    var finished = false;
    done.then((_) => finished = true);
    for (var i = 0; i < 50 && !finished; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(finished, isTrue);
    await tester.pumpAndSettle();

    expect(ranWhileClosed, isTrue);
    expect(opened, hasLength(2));
    expect(host.database, same(opened.last));
    final shellAfter = tester.widget<AppShell>(find.byType(AppShell));
    expect(shellAfter.repository, isNot(same(shellBefore.repository)));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
