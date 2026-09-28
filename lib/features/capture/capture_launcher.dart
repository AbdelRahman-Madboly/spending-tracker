import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../data/barcode_scan_service.dart';
import '../../data/photo_capture_service.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/add_sheet.dart';
import '../home/widgets/capture_bar.dart';

/// Opens the add sheet (spec §6.1) as a modal bottom sheet. Saving writes
/// the entry, gives a light haptic and closes the sheet; the dashboard's
/// streams then slide the new row in.
///
/// [initialAction] starts the camera, gallery or scanner as soon as the
/// sheet is up: how the capture bar's camera and barcode buttons reach the
/// photo and barcode capture the sheet already has, until Phase C gives
/// them flows of their own. The services are injectable for widget tests.
Future<void> openAddSheet(
  BuildContext context,
  SpendingRepository repository, {
  AddSheetAction? initialAction,
  PhotoCaptureService? photoCaptureService,
  BarcodeScanService? barcodeScanService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (sheetContext) => AddSheet(
      repository: repository,
      initialAction: initialAction,
      photoCaptureService: photoCaptureService,
      barcodeScanService: barcodeScanService,
      onSubmit: (draft) async {
        await repository.saveEntry(draft);
        HapticFeedback.lightImpact();
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      },
    ),
  );
}

/// Runs one capture bar action. Camera and barcode open the add sheet
/// straight into their capture; voice and text notes have no flow yet
/// (Phase C) and say so instead of doing nothing.
Future<void> launchCapture(
  BuildContext context,
  SpendingRepository repository,
  CaptureAction action, {
  PhotoCaptureService? photoCaptureService,
  BarcodeScanService? barcodeScanService,
}) async {
  switch (action) {
    case CaptureAction.camera:
    case CaptureAction.barcode:
      await openAddSheet(
        context,
        repository,
        initialAction: action == CaptureAction.camera
            ? AddSheetAction.camera
            : AddSheetAction.barcode,
        photoCaptureService: photoCaptureService,
        barcodeScanService: barcodeScanService,
      );
    case CaptureAction.voice:
    case CaptureAction.text:
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          key: Key('capture-soon-${action.name}'),
          content: Text(action == CaptureAction.voice
              ? 'التسجيل بالصوت جاي في التحديث الجاي'
              : 'كتابة المصاريف كنص جاية في التحديث الجاي'),
        ));
  }
}

/// Stands in for the review sheet (Phase C) when a draft is tapped: shows
/// what was captured, so a draft is at least readable before review exists.
Future<void> showDraftPreview(BuildContext context, CaptureGroupView draft) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (context) {
      final palette = context.palette;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(AppIcons.review, color: palette.primary),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('محتاج مراجعة', style: AppText.title),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(draft.cleanText ?? draft.rawText ?? '',
                  style: AppText.body),
              if (draft.attachments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('${draft.attachments.length} مرفق',
                    style: AppText.caption
                        .copyWith(color: palette.textSecondary)),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('شاشة المراجعة جاية في التحديث الجاي',
                  style:
                      AppText.label.copyWith(color: palette.textSecondary)),
            ],
          ),
        ),
      );
    },
  );
}
