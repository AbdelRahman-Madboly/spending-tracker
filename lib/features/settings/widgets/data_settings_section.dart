import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../data/backup/backup_service.dart';
import '../../../data/backup/data_transfer.dart';
import '../../../data/export/spending_export.dart';
import '../../../domain/dashboard.dart' show arabicMonthName;

/// Settings -> البيانات: xlsx export, full backup and restore.
class DataSettingsSection extends StatefulWidget {
  const DataSettingsSection({super.key, required this.transfer});

  final DataTransfer transfer;

  @override
  State<DataSettingsSection> createState() => _DataSettingsSectionState();
}

class _DataSettingsSectionState extends State<DataSettingsSection> {
  bool _busy = false;

  /// Shows the progress bar while [work] runs; kept apart from [_busy] so
  /// the bar never animates behind an open dialog.
  bool _working = false;

  Future<T> _work<T>(Future<T> work) async {
    setState(() => _working = true);
    try {
      return await work;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  DataTransfer get _transfer => widget.transfer;

  /// Runs [action] with the tiles disabled, and turns any failure into a
  /// message rather than a crash: the data is never half-changed by one
  /// (see [DataTransfer.restore]).
  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    // Captured now: a restore rebuilds the whole screen under this one.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? message;
    try {
      message = await action();
    } on BackupFormatException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'حصلت مشكلة، ومفيش حاجة اتغيرت';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _export() => _run(() async {
    final periods = await _work(_transfer.exportPeriods());
    if (!mounted) return null;
    final scope = await showDialog<ExportScope>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('export-scope'),
        title: const Text('تصدير Excel', style: AppText.title),
        children: [
          _scopeOption(context, 'كل حاجة', const ExportScope.all()),
          for (final year in periods.years)
            _scopeOption(context, 'سنة $year', ExportScope.year(year)),
          for (final m in periods.months)
            _scopeOption(
              context,
              '${arabicMonthName(m.month)} ${m.year}',
              ExportScope.month(m.year, m.month),
            ),
        ],
      ),
    );
    if (scope == null) return null;
    final saved = await _work(_transfer.exportWorkbook(scope));
    return saved ? 'اتحفظ الملف' : null;
  });

  Widget _scopeOption(BuildContext context, String label, ExportScope scope) =>
      SimpleDialogOption(
        onPressed: () => Navigator.pop(context, scope),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(label, style: AppText.body),
          ),
        ),
      );

  Future<void> _backup() => _run(() async {
    final saved = await _work(_transfer.backupNow());
    return saved ? 'اتحفظت النسخة الاحتياطية' : null;
  });

  Future<void> _restore() => _run(() async {
    final staged = await _work(_transfer.pickAndStage());
    if (staged == null || !mounted) return null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('restore-confirm'),
        title: const Text('استرجاع من نسخة', style: AppText.title),
        content: const Text(
          'كل البيانات والمرفقات الحالية هتتبدل بالنسخة دي. '
          'قبلها هنعمل نسخة احتياطية تلقائية من بياناتك الحالية '
          'في فولدر backups.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('restore-confirm-yes'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استرجع'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      await _transfer.discard();
      return null;
    }
    await _work(_transfer.restore(staged));
    return 'رجعت البيانات من النسخة. بياناتك القديمة محفوظة في backups';
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('settings-data-export'),
          leading: const Icon(AppIcons.exportSheet),
          title: const Text('تصدير Excel', style: AppText.body),
          subtitle: const Text(
            'شهر أو سنة أو كل حاجة، بنفس أعمدة الشيت القديم',
            style: AppText.caption,
          ),
          enabled: enabled,
          onTap: _export,
        ),
        ListTile(
          key: const Key('settings-data-backup'),
          leading: const Icon(AppIcons.backup),
          title: const Text('نسخة احتياطية كاملة', style: AppText.body),
          subtitle: const Text(
            'البيانات والمرفقات في ملف zip، من غير مفتاح Gemini',
            style: AppText.caption,
          ),
          enabled: enabled,
          onTap: _backup,
        ),
        ListTile(
          key: const Key('settings-data-restore'),
          leading: const Icon(AppIcons.restore),
          title: const Text('استرجاع من نسخة', style: AppText.body),
          subtitle: const Text(
            'بيستبدل البيانات الحالية بعد ما يسألك',
            style: AppText.caption,
          ),
          enabled: enabled,
          onTap: _restore,
        ),
        if (_working)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
