import 'package:equatable/equatable.dart';

import 'dashboard.dart' show arabicMonthName;
import 'models.dart';
import 'search.dart';

/// What السجل is narrowed to (spec §4.3): a search, a date range, and the
/// category, payment-method and has-attachment chips. An empty set means
/// "any". Pure Dart, so every rule here is unit tested without widgets.
class TransactionFilter extends Equatable {
  final String query;

  /// First and last day shown, both inclusive, as local midnights. Null on
  /// either side leaves that side open.
  final DateTime? from;
  final DateTime? to;
  final Set<String> categoryKeys;
  final Set<String> paymentMethods;

  /// An entry matches when it has at least one attachment of these kinds.
  final Set<AttachmentKind> attachmentKinds;

  const TransactionFilter({
    this.query = '',
    this.from,
    this.to,
    this.categoryKeys = const {},
    this.paymentMethods = const {},
    this.attachmentKinds = const {},
  });

  /// Just [day]: what the dashboard's "عرض الكل" opens.
  factory TransactionFilter.day(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return TransactionFilter(from: d, to: d);
  }

  bool get isEmpty =>
      query.trim().isEmpty &&
      from == null &&
      to == null &&
      categoryKeys.isEmpty &&
      paymentMethods.isEmpty &&
      attachmentKinds.isEmpty;

  bool get isSingleDay => from != null && from == to;

  bool matches(TransactionView t) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    final start = from;
    final end = to;
    if (start != null && day.isBefore(start)) return false;
    if (end != null && day.isAfter(end)) return false;
    if (categoryKeys.isNotEmpty && !categoryKeys.contains(t.categoryKey)) {
      return false;
    }
    if (paymentMethods.isNotEmpty &&
        !paymentMethods.contains(t.paymentMethod)) {
      return false;
    }
    if (attachmentKinds.isNotEmpty &&
        !attachmentKinds.any(t.attachmentKinds.contains)) {
      return false;
    }
    return matchesSearch(query, [
      t.itemNameAr,
      t.description,
      t.note,
      ...t.attachmentText,
    ]);
  }

  /// A copy with the given parts replaced. The range is replaced as a
  /// pair through [withRange], since null there means "open", not "keep".
  TransactionFilter copyWith({
    String? query,
    Set<String>? categoryKeys,
    Set<String>? paymentMethods,
    Set<AttachmentKind>? attachmentKinds,
  }) => TransactionFilter(
    query: query ?? this.query,
    from: from,
    to: to,
    categoryKeys: categoryKeys ?? this.categoryKeys,
    paymentMethods: paymentMethods ?? this.paymentMethods,
    attachmentKinds: attachmentKinds ?? this.attachmentKinds,
  );

  TransactionFilter withRange(DateTime? from, DateTime? to) =>
      TransactionFilter(
        query: query,
        from: from == null ? null : DateTime(from.year, from.month, from.day),
        to: to == null ? null : DateTime(to.year, to.month, to.day),
        categoryKeys: categoryKeys,
        paymentMethods: paymentMethods,
        attachmentKinds: attachmentKinds,
      );

  @override
  List<Object?> get props => [
    query,
    from,
    to,
    categoryKeys,
    paymentMethods,
    attachmentKinds,
  ];
}

const _arabicWeekdays = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// The Arabic name of a [DateTime.weekday] (1 is Monday).
String arabicWeekdayName(int weekday) => _arabicWeekdays[weekday - 1];

/// `الأحد 6 سبتمبر 2026`: the entry detail's date field.
String formatFullDate(DateTime d) =>
    '${arabicWeekdayName(d.weekday)} ${d.day} ${arabicMonthName(d.month)} ${d.year}';

/// [date] moved [months] on, on the same day of the month, or the month's
/// last day when it is shorter (31 January + 1 is 28 February): when a bill
/// made from an entry falls due next.
DateTime addMonthsClamped(DateTime date, int months) {
  final firstOfTarget = DateTime(date.year, date.month + months);
  final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
  return DateTime(
    firstOfTarget.year,
    firstOfTarget.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

/// A row's time: 12-hour with ص or م, Latin digits, e.g. `9:05 م`.
String formatClock(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'ص' : 'م'}';
}

/// One row of السجل: a single entry, or a capture group's parent row.
sealed class TransactionRow {
  const TransactionRow();

  /// When the row's newest line was written, for ordering rows in a day.
  DateTime get newest;
}

class SingleTransactionRow extends TransactionRow {
  final TransactionView entry;

  const SingleTransactionRow(this.entry);

  @override
  DateTime get newest => entry.createdAt;
}

/// Entries sharing a `captureGroupId` (spec §4.3): shown as one parent row
/// with the summed amount, its lines indented below when expanded.
class CaptureGroupRow extends TransactionRow {
  final String captureGroupId;

  /// In captured order.
  final List<TransactionView> lines;

  const CaptureGroupRow(this.captureGroupId, this.lines);

  int get totalPiastres => lines.fold(0, (sum, l) => sum + l.amountPiastres);

  String get title => captureGroupTitle([for (final l in lines) l.name]);

  @override
  DateTime get newest =>
      lines.map((l) => l.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

/// The first line's name, plus "و N أخرى" for the rest.
String captureGroupTitle(List<String> names) {
  if (names.length <= 1) return names.isEmpty ? '' : names.first;
  return '${names.first} و ${names.length - 1} أخرى';
}

/// One day of السجل with its total.
class TransactionDay {
  final DateTime day;
  final List<TransactionRow> rows;

  const TransactionDay(this.day, this.rows);

  int get totalPiastres => rows.fold(
    0,
    (sum, r) =>
        sum +
        switch (r) {
          SingleTransactionRow(:final entry) => entry.amountPiastres,
          CaptureGroupRow() => r.totalPiastres,
        },
  );
}

/// Groups [entries] by day, newest day first. Inside a day, rows run newest
/// first and entries sharing a capture group fold into one
/// [CaptureGroupRow] with its lines in captured order. A group with only
/// one line left (after filtering or deleting) is a plain row.
///
/// Ties on `createdAt` keep the input order: every line of one capture is
/// stamped with the same time, and the repository lists them in the order
/// they were captured.
List<TransactionDay> groupTransactions(Iterable<TransactionView> entries) {
  final byDay = <DateTime, List<(int, TransactionView)>>{};
  var index = 0;
  for (final e in entries) {
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    (byDay[day] ??= []).add((index++, e));
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final day in days) TransactionDay(day, _rowsOf(byDay[day]!))];
}

List<TransactionRow> _rowsOf(List<(int, TransactionView)> indexed) {
  final ordered = [...indexed]
    ..sort((a, b) {
      final byTime = a.$2.createdAt.compareTo(b.$2.createdAt);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  final groups = <String, List<TransactionView>>{};
  final rows = <(int, TransactionRow)>[];
  for (final (i, e) in ordered) {
    final group = e.captureGroupId;
    if (group == null) {
      rows.add((i, SingleTransactionRow(e)));
    } else {
      (groups[group] ??= []).add(e);
    }
  }
  for (final MapEntry(key: id, value: lines) in groups.entries) {
    final order = indexed.firstWhere((p) => p.$2.id == lines.first.id).$1;
    rows.add((
      order,
      lines.length == 1
          ? SingleTransactionRow(lines.single)
          : CaptureGroupRow(id, lines),
    ));
  }
  rows.sort((a, b) {
    final byTime = b.$2.newest.compareTo(a.$2.newest);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [for (final (_, r) in rows) r];
}
