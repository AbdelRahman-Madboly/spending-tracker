import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_theme.dart';
import 'package:spending_tracker/data/backup/backup_service.dart';
import 'package:spending_tracker/data/backup/data_transfer.dart';
import 'package:spending_tracker/data/export/spending_export.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/features/settings/settings_screen.dart';
import 'package:spending_tracker/features/settings/widgets/data_settings_section.dart';

/// Records what the section asks for; no files or database involved.
class _Transfer implements DataTransfer {
  final exported = <ExportScope>[];
  int backups = 0;
  int discarded = 0;
  final restored = <StagedRestore>[];
  StagedRestore? toStage = StagedRestore(Directory('staged'));
  Object? stageError;
  bool saveResult = true;

  @override
  Future<ExportPeriods> exportPeriods() async => const ExportPeriods(
    months: [(year: 2026, month: 9), (year: 2026, month: 8)],
    years: [2026],
  );

  @override
  Future<bool> exportWorkbook(ExportScope scope) async {
    exported.add(scope);
    return saveResult;
  }

  @override
  Future<bool> backupNow() async {
    backups++;
    return saveResult;
  }

  @override
  Future<StagedRestore?> pickAndStage() async {
    if (stageError case final e?) throw e;
    return toStage;
  }

  @override
  Future<void> discard() async => discarded++;

  @override
  Future<File> restore(StagedRestore staged) async {
    restored.add(staged);
    return File('backups/pre-restore.zip');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Transfer transfer;

  setUp(() => transfer = _Transfer());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ListView(children: [DataSettingsSection(transfer: transfer)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('export offers everything, each year and each month', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.byKey(const Key('settings-data-export')));
    expect(find.text('كل حاجة'), findsOneWidget);
    expect(find.text('سنة 2026'), findsOneWidget);
    expect(find.text('سبتمبر 2026'), findsOneWidget);
    await tap(tester, find.text('أغسطس 2026'));
    expect(transfer.exported.single.year, 2026);
    expect(transfer.exported.single.month, 8);
    expect(find.text('اتحفظ الملف'), findsOneWidget);
  });

  testWidgets('a full backup goes to the save screen', (tester) async {
    await pump(tester);
    await tap(tester, find.byKey(const Key('settings-data-backup')));
    expect(transfer.backups, 1);
    expect(find.text('اتحفظت النسخة الاحتياطية'), findsOneWidget);
  });

  testWidgets('restore asks first, and cancelling changes nothing', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.byKey(const Key('settings-data-restore')));
    expect(find.byKey(const Key('restore-confirm')), findsOneWidget);
    expect(find.textContaining('نسخة احتياطية تلقائية'), findsOneWidget);
    await tap(tester, find.text('إلغاء'));
    expect(transfer.restored, isEmpty);
    expect(transfer.discarded, 1);
  });

  testWidgets('confirming restores the staged backup', (tester) async {
    await pump(tester);
    await tap(tester, find.byKey(const Key('settings-data-restore')));
    await tap(tester, find.byKey(const Key('restore-confirm-yes')));
    expect(transfer.restored, hasLength(1));
    expect(find.textContaining('رجعت البيانات'), findsOneWidget);
  });

  testWidgets('a file that is not a backup is refused with its reason', (
    tester,
  ) async {
    transfer.stageError = const BackupFormatException(
      'الملف ده مش نسخة احتياطية',
    );
    await pump(tester);
    await tap(tester, find.byKey(const Key('settings-data-restore')));
    expect(find.byKey(const Key('restore-confirm')), findsNothing);
    expect(find.text('الملف ده مش نسخة احتياطية'), findsOneWidget);
  });

  testWidgets('backing out of the picker does nothing', (tester) async {
    transfer.toStage = null;
    await pump(tester);
    await tap(tester, find.byKey(const Key('settings-data-restore')));
    expect(find.byKey(const Key('restore-confirm')), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Settings shows البيانات with the data section', (tester) async {
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsScreen(
            repository: FixtureSpendingRepository(),
            dataTransfer: transfer,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-data-backup')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('البيانات'), findsOneWidget);
    await tap(tester, find.byKey(const Key('settings-data-backup')));
    expect(transfer.backups, 1);
  });
}
