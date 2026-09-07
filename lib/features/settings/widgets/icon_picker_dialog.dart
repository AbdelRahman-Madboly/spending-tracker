import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../add/widgets/category_strip.dart' show curatedIconNames, iconForName;

/// Shows a grid of curated Material icons and returns the chosen icon's
/// stored name (e.g. `local_drink`), or null if the user cancelled. Used
/// by the category and subcategory dialogs so nobody ever has to type an
/// icon name by hand.
Future<String?> showIconPickerDialog({
  required BuildContext context,
  required String currentIconName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => IconPickerDialog(currentIconName: currentIconName),
  );
}

class IconPickerDialog extends StatelessWidget {
  final String currentIconName;

  const IconPickerDialog({super.key, required this.currentIconName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختيار أيقونة'),
      content: SizedBox(
        width: 320,
        height: 360,
        child: GridView.builder(
          key: const Key('icon-picker-grid'),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
          ),
          itemCount: curatedIconNames.length,
          itemBuilder: (context, index) {
            final name = curatedIconNames[index];
            final selected = name == currentIconName;
            return InkWell(
              key: Key('icon-option-$name'),
              onTap: () => Navigator.of(context).pop(name),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                // Clears the 48dp minimum tap target regardless of the
                // grid cell's own size.
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconForName(name),
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          key: const Key('icon-picker-cancel'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
