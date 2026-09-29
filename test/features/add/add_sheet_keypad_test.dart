import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/barcode_scan_service.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/photo_capture_service.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/add/add_sheet.dart';
import 'package:spending_tracker/core/design/app_icons.dart';

/// The add sheet is keypad first (spec §6.1): type or calculate an amount,
/// pick a category or an item, save.
class _Photos implements PhotoCaptureService {
  int camera = 0;
  int gallery = 0;
  @override
  Future<PhotoCaptureResult> captureFromCamera() async {
    camera++;
    return const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);
  }

  @override
  Future<PhotoCaptureResult> pickFromGallery() async {
    gallery++;
    return const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Scanner implements BarcodeScanService {
  int calls = 0;
  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    return null;
  }

  @override
  Future<List<String>> scanMany(BuildContext context) async => const [];
}

/// A fixture whose stored settings arrive only when [release] is called,
/// to race the user against the last payment method loading.
class _SlowSettings extends FixtureSpendingRepository {
  final _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<String?> setting(String key) async {
    await _gate.future;
    return super.setting(key);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  FixtureSpendingRepository? repository,
  FutureOr<void> Function(DraftEntry)? onSubmit,
  AddSheetAction? initialAction,
  PhotoCaptureService? photos,
  BarcodeScanService? scanner,
}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddSheet(
            repository: repository ?? FixtureSpendingRepository(),
            onSubmit: onSubmit ?? (_) {},
            initialAction: initialAction,
            photoCaptureService: photos,
            barcodeScanService: scanner,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String keys) async {
  for (final key in keys.split('')) {
    await tester.tap(find.byKey(Key('key-$key')));
    await tester.pump();
  }
}

/// Chip rows scroll sideways; bring the chip into view before tapping it.
Future<void> _tapChip(WidgetTester tester, String key) async {
  final chip = find.byKey(Key(key));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
}

Finder get _save => find.byKey(const Key('save-button'));
bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_save).onPressed != null;

void main() {
  testWidgets('the keypad calculates live and saves the result in piastres', (
    tester,
  ) async {
    DraftEntry? saved;
    await _pump(tester, onSubmit: (d) => saved = d);

    await _type(tester, '2×35+10');
    expect(find.text('2×35+10'), findsOneWidget);
    expect(find.text('= 80'), findsOneWidget);

    // No category yet: nothing to file it under.
    expect(_saveEnabled(tester), isFalse);
    await _tapChip(tester, 'category-Food');
    await tester.pumpAndSettle();
    expect(_saveEnabled(tester), isTrue);

    await tester.tap(_save);
    expect(saved!.amountPiastres, 8000);
    expect(saved!.categoryKey, 'Food');
    expect(saved!.itemId, isNull);
    expect(saved!.source, EntrySource.manual);
  });

  testWidgets('backspace removes the last key, and a zero total cannot save', (
    tester,
  ) async {
    await _pump(tester);
    await _tapChip(tester, 'category-Food');
    await tester.pumpAndSettle();
    await _type(tester, '12');
    await tester.tap(find.byKey(const Key('key-backspace')));
    await tester.pump();
    expect(find.byKey(const Key('amount-expression')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('amount-expression'))).data,
      '1',
    );
    await tester.tap(find.byKey(const Key('key-backspace')));
    await _type(tester, '0');
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('two operators in a row keep only the last one', (tester) async {
    await _pump(tester);
    await _type(tester, '5+×2');
    expect(
      tester.widget<Text>(find.byKey(const Key('amount-expression'))).data,
      '5×2',
    );
  });

  testWidgets(
    'recent chips, eight at most, fill the last price, category and item',
    (tester) async {
      final repository = FixtureSpendingRepository();
      // عصير last cost 22.50, not its catalogue default.
      await repository.saveEntry(
        const DraftEntry(
          amountPiastres: 2250,
          itemId: 'i9',
          description: 'عصير',
          categoryKey: 'Drinks',
          subcategoryKey: 'Juice',
          source: EntrySource.quickPick,
        ),
      );
      DraftEntry? saved;
      await _pump(tester, repository: repository, onSubmit: (d) => saved = d);

      final chips = find.descendant(
        of: find.byKey(const Key('recent-chips')),
        matching: find.byType(InkWell),
      );
      expect(chips, findsNWidgets(8));

      // The most used comes first.
      await _tapChip(tester, 'recent-i9');
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('amount-expression'))).data,
        '22.50',
      );
      await tester.tap(_save);
      expect(saved!.amountPiastres, 2250);
      expect(saved!.itemId, 'i9');
      expect(saved!.categoryKey, 'Drinks');
      expect(saved!.subcategoryKey, 'Juice');
    },
  );

  testWidgets(
    'after a chip fills the amount, a digit starts over and an operator '
    'builds on it',
    (tester) async {
      DraftEntry? saved;
      await _pump(tester, onSubmit: (d) => saved = d);
      await tester.tap(find.byKey(const Key('recent-i1'))); // شويبس, 40
      await tester.pumpAndSettle();
      await _type(tester, '×3');
      expect(find.text('= 120'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recent-i1')));
      await tester.pumpAndSettle();
      await _type(tester, '35');
      await tester.tap(_save);
      expect(saved!.amountPiastres, 3500);
      expect(saved!.itemId, 'i1');
    },
  );

  testWidgets('payment method starts on the last one used', (tester) async {
    final repository = FixtureSpendingRepository();
    await repository.setSetting(lastPaymentMethodSettingKey, 'InstaPay');
    DraftEntry? saved;
    await _pump(tester, repository: repository, onSubmit: (d) => saved = d);

    await tester.tap(find.byKey(const Key('recent-i1')));
    await tester.pumpAndSettle();
    await tester.tap(_save);
    expect(saved!.paymentMethod, 'InstaPay');

    await _tapChip(tester, 'payment-Cash');
    await tester.pumpAndSettle();
    await tester.tap(_save);
    expect(saved!.paymentMethod, 'Cash');
  });

  testWidgets('a stored payment method outside the list is still offered', (
    tester,
  ) async {
    final repository = FixtureSpendingRepository();
    await repository.setSetting(lastPaymentMethodSettingKey, 'Etisalat');
    await _pump(tester, repository: repository);
    expect(find.byKey(const Key('payment-Etisalat')), findsOneWidget);
  });

  testWidgets('initialAction camera opens the camera once the sheet is up', (
    tester,
  ) async {
    final photos = _Photos();
    await _pump(tester, initialAction: AddSheetAction.camera, photos: photos);
    expect(photos.camera, 1);
    expect(photos.gallery, 0);
  });

  testWidgets('initialAction gallery opens the gallery', (tester) async {
    final photos = _Photos();
    await _pump(tester, initialAction: AddSheetAction.gallery, photos: photos);
    expect(photos.gallery, 1);
  });

  testWidgets('initialAction barcode opens the scanner', (tester) async {
    final scanner = _Scanner();
    await _pump(
      tester,
      initialAction: AddSheetAction.barcode,
      scanner: scanner,
    );
    expect(scanner.calls, 1);
  });

  testWidgets('every keypad key clears the 48dp tap target', (tester) async {
    await _pump(tester);
    for (final key in [
      ...'0123456789.'.split(''),
      '+',
      '−',
      '×',
      '÷',
      'backspace',
    ]) {
      final size = tester.getSize(find.byKey(Key('key-$key')));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
  });

  testWidgets(
    'a selected category chip wears its ink at 16% with a 1.5dp border and '
    'a check (spec §7.3)',
    (tester) async {
      await _pump(tester);
      await _tapChip(tester, 'category-Drinks');
      await tester.pumpAndSettle();
      final chip = find.byKey(const Key('category-Drinks'));
      expect(
        find.descendant(of: chip, matching: find.byIcon(AppIcons.check)),
        findsOneWidget,
      );
      final box = tester.widget<AnimatedContainer>(
        find.descendant(of: chip, matching: find.byType(AnimatedContainer)),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect((decoration.border! as Border).top.width, 1.5);
      expect(decoration.color!.a, closeTo(0.16, 0.01));
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    },
  );

  testWidgets('a quick double tap on حفظ saves once', (tester) async {
    final pending = Completer<void>();
    var submits = 0;
    await _pump(
      tester,
      onSubmit: (_) {
        submits++;
        return pending.future;
      },
    );
    await tester.tap(find.byKey(const Key('recent-i1')));
    await tester.pumpAndSettle();

    await tester.tap(_save);
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
    await tester.tap(_save, warnIfMissed: false);
    await tester.pump();
    expect(submits, 1);

    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failed save says so and lets the user try again', (
    tester,
  ) async {
    await _pump(tester, onSubmit: (_) async => throw StateError('disk full'));
    await tester.tap(find.byKey(const Key('recent-i1')));
    await tester.pumpAndSettle();

    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-failed')), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('a payment method picked before the stored one loads is kept', (
    tester,
  ) async {
    final repository = _SlowSettings();
    await repository.setSetting(lastPaymentMethodSettingKey, 'InstaPay');
    DraftEntry? saved;
    await _pump(tester, repository: repository, onSubmit: (d) => saved = d);

    await _tapChip(tester, 'payment-Card');
    await tester.pumpAndSettle();
    repository.release();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recent-i1')));
    await tester.pumpAndSettle();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(saved!.paymentMethod, 'Card');
  });
}
