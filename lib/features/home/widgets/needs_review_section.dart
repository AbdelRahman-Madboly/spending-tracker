import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../domain/models.dart';
import 'section_card.dart';

/// Captures kept for later ("بعدين") that still need a review: a count
/// badge and the three newest. The caller hides the section when there are
/// none.
class NeedsReviewSection extends StatelessWidget {
  final List<CaptureGroupView> drafts;
  final ValueChanged<CaptureGroupView> onOpen;

  const NeedsReviewSection({
    super.key,
    required this.drafts,
    required this.onOpen,
  });

  static IconData _iconOf(CaptureKind kind) => switch (kind) {
        CaptureKind.voice => AppIcons.mic,
        CaptureKind.photo => AppIcons.camera,
        CaptureKind.barcode => AppIcons.barcode,
        _ => AppIcons.textNote,
      };

  static String _fallbackTitle(CaptureKind kind) => switch (kind) {
        CaptureKind.voice => 'تسجيل صوتي',
        CaptureKind.photo => 'صورة',
        CaptureKind.barcode => 'باركود',
        _ => 'ملاحظة',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SectionCard(
      key: const Key('needs-review-section'),
      title: 'محتاج مراجعة',
      badge: CountBadge(count: drafts.length),
      child: Column(
        children: [
          for (final draft in drafts.take(3))
            InkWell(
              key: Key('draft-${draft.id}'),
              onTap: () => onOpen(draft),
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Icon(_iconOf(draft.kind), color: palette.warning),
                    const SizedBox(width: AppSpacing.ms),
                    Expanded(
                      child: Text(
                        (draft.cleanText ?? draft.rawText ?? '').trim().isEmpty
                            ? _fallbackTitle(draft.kind)
                            : (draft.cleanText ?? draft.rawText)!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body,
                      ),
                    ),
                    Icon(AppIcons.chevronEnd, color: palette.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
