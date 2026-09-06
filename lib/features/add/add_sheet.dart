import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';

class AddSheet extends StatefulWidget {
  final SpendingRepository repository;
  final ValueChanged<DraftEntry> onSubmit;

  const AddSheet({super.key, required this.repository, required this.onSubmit});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  DraftEntry? _draft;
  List<QuickPickItem> _items = const [];

  @override
  void initState() {
    super.initState();
    widget.repository.topItems(12).then((items) {
      if (mounted) setState(() => _items = items);
    });
  }

  void _select(QuickPickItem item) {
    setState(() {
      _draft = DraftEntry(
        amountPiastres: item.defaultAmountPiastres,
        itemId: item.id,
        description: item.nameAr,
        categoryKey: item.categoryKey,
        paymentMethod: 'Cash',
        source: EntrySource.quickPick,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draft != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '${draft.description}  ${formatPiastres(draft.amountPiastres ?? 0, withCurrency: true)}',
                style: AppText.title,
              ),
            ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.8,
            children: [
              for (final item in _items)
                InkWell(
                  onTap: () => _select(item),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _draft?.itemId == item.id
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.nameAr, style: AppText.body),
                        if (item.defaultAmountPiastres != null)
                          Text(formatPiastres(item.defaultAmountPiastres!),
                              style: AppText.caption),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            key: const Key('capture-icons'),
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Icon(Icons.photo_camera_outlined, color: AppColors.textSecondary),
              Icon(Icons.qr_code_scanner, color: AppColors.textSecondary),
              Icon(Icons.mic_none, color: AppColors.textSecondary),
              Icon(Icons.image_outlined, color: AppColors.textSecondary),
              Icon(Icons.keyboard_alt_outlined, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('save-button'),
              onPressed: draft != null && draft.isComplete
                  ? () => widget.onSubmit(draft)
                  : null,
              child: const Text('حفظ'),
            ),
          ),
        ],
      ),
    );
  }
}
