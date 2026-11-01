import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';

/// A free multiline note (spec §6.5): what was bought, a line per spend,
/// the way it would go in a phone's notes. راجع hands the text to the
/// review sheet, which runs it through the parser.
///
/// [onChanged] is told the text as it is typed, so a note closed before
/// review can still be kept.
class TextNoteSheet extends StatefulWidget {
  final ValueChanged<String>? onChanged;

  const TextNoteSheet({super.key, this.onChanged});

  @override
  State<TextNoteSheet> createState() => _TextNoteSheetState();
}

class _TextNoteSheetState extends State<TextNoteSheet> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      widget.onChanged?.call(_text.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ready = _text.text.trim().isNotEmpty;
    return Padding(
      key: const Key('text-note-sheet'),
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.gutter,
        end: AppSpacing.gutter,
        top: AppSpacing.lg,
        // Above the keyboard, which this sheet opens with.
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.textNote, color: palette.primary),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Text('اكتب مصاريفك', style: AppText.title)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('text-note-field'),
            controller: _text,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'طماطم 2 كيلو ب 30\nعيش ب 10',
              helperText: 'كل مصروف في سطر، والسعر بعد «ب»',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('text-note-review'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed:
                ready ? () => Navigator.of(context).pop(_text.text.trim()) : null,
            icon: const Icon(AppIcons.review, size: 20),
            label: const Text('راجع'),
          ),
        ],
      ),
    );
  }
}
