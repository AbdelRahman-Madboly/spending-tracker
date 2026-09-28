import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/amount_expression.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';

/// The key [AmountKeypad] reports for its backspace key.
const keypadBackspace = 'backspace';

/// The add sheet's calculator keypad (spec §6.1): digits, a decimal point,
/// backspace and the four operators in [keypadOperators].
///
/// Laid out left to right even in the RTL sheet, the way every phone
/// dialler and calculator in Egypt is, so a thumb finds 1-2-3 where it
/// expects them. Each key is at least 52dp tall and a quarter of the width,
/// comfortably past the 48dp target.
class AmountKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;

  const AmountKeypad({super.key, required this.onKey});

  static const _rows = [
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '−'],
    ['.', '0', keypadBackspace, '+'],
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        key: const Key('keypad'),
        children: [
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs / 2,
                        ),
                        child: _Key(value: key, onKey: onKey),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String value;
  final ValueChanged<String> onKey;

  const _Key({required this.value, required this.onKey});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isOperator = keypadOperators.contains(value);
    final isBackspace = value == keypadBackspace;
    final foreground = isOperator
        ? palette.onPrimaryContainer
        : palette.textPrimary;
    return Material(
      color: isOperator ? palette.primaryContainer : palette.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        key: Key('key-$value'),
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onKey(value);
        },
        child: SizedBox(
          height: 52,
          child: Center(
            child: isBackspace
                ? Semantics(
                    label: 'مسح',
                    child: Icon(AppIcons.backspace, color: foreground),
                  )
                : Text(value, style: AppText.title.copyWith(color: foreground)),
          ),
        ),
      ),
    );
  }
}
