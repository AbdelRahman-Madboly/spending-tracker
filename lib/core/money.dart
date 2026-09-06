import 'package:intl/intl.dart';

/// Formats an integer piastre amount for display.
///
/// Latin digits are used deliberately: every payment receipt this app ingests
/// renders amounts in Latin digits, and matching them avoids transcription errors.
String formatPiastres(int piastres, {bool withCurrency = false}) {
  final negative = piastres < 0;
  final abs = piastres.abs();
  final pounds = abs ~/ 100;
  final fraction = abs % 100;

  final poundsText = NumberFormat('#,##0', 'en_US').format(pounds);
  final body = fraction == 0
      ? poundsText
      : '$poundsText.${fraction.toString().padLeft(2, '0')}';

  final signed = negative ? '-$body' : body;
  return withCurrency ? '$signed ج.م' : signed;
}
