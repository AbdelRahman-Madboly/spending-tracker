import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';

/// The four ways to capture a spend (spec §4.2), in the order the capture
/// bar shows them from the start side.
enum CaptureAction { voice, camera, barcode, text }

extension CaptureActionLabels on CaptureAction {
  String get labelAr => switch (this) {
        CaptureAction.voice => 'صوت',
        CaptureAction.camera => 'كاميرا',
        CaptureAction.barcode => 'باركود',
        CaptureAction.text => 'نص',
      };

  IconData get icon => switch (this) {
        CaptureAction.voice => AppIcons.mic,
        CaptureAction.camera => AppIcons.camera,
        CaptureAction.barcode => AppIcons.barcode,
        CaptureAction.text => AppIcons.textNote,
      };
}

/// Four 56dp capture buttons, each a 24dp icon over its label. Used on the
/// dashboard and in the FAB's long-press speed dial, so both reach the same
/// flows.
class CaptureBar extends StatelessWidget {
  final ValueChanged<CaptureAction> onAction;

  const CaptureBar({super.key, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.fromBorderSide(palette.cardBorder),
        boxShadow: palette.cardShadow,
      ),
      child: Row(
        children: [
          for (final action in CaptureAction.values)
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: Key('capture-${action.name}'),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () => onAction(action),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: 56, minWidth: 56),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(action.icon, size: 24, color: palette.primary),
                        const SizedBox(height: AppSpacing.xs),
                        Text(action.labelAr,
                            style: AppText.caption
                                .copyWith(color: palette.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
