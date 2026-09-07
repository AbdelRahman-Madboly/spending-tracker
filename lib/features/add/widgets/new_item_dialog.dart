import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../domain/models.dart';

/// The user's input for a brand-new item: the sheet turns this into a
/// `createItem` call and then selects the result immediately, so the "add
/// a new thing" path still ends in a usable draft.
class NewItemDraft {
  final String nameAr;
  final String categoryKey;
  final int amountPiastres;

  const NewItemDraft({
    required this.nameAr,
    required this.categoryKey,
    required this.amountPiastres,
  });
}

/// Shows the new-item dialog and returns the entered draft, or null if the
/// user cancelled.
Future<NewItemDraft?> showNewItemDialog({
  required BuildContext context,
  required List<CategoryView> categories,
  required String initialCategoryKey,
}) {
  return showDialog<NewItemDraft>(
    context: context,
    builder: (_) => NewItemDialog(
      categories: categories,
      initialCategoryKey: initialCategoryKey,
    ),
  );
}

class NewItemDialog extends StatefulWidget {
  final List<CategoryView> categories;
  final String initialCategoryKey;

  const NewItemDialog({
    super.key,
    required this.categories,
    required this.initialCategoryKey,
  });

  @override
  State<NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<NewItemDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  late String _categoryKey;

  @override
  void initState() {
    super.initState();
    _categoryKey = widget.initialCategoryKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  int? get _amount => parsePiastres(_amountController.text);

  bool get _canSave => _nameController.text.trim().isNotEmpty && _amount != null;

  void _save() {
    final amount = _amount;
    final name = _nameController.text.trim();
    if (name.isEmpty || amount == null) return;
    Navigator.of(context).pop(NewItemDraft(
      nameAr: name,
      categoryKey: _categoryKey,
      amountPiastres: amount,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('عنصر جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('new-item-name'),
              controller: _nameController,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(labelText: 'الاسم'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('new-item-amount'),
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ (جنيه)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: const Key('new-item-category'),
              value: _categoryKey,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الفئة'),
              items: [
                for (final category in widget.categories)
                  DropdownMenuItem(
                    value: category.key,
                    child: Text(category.labelAr),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _categoryKey = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('new-item-cancel'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const Key('new-item-save'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: _canSave ? _save : null,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
