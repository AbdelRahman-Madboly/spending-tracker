import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';

/// The salary period label with ‹ › buttons. The start-side button goes
/// back to the previous (older) period, the end-side one forward; a null
/// callback disables its button at either end of the history.
class PeriodHeader extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PeriodHeader({
    super.key,
    required this.label,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('period-previous'),
          tooltip: 'الفترة اللي فاتت',
          onPressed: onPrevious,
          icon: const Icon(AppIcons.chevronStart),
        ),
        Expanded(
          child: Text(label, textAlign: TextAlign.center, style: AppText.title),
        ),
        IconButton(
          key: const Key('period-next'),
          tooltip: 'الفترة اللي بعدها',
          onPressed: onNext,
          icon: const Icon(AppIcons.chevronEnd),
        ),
      ],
    );
  }
}
