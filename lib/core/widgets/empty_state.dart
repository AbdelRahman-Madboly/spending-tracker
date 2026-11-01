import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// An empty list or section (spec §7.3): a 120dp duotone illustration, one
/// headline, one caption and at most one button.
///
/// The illustration is the section's own glyph in primary strokes on a
/// primaryContainer disc, drawn from tokens so it follows the theme mode.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String caption;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.headline,
    required this.caption,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: palette.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, weight: 300, color: palette.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(headline, style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(color: palette.textSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
