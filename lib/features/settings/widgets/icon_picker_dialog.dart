import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/category_colors.dart';
import '../../../core/design/tokens.dart';

/// Shows a grid of the curated Material Symbols and returns the chosen
/// icon's stored name (e.g. `local_drink`), or null if the user cancelled.
/// Used by the category and subcategory dialogs so nobody ever has to type
/// an icon name by hand.
///
/// [colorKey], when given, draws every glyph in that category colour, so
/// the user picks the icon as it will actually appear.
Future<String?> showIconPickerDialog({
  required BuildContext context,
  required String currentIconName,
  String? colorKey,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => IconPickerDialog(
      currentIconName: currentIconName,
      colorKey: colorKey,
    ),
  );
}

class IconPickerDialog extends StatelessWidget {
  final String currentIconName;
  final String? colorKey;

  const IconPickerDialog({
    super.key,
    required this.currentIconName,
    this.colorKey,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // A stored legacy name (say `cake`) resolves to the same glyph as a
    // picker name (`bakery_dining`); comparing glyphs keeps it marked.
    final currentGlyph = iconFor(currentIconName);
    final ink = colorKey == null
        ? palette.textPrimary
        : palette.categoryInk(colorKey!);
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
            final selected = iconFor(name) == currentGlyph;
            return Semantics(
              selected: selected,
              button: true,
              child: InkWell(
                key: Key('icon-option-$name'),
                onTap: () => Navigator.of(context).pop(name),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Container(
                  // Clears the 48dp minimum tap target regardless of the
                  // grid cell's own size.
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: selected
                        ? Border.all(color: palette.primary, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    iconFor(name),
                    // Outlined by default, filled only for the selection
                    // (spec §7.2).
                    fill: selected ? 1 : 0,
                    color: ink,
                  ),
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
