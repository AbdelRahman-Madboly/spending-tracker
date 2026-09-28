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
  final String? subcategoryKey;
  final int amountPiastres;

  /// The barcode/QR value this item should be learned against, if it was
  /// opened via an unrecognised scan — carried straight through to
  /// `createItem` so the next scan of the same code resolves instantly.
  /// Null for every other way of opening this dialog.
  final String? barcode;

  const NewItemDraft({
    required this.nameAr,
    required this.categoryKey,
    this.subcategoryKey,
    required this.amountPiastres,
    this.barcode,
  });
}

/// Shows the new-item dialog and returns the entered draft, or null if the
/// user cancelled. [subcategories] should be [initialCategoryKey]'s own
/// subcategories (or empty if none are loaded) — together with
/// [initialSubcategoryKey], this carries the add sheet's current category
/// *and* subcategory selection into the جديد tile with no extra taps.
Future<NewItemDraft?> showNewItemDialog({
  required BuildContext context,
  required List<CategoryView> categories,
  required String initialCategoryKey,
  List<SubcategoryView> subcategories = const [],
  String? initialSubcategoryKey,
  String? initialBarcode,
}) {
  return showDialog<NewItemDraft>(
    context: context,
    builder: (_) => NewItemDialog(
      categories: categories,
      initialCategoryKey: initialCategoryKey,
      subcategories: subcategories,
      initialSubcategoryKey: initialSubcategoryKey,
      initialBarcode: initialBarcode,
    ),
  );
}

/// Shows the same dialog pre-filled with [item]'s current name, category
/// and default price, for editing an existing catalogue entry. Returns the
/// edited draft, or null if the user cancelled — the caller is responsible
/// for turning that into an `updateItem` repository call; this dialog never
/// touches the repository itself.
Future<NewItemDraft?> showEditItemDialog({
  required BuildContext context,
  required List<CategoryView> categories,
  required QuickPickItem item,
  List<SubcategoryView> subcategories = const [],
}) {
  return showDialog<NewItemDraft>(
    context: context,
    builder: (_) => NewItemDialog(
      categories: categories,
      initialCategoryKey: item.categoryKey,
      initialNameAr: item.nameAr,
      initialAmountPiastres: item.defaultAmountPiastres,
      subcategories: subcategories,
      initialSubcategoryKey: item.subcategoryKey,
    ),
  );
}

class NewItemDialog extends StatefulWidget {
  final List<CategoryView> categories;
  final String initialCategoryKey;

  /// [initialCategoryKey]'s own subcategories, used to populate the
  /// optional subcategory field. If the user switches the category dropdown
  /// to one this list wasn't loaded for, the subcategory field simply
  /// disappears rather than offer the wrong category's options — a rare,
  /// secondary interaction that isn't worth wiring a live repository lookup
  /// into this dialog for.
  final List<SubcategoryView> subcategories;
  final String? initialSubcategoryKey;

  /// When non-null (via [showEditItemDialog]), the dialog opens pre-filled
  /// for editing an existing item rather than a blank "new item" form.
  final String? initialNameAr;
  final int? initialAmountPiastres;

  /// Set when this dialog was opened from an unrecognised barcode/QR scan
  /// — shown to the user as confirmation and carried through to the
  /// returned [NewItemDraft] unchanged.
  final String? initialBarcode;

  const NewItemDialog({
    super.key,
    required this.categories,
    required this.initialCategoryKey,
    this.subcategories = const [],
    this.initialSubcategoryKey,
    this.initialNameAr,
    this.initialAmountPiastres,
    this.initialBarcode,
  });

  bool get isEditing => initialNameAr != null;

  @override
  State<NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<NewItemDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  late String _categoryKey;
  late String? _subcategoryKey;

  List<SubcategoryView> get _availableSubcategories => widget.subcategories
      .where((s) => s.categoryKey == _categoryKey)
      .toList();

  @override
  void initState() {
    super.initState();
    _categoryKey = widget.initialCategoryKey;
    _subcategoryKey = widget.initialSubcategoryKey;
    final initialNameAr = widget.initialNameAr;
    if (initialNameAr != null) _nameController.text = initialNameAr;
    final initialAmountPiastres = widget.initialAmountPiastres;
    if (initialAmountPiastres != null) {
      _amountController.text = formatPiastres(initialAmountPiastres);
    }
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
      subcategoryKey: _subcategoryKey,
      amountPiastres: amount,
      barcode: widget.initialBarcode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final availableSubcategories = _availableSubcategories;
    return AlertDialog(
      title: Text(widget.isEditing ? 'تعديل العنصر' : 'عنصر جديد'),
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
              initialValue: _categoryKey,
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
                if (value == null || value == _categoryKey) return;
                setState(() {
                  _categoryKey = value;
                  // A subcategory only ever belongs to one category — moving
                  // to a different one invalidates whatever was pre-filled
                  // or picked, the same cross-category rule the catalogue
                  // itself enforces.
                  if (!_availableSubcategories
                      .any((s) => s.key == _subcategoryKey)) {
                    _subcategoryKey = null;
                  }
                });
              },
            ),
            if (availableSubcategories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String?>(
                key: const Key('new-item-subcategory'),
                initialValue: _subcategoryKey,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الفئة الفرعية'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('بدون'),
                  ),
                  for (final subcategory in availableSubcategories)
                    DropdownMenuItem<String?>(
                      value: subcategory.key,
                      child: Text(subcategory.labelAr),
                    ),
                ],
                onChanged: (value) => setState(() => _subcategoryKey = value),
              ),
            ],
            if (widget.initialBarcode != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'باركود: ${widget.initialBarcode}',
                key: const Key('new-item-barcode'),
                style: AppText.caption,
              ),
            ],
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
