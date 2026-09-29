import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../domain/dashboard.dart' show arabicMonthName;

/// What the welcome collected: the salary, the day it was paid, and who
/// the user is on InstaPay (empty when left blank).
typedef WelcomeAnswers = ({
  int salaryPiastres,
  DateTime paidOn,
  String instaPayIdentity,
});

/// The shared build's first-run card: the salary and the day it came, so
/// the dashboard has a period to count from, and optionally the user's
/// InstaPay name. Skippable; everything in it is also in الإعدادات.
class WelcomeCard extends StatefulWidget {
  const WelcomeCard({
    super.key,
    required this.today,
    required this.onSave,
    required this.onSkip,
  });

  final DateTime today;
  final Future<void> Function(WelcomeAnswers answers) onSave;
  final VoidCallback onSkip;

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard> {
  final _salary = TextEditingController();
  final _instaPay = TextEditingController();
  late DateTime _paidOn = DateUtils.dateOnly(widget.today);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _salary.dispose();
    _instaPay.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(widget.today);
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidOn,
      firstDate: DateTime(today.year, today.month - 2, today.day),
      lastDate: today,
    );
    if (picked != null) setState(() => _paidOn = picked);
  }

  Future<void> _save() async {
    final amount = parsePiastres(_salary.text.replaceAll(RegExp('[,٬]'), ''));
    if (amount == null || amount == 0) {
      setState(() => _error = 'اكتب المرتب بالجنيه، أو اضغط تخطي');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.onSave((
        salaryPiastres: amount,
        paidOn: _paidOn,
        instaPayIdentity: _instaPay.text.trim(),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onCard = palette.onPrimaryContainer;
    return Card(
      key: const Key('welcome-card'),
      margin: EdgeInsets.zero,
      color: palette.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'أهلاً بيك في مصاريفي',
              style: AppText.title.copyWith(color: onCard),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'قولنا مرتبك قد إيه وجالك إمتى، علشان نحسب اللي فاضل لحد '
              'المرتب الجاي. تقدر تغيّره بعدين من الإعدادات.',
              style: AppText.body.copyWith(color: onCard),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('welcome-salary'),
              controller: _salary,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'المرتب (جنيه)',
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('welcome-date'),
              onPressed: _pickDate,
              icon: const Icon(AppIcons.calendar),
              label: Text(
                'جالك يوم ${_paidOn.day} '
                '${arabicMonthName(_paidOn.month)}',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('welcome-instapay'),
              controller: _instaPay,
              decoration: const InputDecoration(
                labelText: 'اسمك أو حسابك على InstaPay (اختياري)',
                hintText: 'Sara Ahmed، sara@instapay',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const Key('welcome-save'),
                  onPressed: _saving ? null : _save,
                  child: const Text('حفظ'),
                ),
                TextButton(
                  key: const Key('welcome-skip'),
                  onPressed: _saving ? null : widget.onSkip,
                  child: const Text('تخطي'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
