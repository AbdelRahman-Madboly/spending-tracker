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
          // Cap tile WIDTH rather than fixing a column count. Tile height derives
          // from tile width, so a fixed count makes tiles balloon on a wide surface
          // and collapse below the 48dp touch target if the ratio is tuned to
          // compensate. Capping width holds tiles near 69dp tall on a phone (3
          // columns) and simply reflows to more columns on anything wider.
          GridView.extent(
            maxCrossAxisExtent: 130,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.5,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Always one line. Item names become user-supplied, and a
                          // long one must truncate rather than wrap and overflow
                          // the tile.
                          Text(
                            item.nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body,
                          ),
                          if (item.defaultAmountPiastres != null)
                            Text(formatPiastres(item.defaultAmountPiastres!),
                                style: AppText.caption),
                        ],
                      ),
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
