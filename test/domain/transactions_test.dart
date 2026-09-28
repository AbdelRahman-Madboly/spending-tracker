import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/domain/transactions.dart';

TransactionView _t(
  String id, {
  DateTime? date,
  DateTime? createdAt,
  int amount = 1000,
  String category = 'Food',
  String description = '',
  String? itemName,
  String? note,
  String payment = 'Cash',
  String? group,
  Set<AttachmentKind> kinds = const {},
  List<String> attachmentText = const [],
}) {
  final day = date ?? DateTime(2026, 9, 20);
  return TransactionView(
    id: id,
    date: day,
    createdAt: createdAt ?? day.add(const Duration(hours: 12)),
    amountPiastres: amount,
    categoryKey: category,
    categoryLabelAr: category,
    description: description,
    itemNameAr: itemName,
    note: note,
    paymentMethod: payment,
    source: EntrySource.manual,
    captureGroupId: group,
    attachmentKinds: kinds,
    attachmentText: attachmentText,
  );
}

void main() {
  group('TransactionView.name', () {
    test('is the description, else the item name, else the category', () {
      expect(_t('a', description: 'طماطم', itemName: 'خضار').name, 'طماطم');
      expect(_t('a', itemName: 'خضار').name, 'خضار');
      expect(_t('a', category: 'أكل').name, 'أكل');
    });
  });

  group('TransactionFilter', () {
    test('the empty filter matches everything and says it is empty', () {
      const filter = TransactionFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.matches(_t('a')), isTrue);
    });

    test('searches item name, description, note and attachment text', () {
      bool finds(String query, TransactionView t) =>
          TransactionFilter(query: query).matches(t);
      expect(finds('إندومى', _t('a', itemName: 'اندومي')), isTrue);
      expect(finds('طماطم', _t('a', description: 'طماطم')), isTrue);
      expect(finds('عزومة', _t('a', note: 'عزومه أحمد')), isTrue);
      expect(finds('كيلو', _t('a', attachmentText: ['اتنين كيلو'])), isTrue);
      expect(finds('قهوة', _t('a', description: 'شاي')), isFalse);
    });

    test('a date range keeps its first and last day', () {
      final filter = TransactionFilter(
          from: DateTime(2026, 9, 10), to: DateTime(2026, 9, 12));
      expect(filter.matches(_t('a', date: DateTime(2026, 9, 10))), isTrue);
      expect(filter.matches(_t('a', date: DateTime(2026, 9, 12))), isTrue);
      expect(filter.matches(_t('a', date: DateTime(2026, 9, 9))), isFalse);
      expect(filter.matches(_t('a', date: DateTime(2026, 9, 13))), isFalse);
    });

    test('categories and payment methods match any of the chosen', () {
      const filter = TransactionFilter(
        categoryKeys: {'Food', 'Drinks'},
        paymentMethods: {'InstaPay'},
      );
      expect(filter.matches(_t('a', payment: 'InstaPay')), isTrue);
      expect(filter.matches(_t('a', category: 'Drinks', payment: 'InstaPay')),
          isTrue);
      expect(filter.matches(_t('a', category: 'Bills', payment: 'InstaPay')),
          isFalse);
      expect(filter.matches(_t('a')), isFalse);
    });

    test('has-attachment matches an entry with any of the chosen kinds', () {
      const filter =
          TransactionFilter(attachmentKinds: {AttachmentKind.voice});
      expect(filter.matches(_t('a', kinds: {AttachmentKind.voice})), isTrue);
      expect(filter.matches(_t('a', kinds: {AttachmentKind.photo})), isFalse);
      expect(filter.matches(_t('a')), isFalse);
    });

    test('isSingleDay is true only for a one-day range', () {
      expect(TransactionFilter.day(DateTime(2026, 9, 5, 18)).isSingleDay,
          isTrue);
      expect(TransactionFilter.day(DateTime(2026, 9, 5, 18)).from,
          DateTime(2026, 9, 5));
      expect(
          TransactionFilter(from: DateTime(2026, 9, 5), to: DateTime(2026, 9, 6))
              .isSingleDay,
          isFalse);
    });
  });

  group('groupTransactions', () {
    test('groups by day, newest day first, each with its total', () {
      final days = groupTransactions([
        _t('a', date: DateTime(2026, 9, 19), amount: 500),
        _t('b', date: DateTime(2026, 9, 20), amount: 1000),
        _t('c', date: DateTime(2026, 9, 20), amount: 250),
      ]);
      expect(days.map((d) => d.day),
          [DateTime(2026, 9, 20), DateTime(2026, 9, 19)]);
      expect(days.first.totalPiastres, 1250);
      expect(days.last.totalPiastres, 500);
    });

    test('rows within a day run newest first', () {
      final day = DateTime(2026, 9, 20);
      final rows = groupTransactions([
        _t('early', createdAt: day.add(const Duration(hours: 8))),
        _t('late', createdAt: day.add(const Duration(hours: 20))),
      ]).single.rows;
      expect(rows.map((r) => (r as SingleTransactionRow).entry.id),
          ['late', 'early']);
    });

    test('lines sharing a capture group make one parent row', () {
      final day = DateTime(2026, 9, 20);
      final at = day.add(const Duration(hours: 10));
      final rows = groupTransactions([
        _t('solo', createdAt: day.add(const Duration(hours: 9))),
        _t('g1', description: 'طماطم', amount: 3000, group: 'G',
            createdAt: at),
        _t('g2', description: 'عيش', amount: 1000, group: 'G', createdAt: at),
        _t('g3', description: 'جبنة', amount: 500, group: 'G', createdAt: at),
      ]).single.rows;
      expect(rows, hasLength(2));
      final parent = rows.first as CaptureGroupRow;
      expect(parent.captureGroupId, 'G');
      expect(parent.totalPiastres, 4500);
      // Captured order is kept inside the group.
      expect(parent.lines.map((l) => l.id), ['g1', 'g2', 'g3']);
      expect(parent.title, 'طماطم و 2 أخرى');
      expect((rows.last as SingleTransactionRow).entry.id, 'solo');
    });

    test('a group with one visible line is a plain row', () {
      final rows = groupTransactions([_t('g1', group: 'G')]).single.rows;
      expect(rows.single, isA<SingleTransactionRow>());
    });
  });

  group('captureGroupTitle', () {
    test('names the first line and counts the rest', () {
      expect(captureGroupTitle(['طماطم', 'عيش']), 'طماطم و 1 أخرى');
      expect(captureGroupTitle(['طماطم']), 'طماطم');
    });
  });
}
