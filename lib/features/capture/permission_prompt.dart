import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';

/// The runtime permissions a capture asks for (spec §8).
enum AppPermission { camera, microphone }

/// What the system says about a permission, reduced to what the card
/// needs: go on, ask, or send the user to the app's settings.
enum AppPermissionStatus { granted, denied, permanentlyDenied }

/// The permission seam: permission_handler talks to a platform channel
/// that does not run under `flutter test`, so tests inject a fake.
abstract class PermissionService {
  Future<AppPermissionStatus> status(AppPermission permission);

  /// Shows the system dialog.
  Future<AppPermissionStatus> request(AppPermission permission);

  /// Opens this app's page in the system settings.
  Future<bool> openSettings();
}

class HandlerPermissionService implements PermissionService {
  const HandlerPermissionService();

  Permission _of(AppPermission p) => switch (p) {
        AppPermission.camera => Permission.camera,
        AppPermission.microphone => Permission.microphone,
      };

  AppPermissionStatus _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return AppPermissionStatus.granted;
    if (s.isPermanentlyDenied || s.isRestricted) {
      return AppPermissionStatus.permanentlyDenied;
    }
    return AppPermissionStatus.denied;
  }

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async =>
      _map(await _of(permission).status);

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async =>
      _map(await _of(permission).request());

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// Makes sure [permission] is granted before a capture opens the camera or
/// the microphone (spec §8). When it is not, an Arabic card explains why
/// the app needs it before the system dialog shows; متابعة then asks the
/// system. When it is denied (or was denied for good before), the card
/// says so and links to the app's settings. True means go on.
///
/// When the status cannot be read at all the capture goes on and the
/// feature asks for itself, as it did before this card existed.
Future<bool> ensurePermission(
  BuildContext context,
  AppPermission permission, {
  PermissionService? service,
}) async {
  final permissions = service ?? const HandlerPermissionService();
  AppPermissionStatus status;
  try {
    status = await permissions.status(permission);
  } catch (_) {
    return true;
  }
  if (status == AppPermissionStatus.granted) return true;
  if (!context.mounted) return false;

  if (status == AppPermissionStatus.denied) {
    final go = await _showCard(context, permission, denied: false);
    if (go != true || !context.mounted) return false;
    try {
      status = await permissions.request(permission);
    } catch (_) {
      return true;
    }
    if (status == AppPermissionStatus.granted) return true;
    if (!context.mounted) return false;
  }

  final open = await _showCard(context, permission, denied: true);
  if (open == true) {
    try {
      await permissions.openSettings();
    } catch (_) {
      // Nothing more to offer: the card already said what to allow.
    }
  }
  return false;
}

Future<bool?> _showCard(
  BuildContext context,
  AppPermission permission, {
  required bool denied,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (sheetContext) =>
        _PermissionCard(permission: permission, denied: denied),
  );
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.permission, required this.denied});

  final AppPermission permission;
  final bool denied;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, title, why) = switch (permission) {
      AppPermission.camera => (
          AppIcons.camera,
          'إذن الكاميرا',
          'الكاميرا بتصور الفاتورة أو الإيصال أو تقرا الباركود. الصور بتفضل '
              'على الموبايل.',
        ),
      AppPermission.microphone => (
          AppIcons.mic,
          'إذن الميكروفون',
          'الميكروفون بيسجل الملاحظة الصوتية عشان تتحول لمصاريف. التسجيل '
              'بيفضل على الموبايل.',
        ),
    };
    final body = denied
        ? 'الإذن مرفوض. افتح إعدادات التطبيق واسمح بيه من «الأذونات».'
        : why;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('permission-card'),
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 40, color: palette.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(title, textAlign: TextAlign.center, style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            Text(body,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: palette.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: Key(denied ? 'permission-open-settings' : 'permission-continue'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(denied ? 'افتح الإعدادات' : 'متابعة'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('permission-later'),
              style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('مش دلوقتي'),
            ),
          ],
        ),
      ),
    );
  }
}
