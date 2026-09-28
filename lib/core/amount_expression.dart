import 'money.dart';

/// The operators the add sheet's keypad types, in the glyphs it shows.
const keypadOperators = ['+', '−', '×', '÷'];

/// Evaluates what the add sheet's calculator keypad holds, such as
/// `2×35+10`, into integer piastres (spec §6.1). Returns null when the text
/// is empty, malformed, divides by zero, goes negative or passes
/// [maxParsablePiastres].
///
/// Every operand is parsed with [parsePiastres], so Eastern Arabic digits and
/// the Arabic decimal comma work, and the arithmetic stays in integers: a
/// value is always piastres (hundredths), so `a × b` is `a·b / 100` and
/// `a ÷ b` is `a·100 / b`, each rounded half up once. That keeps `2×35` at
/// exactly 70.00 instead of passing through a double.
///
/// A trailing operator is dropped, so the live total keeps showing `35`
/// while the user is halfway through typing `35+10`.
int? evaluateAmountExpression(String input) {
  var text = input
      .replaceAll(' ', '')
      .replaceAll('٫', '.')
      .replaceAll('*', '×')
      .replaceAll('/', '÷')
      .replaceAll('-', '−');
  if (text.isEmpty) return null;
  if (keypadOperators.contains(text[text.length - 1])) {
    text = text.substring(0, text.length - 1);
  }
  if (text.isEmpty) return null;

  // Split into alternating operand/operator tokens.
  final operands = <int>[];
  final operators = <String>[];
  final current = StringBuffer();
  for (final char in text.split('')) {
    if (keypadOperators.contains(char)) {
      final value = parsePiastres(current.toString());
      if (value == null) return null;
      operands.add(value);
      operators.add(char);
      current.clear();
    } else {
      current.write(char);
    }
  }
  final last = parsePiastres(current.toString());
  if (last == null) return null;
  operands.add(last);

  // First pass: × and ÷, left to right. Second pass: + and −.
  final terms = <int>[operands.first];
  final additive = <String>[];
  for (var i = 0; i < operators.length; i++) {
    final op = operators[i];
    final right = operands[i + 1];
    switch (op) {
      case '×':
        terms.last = (terms.last * right + 50) ~/ 100;
      case '÷':
        if (right == 0) return null;
        terms.last = (terms.last * 200 + right) ~/ (right * 2);
      default:
        terms.add(right);
        additive.add(op);
    }
    if (terms.last > maxParsablePiastres) return null;
  }

  var total = terms.first;
  for (var i = 0; i < additive.length; i++) {
    total = additive[i] == '+' ? total + terms[i + 1] : total - terms[i + 1];
  }
  if (total < 0 || total > maxParsablePiastres) return null;
  return total;
}
