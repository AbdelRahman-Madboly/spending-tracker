import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/barcode_scan.dart';
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

    CaptureDraft transfer(String reference, {DateTime? date}) => CaptureDraft(
          kind: CaptureKind.photo,
          date: date ?? DateTime(2026, 9, 21),
          paymentMethod: 'InstaPay',
          lines: [
            CaptureLine(
              amountPiastres: 50000,
              categoryKey: 'Food',
              description: 'تحويل إنستاباي',
              reference: reference,
            ),
          ],
        );

    test('a payment reference already recorded is refused, saving nothing',
        () async {
      await repo.saveCapture(transfer('512345678901'));
      final before = await repo.spentInMonth(2026, 9);
      expect(await repo.referenceExists('512345678901'), isTrue);
      expect(await repo.referenceExists('999'), isFalse);

      await expectLater(
          repo.saveCapture(transfer('512345678901', date: DateTime(2026, 9, 22))),
          throwsA(isA<DuplicateReferenceException>()
              .having((e) => e.reference, 'reference', '512345678901')));

      expect(await repo.spentInMonth(2026, 9), before);
      expect(await repo.watchEntriesForDay(DateTime(2026, 9, 22)).first,
          isEmpty);
    });

    test("a deleted entry's reference can be recorded again", () async {
      await repo.saveCapture(transfer('77'));
      final id = (await repo.watchEntriesForDay(DateTime(2026, 9, 21)).first)
          .single
          .id;
      await repo.deleteEntries([id]);

      expect(await repo.referenceExists('77'), isFalse);
      await repo.saveCapture(transfer('77'));
    });

    test('one capture cannot carry the same reference twice', () async {
      final line = transfer('88').lines.single;
      await expectLater(
          repo.saveCapture(CaptureDraft(
            kind: CaptureKind.photo,
            date: DateTime(2026, 9, 21),
            lines: [line, line],
          )),
          throwsA(isA<DuplicateReferenceException>()));
      expect(await repo.referenceExists('88'), isFalse);
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
  
    // ---- السجل and entry detail (B2) ----

    Future<List<TransactionView>> transactionsOn(DateTime day) async =>
        (await repo.watchTransactions().first)
            .where((t) => t.date == day)
            .toList();

    test('watchTransactions lists live entries with labels and attachments',
        () async {
      final groupId = await repo.saveCapture(twoLines());
      final lines = (await repo.captureGroup(groupId))!.entries;
      await repo.addAttachment(
        entryId: lines.last.id,
        attachment:
            const DraftAttachment(kind: AttachmentKind.text, text: 'مع أحمد'),
      );

      final day = await transactionsOn(DateTime(2026, 9, 20));

      expect(day.map((t) => t.id), unorderedEquals(lines.map((l) => l.id)));
      final tomato = day.firstWhere((t) => t.description == 'طماطم');
      expect(tomato.amountPiastres, 3000);
      expect(tomato.categoryKey, 'Food');
      expect(tomato.categoryLabelAr, isNotEmpty);
      expect(tomato.subcategoryKey, 'Groceries');
      expect(tomato.subcategoryLabelAr, isNotEmpty);
      expect(tomato.paymentMethod, 'InstaPay');
      expect(tomato.captureGroupId, groupId);
      expect(tomato.source, EntrySource.voice);
      // The group's voice note belongs to every line.
      expect(tomato.attachmentKinds, {AttachmentKind.voice});
      expect(tomato.attachmentText, contains(startsWith('اتنين كيلو')));
      final bread = day.firstWhere((t) => t.description == 'عيش');
      expect(bread.attachmentKinds,
          {AttachmentKind.voice, AttachmentKind.text});
      expect(bread.attachmentText, contains('مع أحمد'));
    });

    test('watchTransactions names an item-only entry after its item',
        () async {
      final item = (await repo.topItems(1)).single;
      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.manual,
        date: DateTime(2026, 9, 23),
        lines: [
          CaptureLine(
              amountPiastres: 900,
              categoryKey: item.categoryKey,
              itemId: item.id),
        ],
      ));

      final t = (await transactionsOn(DateTime(2026, 9, 23))).single;
      expect(t.itemNameAr, item.nameAr);
      expect(t.name, item.nameAr);
    });

    test('updateEntry rewrites the editable fields everywhere', () async {
      final groupId = await repo.saveCapture(twoLines());
      final original = (await repo.captureGroup(groupId))!.entries.first;

      await repo.updateEntry(EntryRecord(
        id: original.id,
        date: DateTime(2026, 9, 19),
        amountPiastres: 4250,
        categoryKey: 'Drinks',
        description: 'عصير',
        paymentMethod: 'Cash',
        source: original.source,
        quantityMilli: 1500,
        unit: 'liter',
        note: 'من الكشك',
      ));

      final edited = await repo.entry(original.id);
      expect(edited, isNotNull);
      expect(edited!.date, DateTime(2026, 9, 19));
      expect(edited.amountPiastres, 4250);
      expect(edited.categoryKey, 'Drinks');
      expect(edited.subcategoryKey, isNull);
      expect(edited.description, 'عصير');
      expect(edited.paymentMethod, 'Cash');
      expect(edited.quantityMilli, 1500);
      expect(edited.unit, 'liter');
      expect(edited.note, 'من الكشك');
      // Identity fields are not the editor's to change.
      expect(edited.captureGroupId, groupId);
      expect(edited.source, EntrySource.voice);

      expect(await repo.spentBetween(DateTime(2026, 9, 19), DateTime(2026, 9, 19)),
          4250);
      final moved = await transactionsOn(DateTime(2026, 9, 19));
      expect(moved.single.description, 'عصير');
      expect(moved.single.categoryKey, 'Drinks');
    });

    test('deleteEntries hides entries until restoreEntries brings them back',
        () async {
      final groupId = await repo.saveCapture(twoLines());
      final lines = (await repo.captureGroup(groupId))!.entries;
      final day = DateTime(2026, 9, 20);
      final spent = await repo.spentBetween(day, day);

      await repo.deleteEntries([lines.first.id]);

      expect(await repo.entry(lines.first.id), isNull);
      expect((await transactionsOn(day)).map((t) => t.id), [lines.last.id]);
      expect((await repo.watchEntriesForDay(day).first).map((e) => e.id),
          isNot(contains(lines.first.id)));
      expect(await repo.spentBetween(day, day),
          spent - lines.first.amountPiastres);
      expect((await repo.captureGroup(groupId))!.entries.map((e) => e.id),
          [lines.last.id]);

      await repo.restoreEntries([lines.first.id]);

      expect(await repo.entry(lines.first.id), isNotNull);
      expect(await repo.spentBetween(day, day), spent);
      expect((await repo.captureGroup(groupId))!.entries.map((e) => e.id),
          lines.map((l) => l.id));
    });

    test('recategorizeEntries moves entries and clears their subcategory',
        () async {
      final groupId = await repo.saveCapture(twoLines());
      final ids = (await repo.captureGroup(groupId))!
          .entries
          .map((e) => e.id)
          .toList();

      await repo.recategorizeEntries(ids, 'Bills');

      for (final id in ids) {
        final e = (await repo.entry(id))!;
        expect(e.categoryKey, 'Bills');
        expect(e.subcategoryKey, isNull);
      }
    });

    test('duplicateEntry copies an entry to another day on its own',
        () async {
      final groupId = await repo.saveCapture(twoLines(externalIdOfSecond: 'x-1'));
      final bread = (await repo.captureGroup(groupId))!
          .entries
          .firstWhere((e) => e.description == 'عيش');

      final copyId = await repo.duplicateEntry(bread.id, DateTime(2026, 9, 24));

      final copy = (await repo.entry(copyId))!;
      expect(copyId, isNot(bread.id));
      expect(copy.date, DateTime(2026, 9, 24));
      expect(copy.amountPiastres, bread.amountPiastres);
      expect(copy.categoryKey, bread.categoryKey);
      expect(copy.description, 'عيش');
      expect(copy.paymentMethod, 'InstaPay');
      // A copy is its own spend: no capture group, no import identity.
      expect(copy.captureGroupId, isNull);
      expect(copy.externalId, isNull);
      expect(await repo.spentBetween(DateTime(2026, 9, 24), DateTime(2026, 9, 24)),
          bread.amountPiastres);
    });

    // ---- the review sheet (C2) ----

    Future<String> keepDraft() => repo.saveCapture(CaptureDraft(
          kind: CaptureKind.voice,
          date: DateTime(2026, 9, 22),
          rawText: 'عيش ب ١٠',
          lines: const [],
          isDraft: true,
          attachments: const [
            DraftAttachment(
                kind: AttachmentKind.voice, path: 'attachments/2026-09/d.m4a'),
          ],
        ));

    test('saving a reviewed draft turns that draft into the saved capture',
        () async {
      final draftId = await keepDraft();

      final savedId = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.voice,
        date: DateTime(2026, 9, 22),
        paymentMethod: 'Card',
        rawText: 'something else',
        draftId: draftId,
        lines: const [
          CaptureLine(amountPiastres: 1000, categoryKey: 'Food', description: 'عيش'),
        ],
        attachments: const [
          DraftAttachment(kind: AttachmentKind.text, text: 'من الفرن'),
        ],
      ));

      expect(savedId, draftId);
      expect(await repo.watchDraftCaptures().first, isEmpty);
      final group = (await repo.captureGroup(draftId))!;
      expect(group.status, CaptureStatus.saved);
      // The raw text is what was captured, never rewritten by review.
      expect(group.rawText, 'عيش ب ١٠');
      expect(group.entries.single.description, 'عيش');
      expect(group.entries.single.captureGroupId, draftId);
      expect(group.entries.single.paymentMethod, 'Card');
      expect(group.attachments.map((a) => a.kind),
          [AttachmentKind.voice, AttachmentKind.text]);
    });

    test('a draft with no text keeps the text typed at review', () async {
      // A voice note no recogniser heard: the audio, and no words yet.
      final draftId = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.voice,
        date: DateTime(2026, 9, 22),
        lines: const [],
        isDraft: true,
        attachments: const [
          DraftAttachment(
              kind: AttachmentKind.voice, path: 'attachments/2026-09/e.m4a'),
        ],
      ));

      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.voice,
        date: DateTime(2026, 9, 22),
        rawText: 'عيش ب 10',
        draftId: draftId,
        lines: const [
          CaptureLine(amountPiastres: 1000, categoryKey: 'Food', description: 'عيش'),
        ],
      ));

      final group = (await repo.captureGroup(draftId))!;
      expect(group.rawText, 'عيش ب 10');
    });

    test('a reviewed draft kept as a note leaves Needs review', () async {
      final draftId = await keepDraft();

      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.voice,
        date: DateTime(2026, 9, 22),
        draftId: draftId,
        lines: const [],
      ));

      expect(await repo.watchDraftCaptures().first, isEmpty);
      final group = (await repo.captureGroup(draftId))!;
      expect(group.status, CaptureStatus.note);
      expect(group.attachments, hasLength(1));
    });

    test('saveCapture refuses a draft id that is not a draft', () async {
      final saved = await repo.saveCapture(twoLines());
      final before = await repo.spentInMonth(2026, 9);
      CaptureDraft onto(String id) => CaptureDraft(
            kind: CaptureKind.text,
            date: DateTime(2026, 9, 22),
            draftId: id,
            lines: const [
              CaptureLine(amountPiastres: 100, categoryKey: 'Food'),
            ],
          );

      await expectLater(repo.saveCapture(onto(saved)), throwsStateError);
      await expectLater(repo.saveCapture(onto('no-such-id')), throwsStateError);
      expect(await repo.spentInMonth(2026, 9), before);
    });

    test('saveCapture learns aliases, item prices and the payment method',
        () async {
      final item = (await repo.allItems()).first;
      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 9, 22),
        paymentMethod: 'InstaPay',
        lines: [
          CaptureLine(
            amountPiastres: 3000,
            categoryKey: item.categoryKey,
            itemId: item.id,
            description: item.nameAr,
            quantityMilli: 2000,
            aliasToLearn: 'انودى',
          ),
        ],
      ));

      expect((await repo.itemAliases())['انودي'], item.id);
      final updated =
          (await repo.allItems()).firstWhere((i) => i.id == item.id);
      // The default is the price of one: 30 for two is 15.
      expect(updated.defaultAmountPiastres, 1500);
      expect(await repo.setting(lastPaymentMethodSettingKey), 'InstaPay');
    });

    test('itemByBarcode gives the item with the price it was last bought at',
        () async {
      final item = await repo.createItem(
          nameAr: 'بيبسي كانز',
          categoryKey: 'Drinks',
          defaultAmountPiastres: 1500,
          barcode: '6224');
      expect((await repo.itemByBarcode('6224'))!.suggestedAmountPiastres, 1500);
      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.barcode,
        date: DateTime(2026, 9, 22),
        lines: [
          CaptureLine(
              amountPiastres: 2000,
              categoryKey: 'Drinks',
              itemId: item.id,
              description: 'بيبسي كانز'),
        ],
      ));
      final found = (await repo.itemByBarcode('6224'))!;
      expect(found.lastAmountPiastres, 2000);
      expect(found.suggestedAmountPiastres, 2000);
    });

    test('itemByBarcode gives the price of one when the last entry was several',
        () async {
      final item = await repo.createItem(
          nameAr: 'تونة', categoryKey: 'Food', barcode: '6230');
      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.barcode,
        date: DateTime(2026, 9, 22),
        lines: [
          CaptureLine(
              amountPiastres: 4000,
              categoryKey: 'Food',
              itemId: item.id,
              description: 'تونة',
              quantityMilli: 2000),
        ],
      ));
      // Two for 40 last time: one can is 20, and scanning one suggests 20.
      expect((await repo.itemByBarcode('6230'))!.suggestedAmountPiastres,
          2000);
      final lines = await barcodeLines(['6230'],
          repository: repo, day: DateTime(2026, 9, 23));
      expect(lines.single.amountPiastres, 2000);
    });

    test('itemByBarcode prefers the unit price the last entry recorded',
        () async {
      final item = await repo.createItem(
          nameAr: 'جبنة', categoryKey: 'Food', barcode: '6231');
      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.barcode,
        date: DateTime(2026, 9, 22),
        lines: [
          CaptureLine(
              amountPiastres: 5000,
              categoryKey: 'Food',
              itemId: item.id,
              description: 'جبنة',
              quantityMilli: 3000,
              unitPricePiastres: 1700),
        ],
      ));
      expect((await repo.itemByBarcode('6231'))!.suggestedAmountPiastres,
          1700);
    });

    test('a scanned line with no item creates the item that learns its code',
        () async {
      final groupId = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.barcode,
        date: DateTime(2026, 9, 22),
        lines: const [
          CaptureLine(
            amountPiastres: 4000,
            categoryKey: 'Food',
            subcategoryKey: 'Groceries',
            description: 'تونة',
            quantityMilli: 2000,
            barcode: '6225',
          ),
        ],
      ));

      final item = (await repo.itemByBarcode('6225'))!;
      expect(item.nameAr, 'تونة');
      expect(item.categoryKey, 'Food');
      expect(item.subcategoryKey, 'Groceries');
      // The price of one: 40 for two is 20.
      expect(item.defaultAmountPiastres, 2000);
      final entry = (await repo.captureGroup(groupId))!.entries.single;
      expect((await repo.entry(entry.id))!.itemId, item.id);
      expect((await repo.entry(entry.id))!.source, EntrySource.barcode);
    });

    test('a scanned line linked to an item without a code teaches it the code',
        () async {
      final item =
          await repo.createItem(nameAr: 'مياه', categoryKey: 'Drinks');
      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.barcode,
        date: DateTime(2026, 9, 22),
        lines: [
          CaptureLine(
              amountPiastres: 800,
              categoryKey: 'Drinks',
              itemId: item.id,
              description: 'مياه',
              barcode: '6226'),
        ],
      ));
      expect((await repo.itemByBarcode('6226'))!.id, item.id);
    });

    test('a scanned code never moves off the item that already holds it',
        () async {
      final holder = await repo.createItem(
          nameAr: 'بيبسي', categoryKey: 'Drinks', barcode: '6227');
      final other = await repo.createItem(
          nameAr: 'سفن', categoryKey: 'Drinks', barcode: '6228');
      final groupId = await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.barcode,
        date: DateTime(2026, 9, 22),
        lines: [
          // Linked in review to an item that has a code of its own.
          CaptureLine(
              amountPiastres: 800,
              categoryKey: 'Drinks',
              itemId: other.id,
              description: 'سفن',
              barcode: '6227'),
          // Unlinked, but the code already has its item: no second item.
          const CaptureLine(
              amountPiastres: 900,
              categoryKey: 'Drinks',
              description: 'بيبسي تاني',
              barcode: '6227'),
        ],
      ));
      expect((await repo.itemByBarcode('6227'))!.id, holder.id);
      expect((await repo.itemByBarcode('6228'))!.id, other.id);
      final entries = (await repo.captureGroup(groupId))!.entries;
      expect((await repo.entry(entries.last.id))!.itemId, holder.id);
      expect(
          (await repo.allItems()).where((i) => i.nameAr == 'بيبسي تاني'),
          isEmpty);
    });

    test('addSalaryPeriod records a dated salary with its import identity',
        () async {
      await repo.addSalaryPeriod(
        datePaid: today(),
        amountPiastres: 710000,
        note: 'InstaPay reference A1',
        evidencePhotoPath: 'attachments/2026-09/s.jpeg',
        externalId: 'pack:manual.json:sal-1',
      );
      expect(await repo.knownExternalIds(), contains('pack:manual.json:sal-1'));
      expect((await repo.watchPeriods().first).first.salaryPiastres, 710000);
    });

    test('addSalaryPeriod refuses an import identity already recorded',
        () async {
      await repo.addSalaryPeriod(
          datePaid: today(), amountPiastres: 710000, externalId: 'sal-1');
      await expectLater(
        repo.addSalaryPeriod(
            datePaid: today(), amountPiastres: 800000, externalId: 'sal-1'),
        throwsStateError,
      );
      expect((await repo.watchPeriods().first).first.salaryPiastres, 710000);
    });

    test('a draft or a note does not touch the last payment method', () async {
      await repo.saveCapture(CaptureDraft(
        kind: CaptureKind.text,
        date: DateTime(2026, 9, 22),
        paymentMethod: 'Card',
        rawText: 'x',
        lines: const [],
        isDraft: true,
      ));
      expect(await repo.setting(lastPaymentMethodSettingKey), isNull);
    });
  });
}
