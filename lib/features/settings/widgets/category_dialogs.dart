import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/category_colors.dart';
import '../../../core/design/tokens.dart';
import '../../../domain/models.dart';
import 'icon_picker_dialog.dart';

/// The user's input for a category: its Arabic label, icon and colour
/// (one of `categoryInks`' keys). The key is never part of this draft — it
/// is generated once at creation and never changes afterwards, so there is
/// nothing here for a rename to touch.
class CategoryDraft {
  final String labelAr;
  final String iconName;
  final String colorKey;

  const CategoryDraft({
    required this.labelAr,
    required this.iconName,
    required this.colorKey,
  });
}

/// Shows the add/edit category dialog. Pass [initialLabelAr]/
/// [initialIconName]/[initialColorKey] to pre-fill it for editing an
/// existing category; leave them null for "add a new category", which
/// starts on the generic `category` icon and the `Other` colour. Returns
/// the entered draft, or null if the user cancelled.
Future<CategoryDraft?> showCategoryDialog({
  required BuildContext context,
  String? initialLabelAr,
  String? initialIconName,
  String? initialColorKey,
}) {
  return showDialog<CategoryDraft>(
    context: context,
    builder: (_) => _CategoryDialog(
      initialLabelAr: initialLabelAr,
      initialIconName: initialIconName,
      initialColorKey: initialColorKey,
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  final String? initialLabelAr;
  final String? initialIconName;
  final String? initialColorKey;

  const _CategoryDialog({
    this.initialLabelAr,
    this.initialIconName,
    this.initialColorKey,
  });

  bool get isEditing => initialLabelAr != null;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _nameController = TextEditingController();
  late String _iconName;
  late String _colorKey;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialLabelAr ?? '';
    _iconName = widget.initialIconName ?? 'category';
    // A key the palette doesn't know (none should exist, but a row is
    // user data) shows as Other rather than leaving nothing selected.
    final initialColor = widget.initialColorKey;
    _colorKey = initialColor != null && categoryInks.containsKey(initialColor)
        ? initialColor
        : 'Other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  Future<void> _pickIcon() async {
    final picked = await showIconPickerDialog(
      context: context,
      currentIconName: _iconName,
      colorKey: _colorKey,
    );
    if (picked != null) setState(() => _iconName = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(CategoryDraft(
      labelAr: name,
      iconName: _iconName,
      colorKey: _colorKey,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'تعديل القسم' : 'قسم جديد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('category-dialog-name'),
            controller: _nameController,
            autofocus: true,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(labelText: 'الاسم'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('category-dialog-icon-button'),
              onPressed: _pickIcon,
              icon: Icon(iconFor(_iconName),
                  color: context.palette.categoryInk(_colorKey)),
              label: const Text('تغيير الأيقونة'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('اللون',
              style: AppText.label
                  .copyWith(color: context.palette.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          _ColorKeyPicker(
            selected: _colorKey,
            onSelected: (key) => setState(() => _colorKey = key),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('category-dialog-cancel'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const Key('category-dialog-save'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: _canSave ? _save : null,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

/// The user's input for a subcategory: its Arabic label, icon and which
/// category it lives under (letting the dialog double as the "move to
/// another category" control). As with [CategoryDraft], the key is never
/// part of this draft.
class SubcategoryDraft {
  final String labelAr;
  final String iconName;
  final String categoryKey;

  const SubcategoryDraft({
    required this.labelAr,
    required this.iconName,
    required this.categoryKey,
  });
}

/// Shows the add/edit subcategory dialog. Pass [initialLabelAr]/
/// [initialIconName] to pre-fill it for editing an existing subcategory;
/// leave them null for "add a new subcategory" under [initialCategoryKey].
/// Returns the entered draft, or null if the user cancelled.
Future<SubcategoryDraft?> showSubcategoryDialog({
  required BuildContext context,
  required List<CategoryView> categories,
  required String initialCategoryKey,
  String? initialLabelAr,
  String? initialIconName,
}) {
  return showDialog<SubcategoryDraft>(
    context: context,
    builder: (_) => _SubcategoryDialog(
      categories: categories,
      initialCategoryKey: initialCategoryKey,
      initialLabelAr: initialLabelAr,
      initialIconName: initialIconName,
    ),
  );
}

class _SubcategoryDialog extends StatefulWidget {
  final List<CategoryView> categories;
  final String initialCategoryKey;
  final String? initialLabelAr;
  final String? initialIconName;

  const _SubcategoryDialog({
    required this.categories,
    required this.initialCategoryKey,
    this.initialLabelAr,
    this.initialIconName,
  });

  bool get isEditing => initialLabelAr != null;

  @override
  State<_SubcategoryDialog> createState() => _SubcategoryDialogState();
}

class _SubcategoryDialogState extends State<_SubcategoryDialog> {
  final _nameController = TextEditingController();
  late String _iconName;
  late String _categoryKey;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialLabelAr ?? '';
    _iconName = widget.initialIconName ?? 'category';
    _categoryKey = widget.initialCategoryKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  Future<void> _pickIcon() async {
    final picked = await showIconPickerDialog(
      context: context,
      currentIconName: _iconName,
    );
    if (picked != null) setState(() => _iconName = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(SubcategoryDraft(
      labelAr: name,
      iconName: _iconName,
      categoryKey: _categoryKey,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'تعديل الفئة الفرعية' : 'فئة فرعية جديدة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('subcategory-dialog-name'),
              controller: _nameController,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(labelText: 'الاسم'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: const Key('subcategory-dialog-category'),
              initialValue: _categoryKey,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'القسم'),
              items: [
                for (final category in widget.categories)
                  DropdownMenuItem(
                    value: category.key,
                    child: Text(category.labelAr),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _categoryKey = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const Key('subcategory-dialog-icon-button'),
                onPressed: _pickIcon,
                icon: Icon(iconFor(_iconName)),
                label: const Text('تغيير الأيقونة'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('subcategory-dialog-cancel'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const Key('subcategory-dialog-save'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: _canSave ? _save : null,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

/// Shows a confirmation dialog before archiving a category or subcategory
/// that has children (subcategories and/or items for a category; items for
/// a subcategory), stating in Arabic exactly what else will be hidden along
/// with it, that nothing is deleted, and that it can be undone from the
/// archive. Returns true if the user confirmed, false/null if they
/// cancelled.
///
/// Callers should skip this dialog entirely (and archive directly) when
/// there is nothing riding along — an item, or a category/subcategory with
/// zero children, needs no warning.
Future<bool?> showArchiveCascadeConfirmationDialog({
  required BuildContext context,
  required String labelAr,
  required String childrenSummary,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('أرشفة "$labelAr"؟'),
      content: Text(
        key: const Key('archive-confirm-message'),
        'هيتخفي معاها $childrenSummary من كل القوائم. البيانات القديمة '
        '(التواريخ والمبالغ) مش هتتأثر، وتقدر ترجعها في أي وقت من الأرشيف.',
        style: AppText.body,
      ),
      actions: [
        TextButton(
          key: const Key('archive-confirm-cancel'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const Key('archive-confirm-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('أرشفة'),
        ),
      ],
    ),
  );
}

/// The category colour choices of spec §7.2: one swatch per colour key,
/// drawn in the current mode's ink. The selected one is filled and ringed,
/// with a check, so the choice never rests on colour alone.
class _ColorKeyPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _ColorKeyPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      children: [
        for (final key in categoryInks.keys)
          Semantics(
            selected: key == selected,
            button: true,
            label: key,
            child: InkWell(
              key: Key('color-option-$key'),
              customBorder: const CircleBorder(),
              onTap: () => onSelected(key),
              // 48dp tap target around a 32dp swatch.
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.categoryInk(key),
                      border: key == selected
                          ? Border.all(color: palette.textPrimary, width: 2)
                          : null,
                    ),
                    child: key == selected
                        ? Icon(AppIcons.check,
                            size: 20, color: palette.surface)
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
