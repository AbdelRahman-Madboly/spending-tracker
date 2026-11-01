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
///
/// A long press on باركود reports [onLongPress]; the dashboard answers a
/// tap or a long press on it with [showBarcodeMenu]. The other buttons
/// have no long press.
class CaptureBar extends StatelessWidget {
  final ValueChanged<CaptureAction> onAction;
  final ValueChanged<CaptureAction>? onLongPress;

  const CaptureBar({super.key, required this.onAction, this.onLongPress});

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
                child: Semantics(
                  onLongPressHint:
                      action == CaptureAction.barcode && onLongPress != null
                      ? 'امسح واعرف السعر أو المنتجات'
                      : null,
                  child: InkWell(
                    key: Key('capture-${action.name}'),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: () => onAction(action),
                    onLongPress:
                        action == CaptureAction.barcode && onLongPress != null
                        ? () => onLongPress!(action)
                        : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 56,
                        minWidth: 56,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(action.icon, size: 24, color: palette.primary),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            action.labelAr,
                            style: AppText.caption.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
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

/// What the باركود long press offers.
enum BarcodeMenuChoice { record, check, products }

/// The باركود menu: «سجل مصروف» (the barcode purchase scan),
/// «امسح واعرف السعر» (scan a product to see what it is and costs before
/// deciding anything) and «المنتجات». Null when dismissed.
Future<BarcodeMenuChoice?> showBarcodeMenu(BuildContext context) =>
    showModalBottomSheet<BarcodeMenuChoice>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (sheetContext) {
        Widget option(
          BarcodeMenuChoice choice,
          String key,
          IconData icon,
          String title,
          String subtitle,
        ) => ListTile(
          key: Key(key),
          minTileHeight: 56,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: () => Navigator.of(sheetContext).pop(choice),
        );
        return SafeArea(
          child: Column(
            key: const Key('barcode-menu'),
            mainAxisSize: MainAxisSize.min,
            children: [
              option(
                BarcodeMenuChoice.record,
                'barcode-menu-record',
                AppIcons.barcode,
                'سجل مصروف',
                'امسح المنتجات اللي اشتريتها وراجعها',
              ),
              option(
                BarcodeMenuChoice.check,
                'barcode-menu-check',
                AppIcons.search,
                'امسح واعرف السعر',
                'اعرف المنتج وسعره، وبعدين قرر تسجله ولا لأ',
              ),
              option(
                BarcodeMenuChoice.products,
                'barcode-menu-products',
                AppIcons.importBundled,
                'المنتجات',
                'منتجاتك ودليل المنتجات',
              ),
            ],
          ),
        );
      },
    );
