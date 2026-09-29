import 'dart:convert';

import '../core/arabic_text.dart';
import 'models.dart';
import 'transactions.dart';

/// The hour of the day a bill reminder shows.
const billReminderHour = 10;

/// The `app_settings` key holding the suggestion keys the user dismissed.
const dismissedBillSuggestionsSettingKey = 'bills_dismissed_suggestions';

/// The `app_settings` key set once the notification permission was asked
/// for (whatever the answer), so the explanation card shows only once.
const billRemindersPermissionAskedSettingKey = 'bills_notifications_asked';

/// The built-in suggestion for the home internet plan: 300 EGP,
/// renewing on the 27th.
const homeInternetSuggestionKey = 'seed:plan-home-internet';

/// When [bill] falls due after the current [RecurringBillView.nextDue] is
/// paid.
DateTime dueAfterPayment(RecurringBillView bill) =>
    addMonthsClamped(bill.nextDue, bill.everyMonths);

/// When to remind about [bill]: [RecurringBillView.remindDaysBefore] days
/// before it is due, at [billReminderHour]. Null when that moment is not
/// after [now], since a reminder in the past would never show.
DateTime? reminderTime(RecurringBillView bill, DateTime now) {
  final due = bill.nextDue;
  final at = DateTime(
      due.year, due.month, due.day - bill.remindDaysBefore, billReminderHour);
  return at.isAfter(now) ? at : null;
}

/// The first date on day [day] of a month (the month's last day when it is
/// shorter) that is not before [today]'s day.
DateTime nextDueOnDay(int day, DateTime today) {
  DateTime onDay(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > last ? last : day);
  }

  final start = DateTime(today.year, today.month, today.day);
  final due = onDay(today.year, today.month);
  return due.isBefore(start) ? onDay(today.year, today.month + 1) : due;
}

/// A bill the history suggests, not saved yet.
class BillSuggestion {
  /// Stable identity, so a dismissed suggestion stays dismissed.
  final String key;
  final String nameAr;
  final int amountPiastres;
  final String categoryKey;
  final String? subcategoryKey;
  final DateTime nextDue;

  const BillSuggestion({
    required this.key,
    required this.nameAr,
    required this.amountPiastres,
    required this.categoryKey,
    required this.nextDue,
    this.subcategoryKey,
  });
}

/// Bills worth offering: the same item (or description) at the same amount
/// in two or more consecutive calendar months of [history], each due
/// monthly from its latest payment, plus the home internet plan seed.
///
/// Skips anything whose name matches an existing bill, anything in
/// [dismissed], and the seed once a home internet bill exists or history
/// already found one.
List<BillSuggestion> suggestBills({
  required List<TransactionView> history,
  required List<RecurringBillView> bills,
  required DateTime today,
  Set<String> dismissed = const {},
  bool includeSeeds = true,
}) {
  final billNames = {for (final b in bills) normalizeArabic(b.nameAr)};
  final groups = <String, List<TransactionView>>{};
  final names = <String, String>{};
  for (final t in history) {
    final name = (t.itemNameAr ?? t.description).trim();
    final normalized = normalizeArabic(name);
    if (normalized.isEmpty) continue;
    final key = '$normalized|${t.amountPiastres}';
    groups.putIfAbsent(key, () => []).add(t);
    names.putIfAbsent(key, () => name);
  }

  final suggestions = <BillSuggestion>[];
  groups.forEach((key, rows) {
    if (dismissed.contains(key)) return;
    if (billNames.contains(key.substring(0, key.lastIndexOf('|')))) return;
    final months = {for (final r in rows) r.date.year * 12 + r.date.month - 1};
    if (!months.any((m) => months.contains(m + 1))) return;
    final latest =
        rows.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
    suggestions.add(BillSuggestion(
      key: key,
      nameAr: names[key]!,
      amountPiastres: latest.amountPiastres,
      categoryKey: latest.categoryKey,
      subcategoryKey: latest.subcategoryKey,
      nextDue: nextMonthlyDue(latest.date, today),
    ));
  });
  suggestions.sort((a, b) => a.nextDue.compareTo(b.nextDue));

  final hasInternet = bills.any((b) => b.subcategoryKey == 'HomeInternet') ||
      suggestions.any((s) => s.subcategoryKey == 'HomeInternet');
  if (includeSeeds &&
      !hasInternet &&
      !dismissed.contains(homeInternetSuggestionKey)) {
    final due = nextDueOnDay(27, today);
    suggestions.add(BillSuggestion(
      key: homeInternetSuggestionKey,
      nameAr: 'باقة إنترنت المنزل',
      amountPiastres: 30000,
      categoryKey: 'Bills',
      subcategoryKey: 'HomeInternet',
      nextDue: due,
    ));
  }
  return suggestions;
}

String encodeDismissedSuggestions(Set<String> keys) =>
    jsonEncode(keys.toList()..sort());

/// The dismissed suggestion keys stored under
/// [dismissedBillSuggestionsSettingKey]; a missing or unreadable value
/// reads as none.
Set<String> decodeDismissedSuggestions(String? value) {
  if (value == null) return {};
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) return {for (final k in decoded) if (k is String) k};
  } on FormatException {
    // Falls through to none.
  }
  return {};
}
