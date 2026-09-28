import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/spending_repository.dart';

/// The v3 repository behaviour (capture groups, attachments, aliases,
/// settings, recurring bills, barcode uniqueness, category colours), run
/// against both the drift repository and the in-memory fixture one, so a
/// widget test on the fixture sees the same rules the phone does.
///
/// [create] builds a fresh repository whose catalogue holds the ten seeded
/// categories and at least two items. It runs inside `setUp`, so it can
/// register its own cleanup with `addTearDown`. [today] is the day
/// `saveEntry` dates a new entry: the real date for drift, the fixture's
/// frozen 2026-09-06 for the fixture.
void runV3RepositoryContract(
  String name,
  Future<SpendingRepository> Function() create, {
  DateTime Function() today = DateTime.now,
}) {
  group('$name (v3 contract)', () {
    late SpendingRepository repo;

    setUp(() async => repo = await create());

    CaptureDraft twoLines({String? externalIdOfSecond}) => CaptureDraft(
          kind: CaptureKind.voice,
          date: DateTime(2026, 9, 20),
          paymentMethod: 'InstaPay',
          rawText: 'اتنين كيلو طماطم ب ٣٠ و عيش ب ١٠',
          parsedBy: 'local',
          lines: [
            const CaptureLine(
              amountPiastres: 3000,
              categoryKey: 'Food',
              subcategoryKey: 'Groceries',
              description: 'طماطم',
              quantityMilli: 2000,
              unit: 'kg',
              unitPricePiastres: 1500,
            ),
            CaptureLine(
              amountPiastres: 1000,
              categoryKey: 'Food',
              description: 'عيش',
              externalId: externalIdOfSecond,
              reference: 'IP-123',
            ),
          ],
          attachments: const [
            DraftAttachment(
              kind: AttachmentKind.voice,
              path: 'attachments/2026-09/v1.m4a',
              transcript: 'اتنين كيلو طماطم ب ٣٠ و عيش ب ١٠',
              durationMs: 4200,
            ),
          ],
        );

    test('saveCapture writes one entry per line under one capture group',
        () async {
      final groupId = await repo.saveCapture(twoLines());

      final group = await repo.captureGroup(groupId);
      expect(group, isNotNull);
      expect(group!.kind, CaptureKind.voice);
      expect(group.status, CaptureStatus.saved);
      expect(group.rawText, 'اتنين كيلو طماطم ب ٣٠ و عيش ب ١٠');
      expect(group.parsedBy, 'local');
      expect(group.date, DateTime(2026, 9, 20));

      expect(group.entries, hasLength(2));
      final tomato = group.entries.firstWhere((e) => e.description == 'طماطم');
      expect(tomato.amountPiastres, 3000);
      expect(tomato.quantityMilli, 2000);
      expect(tomato.unit, 'kg');
      expect(tomato.unitPricePiastres, 1500);
      expect(tomato.subcategoryKey, 'Groceries');
      expect(tomato.paymentMethod, 'InstaPay');
      expect(tomato.source, EntrySource.voice);
      expect(tomato.captureGroupId, groupId);
      expect(tomato.date, DateTime(2026, 9, 20));
      final bread = group.entries.firstWhere((e) => e.description == 'عيش');
      expect(bread.reference, 'IP-123');

      expect(group.attachments, hasLength(1));
      expect(group.attachments.single.kind, AttachmentKind.voice);
      expect(group.attachments.single.durationMs, 4200);
      expect(group.attachments.single.captureGroupId, groupId);

      expect(await repo.spentInMonth(2026, 9),
          greaterThanOrEqualTo(4000));
      final day = await repo.watchEntriesForDay(DateTime(2026, 9, 20)).first;
      expect(day.map((e) => e.id),
          containsAll(group.entries.map((e) => e.id)));
    });

    test('a capture group lists its lines in the order they were captured',
        () async {
      const names = ['عيش', 'طماطم', 'لبن', 'بيض', 'جبنة', 'أرز'];
      final groupId = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 9, 21),
        lines: [
          for (final name in names)
            CaptureLine(
                amountPiastres: 500, categoryKey: 'Food', description: name),
        ],
      ));

      final group = await repo.captureGroup(groupId);
      expect(group!.entries.map((e) => e.description), names);
    });

    test('an entry\'s attachments include its capture group\'s', () async {
      final groupId = await repo.saveCapture(twoLines());
      final entryId = (await repo.captureGroup(groupId))!.entries.first.id;

      final attachments = await repo.attachmentsForEntry(entryId);

      expect(attachments.map((a) => a.kind), [AttachmentKind.voice]);
    });

    test('a capture with no lines is kept as a note', () async {
      final before = await repo.spentInMonth(2026, 9);
      final groupId = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 9, 21),
        rawText: 'افتكر اجيب هدية',
        lines: const [],
      ));

      final group = await repo.captureGroup(groupId);
      expect(group!.status, CaptureStatus.note);
      expect(group.entries, isEmpty);
      expect(await repo.spentInMonth(2026, 9), before);
    });

    test('saveCapture saves nothing when one line is invalid', () async {
      final before = await repo.spentInMonth(2026, 9);
      final draft = CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 9, 22),
        lines: const [
          CaptureLine(amountPiastres: 500, categoryKey: 'Food'),
          CaptureLine(amountPiastres: 700, categoryKey: 'NoSuchCategory'),
        ],
      );

      await expectLater(repo.saveCapture(draft), throwsA(anything));

      expect(await repo.spentInMonth(2026, 9), before);
      expect(await repo.watchEntriesForDay(DateTime(2026, 9, 22)).first,
          isEmpty);
    });

    test('an import identity can only be written once', () async {
      await repo.saveCapture(twoLines(externalIdOfSecond: 'sn-001'));
      final before = await repo.spentInMonth(2026, 9);

      await expectLater(
          repo.saveCapture(twoLines(externalIdOfSecond: 'sn-001')),
          throwsA(anything));

      expect(await repo.spentInMonth(2026, 9), before);
      expect(await repo.knownExternalIds(), contains('sn-001'));
    });

    test('saveEntry stores an attached photo as a photo attachment',
        () async {
      await repo.saveEntry(const DraftEntry(
        amountPiastres: 2500,
        categoryKey: 'Food',
        description: 'فاتورة',
        source: EntrySource.manual,
        photoPath: 'photos/p1.jpg',
      ));
      final saved = (await repo.watchEntriesForDay(today()).first)
          .firstWhere((e) => e.displayName == 'فاتورة');

      final attachments = await repo.attachmentsForEntry(saved.id);

      expect(attachments, hasLength(1));
      expect(attachments.single.kind, AttachmentKind.photo);
      expect(attachments.single.path, 'photos/p1.jpg');
      expect(attachments.single.entryId, saved.id);
    });

    test('addAttachment links a text note to an existing entry', () async {
      final groupId = await repo.saveCapture(twoLines());
      final entryId = (await repo.captureGroup(groupId))!.entries.first.id;

      final added = await repo.addAttachment(
        entryId: entryId,
        attachment:
            const DraftAttachment(kind: AttachmentKind.text, text: 'مع أحمد'),
      );

      expect(added.entryId, entryId);
      expect((await repo.attachmentsForEntry(entryId)).map((a) => a.text),
          contains('مع أحمد'));
    });

    test('addAttachment refuses an attachment with no owner', () async {
      expect(
        () => repo.addAttachment(
            attachment: const DraftAttachment(
                kind: AttachmentKind.text, text: 'x')),
        throwsArgumentError,
      );
    });

    test('learned aliases are stored normalised and can be re-pointed',
        () async {
      final items = await repo.allItems();
      await repo.learnAlias('إندومى', items[0].id);
      expect(await repo.itemAliases(), {'اندومي': items[0].id});

      await repo.learnAlias('اندومي', items[1].id);
      expect(await repo.itemAliases(), {'اندومي': items[1].id});
    });

    test('settings round-trip and overwrite', () async {
      expect(await repo.setting('theme'), isNull);
      await repo.setSetting('theme', 'dark');
      await repo.setSetting('theme', 'system');
      expect(await repo.setting('theme'), 'system');
    });

    test('settings refuse anything that looks like a secret', () async {
      for (final key in [
        'geminiApiKey',
        'api_key',
        'authToken',
        'secret',
        'gemini_key',
        'geminiKey',
      ]) {
        expect(() => repo.setSetting(key, 'x'), throwsArgumentError,
            reason: key);
      }
    });

    test('settings accept the benign keys the app stores', () async {
      for (final key in [
        'theme',
        'gemini_model',
        'online_master',
        'online_gemini',
        'last_payment_method',
        'barcode_lookup_stamp',
      ]) {
        await repo.setSetting(key, 'x');
        expect(await repo.setting(key), 'x', reason: key);
      }
    });

    test('recurring bills: create, list by due date, update, archive',
        () async {
      final internet = await repo.createRecurringBill(
        nameAr: 'إنترنت المنزل',
        amountPiastres: 30000,
        categoryKey: 'Bills',
        subcategoryKey: 'HomeInternet',
        nextDue: DateTime(2026, 10, 27),
      );
      final phone = await repo.createRecurringBill(
        nameAr: 'فاتورة موبايل',
        amountPiastres: 10000,
        categoryKey: 'Bills',
        nextDue: DateTime(2026, 10, 5),
        remindDaysBefore: 3,
      );
      expect(internet.everyMonths, 1);
      expect(internet.remindDaysBefore, 2);

      expect((await repo.recurringBills()).map((b) => b.id),
          [phone.id, internet.id]);

      await repo.updateRecurringBill(RecurringBillView(
        id: phone.id,
        nameAr: phone.nameAr,
        amountPiastres: 12000,
        categoryKey: 'Bills',
        everyMonths: 1,
        nextDue: DateTime(2026, 11, 5),
        remindDaysBefore: 3,
      ));
      final updated =
          (await repo.recurringBills()).firstWhere((b) => b.id == phone.id);
      expect(updated.amountPiastres, 12000);
      expect(updated.nextDue, DateTime(2026, 11, 5));

      await repo.archiveRecurringBill(internet.id);
      expect((await repo.recurringBills()).map((b) => b.id), [phone.id]);
    });

    test('a barcode belongs to one non-archived item at a time', () async {
      final first = await repo.createItem(
          nameAr: 'بيبسي كانز', categoryKey: 'Drinks', barcode: '6221');

      await expectLater(
        repo.createItem(
            nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6221'),
        throwsA(isA<DuplicateBarcodeException>()),
      );

      await repo.archiveItem(first.id);
      final second = await repo.createItem(
          nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6221');
      expect((await repo.itemByBarcode('6221'))!.id, second.id);
    });

    test('unarchiveItem refuses to bring back a barcode another item holds',
        () async {
      final first = await repo.createItem(
          nameAr: 'بيبسي كانز', categoryKey: 'Drinks', barcode: '6221');
      await repo.archiveItem(first.id);
      final second = await repo.createItem(
          nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6221');

      await expectLater(repo.unarchiveItem(first.id),
          throwsA(isA<DuplicateBarcodeException>()));

      expect((await repo.archivedItems()).map((i) => i.id), contains(first.id));
      expect((await repo.itemByBarcode('6221'))!.id, second.id);
    });

    test('unarchiveCategory leaves an item whose barcode is now taken archived',
        () async {
      final old = await repo.createItem(
          nameAr: 'بيبسي كانز', categoryKey: 'Drinks', barcode: '6221');
      final plain =
          await repo.createItem(nameAr: 'مياه', categoryKey: 'Drinks');
      await repo.archiveCategory('Drinks');
      final replacement = await repo.createItem(
          nameAr: 'بيبسي', categoryKey: 'Food', barcode: '6221');

      await repo.unarchiveCategory('Drinks');

      final visible = (await repo.allItems()).map((i) => i.id);
      expect(visible, contains(plain.id));
      expect(visible, isNot(contains(old.id)));
      expect((await repo.archivedItems()).map((i) => i.id), contains(old.id));
      expect((await repo.itemByBarcode('6221'))!.id, replacement.id);
    });

    test(
        'unarchiveSubcategory leaves an item whose barcode is now taken '
        'archived', () async {
      final old = await repo.createItem(
          nameAr: 'طماطم معلبة',
          categoryKey: 'Food',
          subcategoryKey: 'Groceries',
          barcode: '6222');
      final plain = await repo.createItem(
          nameAr: 'خيار', categoryKey: 'Food', subcategoryKey: 'Groceries');
      await repo.archiveSubcategory('Groceries');
      final replacement = await repo.createItem(
          nameAr: 'صلصة', categoryKey: 'Food', barcode: '6222');

      await repo.unarchiveSubcategory('Groceries');

      final visible = (await repo.allItems()).map((i) => i.id);
      expect(visible, contains(plain.id));
      expect(visible, isNot(contains(old.id)));
      expect((await repo.itemByBarcode('6222'))!.id, replacement.id);
    });

    test('a cascade restores only one of two archived items sharing a barcode',
        () async {
      final a = await repo.createItem(
          nameAr: 'بيبسي كانز', categoryKey: 'Drinks', barcode: '6223');
      await repo.archiveItem(a.id);
      final b = await repo.createItem(
          nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6223');
      await repo.archiveCategory('Drinks');

      await repo.unarchiveCategory('Drinks');

      final holders = (await repo.allItems())
          .where((i) => i.barcode == '6223')
          .map((i) => i.id);
      expect(holders, hasLength(1));
      expect([a.id, b.id], contains(holders.single));
      expect((await repo.itemByBarcode('6223'))!.id, holders.single);
    });

    test('categories carry a colour key', () async {
      final categories = await repo.categories();
      expect(categories.firstWhere((c) => c.key == 'Drinks').colorKey,
          'Drinks');

      final created = await repo.createCategory(
          key: 'cat-1', labelAr: 'قهوة', iconName: 'local_cafe');
      expect(created.colorKey, 'Other');

      await repo.updateCategory(
          key: 'cat-1',
          labelAr: 'قهوة',
          iconName: 'local_cafe',
          colorKey: 'Drinks');
      expect(
          (await repo.categories()).firstWhere((c) => c.key == 'cat-1').colorKey,
          'Drinks');
    });

    // ---- dashboard and add sheet (B1) ----

    test('a draft capture is kept with no entries and listed for review',
        () async {
      final spentBefore = await repo.spentBetween(
          DateTime(2026, 9, 21), DateTime(2026, 9, 21));
      final older = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.voice,
        date: DateTime(2026, 9, 21),
        rawText: 'عيش ب ١٠',
        lines: const [],
        isDraft: true,
        attachments: const [
          DraftAttachment(
              kind: AttachmentKind.voice, path: 'attachments/2026-09/a.m4a'),
        ],
      ));
      final newer = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 9, 21),
        rawText: 'طماطم ٣٠',
        lines: const [],
        isDraft: true,
      ));
      await repo.saveCapture(twoLines());

      final drafts = await repo.watchDraftCaptures().first;
      expect(drafts.map((d) => d.id), [newer, older]);
      expect(drafts.every((d) => d.status == CaptureStatus.draft), isTrue);
      expect(drafts.last.rawText, 'عيش ب ١٠');
      expect(drafts.last.attachments.single.kind, AttachmentKind.voice);
      // Nothing unreviewed counts toward a total.
      expect(
          await repo.spentBetween(
              DateTime(2026, 9, 21), DateTime(2026, 9, 21)),
          spentBefore);
    });

    test('a draft may not carry lines: they would count before review',
        () async {
      await expectLater(
        repo.saveCapture(CaptureDraft(
          kind: CaptureKind.text,
          date: DateTime(2026, 9, 21),
          isDraft: true,
          lines: const [
            CaptureLine(
                amountPiastres: 100, categoryKey: 'Food', description: 'x'),
          ],
        )),
        throwsArgumentError,
      );
      expect(await repo.watchDraftCaptures().first, isEmpty);
    });

    test('spentBetween and spendByCategoryBetween count whole days inclusive',
        () async {
      final day = DateTime(2026, 9, 20);
      final before = await repo.spentBetween(day, day);
      final foodBefore =
          (await repo.spendByCategoryBetween(day, day))['Food'] ?? 0;
      final nextDays =
          await repo.spentBetween(DateTime(2026, 9, 21), DateTime(2026, 9, 30));

      await repo.saveCapture(twoLines());

      expect(await repo.spentBetween(day, day), before + 4000);
      expect((await repo.spendByCategoryBetween(day, day))['Food'],
          foodBefore + 4000);
      // An open end counts everything from the start on.
      expect(
          (await repo.spendByCategoryBetween(day, null))['Food'],
          greaterThanOrEqualTo(foodBefore + 4000));
      expect(
          await repo.spentBetween(DateTime(2026, 9, 21), DateTime(2026, 9, 30)),
          nextDays);
    });

    test('saveEntry remembers the payment method for the next add', () async {
      expect(await repo.setting(lastPaymentMethodSettingKey), isNull);
      final item = (await repo.topItems(1)).single;
      await repo.saveEntry(DraftEntry(
        amountPiastres: 500,
        itemId: item.id,
        description: item.nameAr,
        categoryKey: item.categoryKey,
        paymentMethod: 'InstaPay',
        source: EntrySource.quickPick,
      ));
      expect(await repo.setting(lastPaymentMethodSettingKey), 'InstaPay');
    });

    test('recentItems puts the last used item first with its last price',
        () async {
      final items = await repo.topItems(2);
      final used = items.last;
      for (final amount in [1500, 1750]) {
        await repo.saveEntry(DraftEntry(
          amountPiastres: amount,
          itemId: used.id,
          description: used.nameAr,
          categoryKey: used.categoryKey,
          source: EntrySource.quickPick,
        ));
      }

      final recent = await repo.recentItems(8);
      expect(recent.length, lessThanOrEqualTo(8));
      expect(recent.first.id, used.id);
      expect(recent.first.lastAmountPiastres, 1750);
      expect(recent.first.suggestedAmountPiastres, 1750);
    });
  });
}
