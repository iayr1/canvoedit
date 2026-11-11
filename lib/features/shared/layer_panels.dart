import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../canvas/layer.dart';
import '../../canvas/renderer.dart';
import 'grade_panels.dart';

const stickerEmoji = [
  '😀',
  '😂',
  '🥰',
  '😎',
  '🤩',
  '🥳',
  '😭',
  '🤯',
  '🔥',
  '✨',
  '💯',
  '❤️',
  '💜',
  '⭐',
  '🌈',
  '☀️',
  '🌙',
  '⚡',
  '🎉',
  '🎂',
  '🎈',
  '🎁',
  '🎵',
  '🎧',
  '📷',
  '🎬',
  '✈️',
  '🌍',
  '🏖️',
  '🌸',
  '🌴',
  '🍕',
  '☕',
  '🍦',
  '👑',
  '💎',
  '👍',
  '👏',
  '🙌',
  '💪',
  '➡️',
  '⬇️',
  '✅',
  '❌',
  '💬',
  '📍',
  '🛒',
  '💡',
];

class StickerGrid extends StatelessWidget {
  const StickerGrid({super.key, required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 170,
    child: GridView.count(
      crossAxisCount: 8,
      padding: const EdgeInsets.all(8),
      children: [
        for (final s in stickerEmoji)
          InkWell(
            onTap: () => onPick(s),
            child: Center(child: Text(s, style: const TextStyle(fontSize: 26))),
          ),
      ],
    ),
  );
}

/// Font, colour and style controls for a text layer.
class TextStylePanel extends StatelessWidget {
  const TextStylePanel({super.key, required this.layer, required this.onCommit, required this.onFontReady, required this.onFontFailed});

  final CanvasLayer layer;
  final VoidCallback onCommit;
  final VoidCallback onFontReady;
  final VoidCallback onFontFailed;

  Widget _toggle(IconData icon, String tooltip, bool on, VoidCallback flip) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon, size: 20, color: on ? AppColors.coral : Colors.white),
    onPressed: () {
      flip();
      onCommit();
    },
  );

  @override
  Widget build(BuildContext context) {
    final l = layer;
    return SizedBox(
      height: 134,
      child: ListView(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final font in appFonts)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(font, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      selected: l.fontFamily == font,
                      onSelected: (_) {
                        l.fontFamily = font;
                        onCommit();
                        SceneRenderer.prepare([l]).then((_) => onFontReady()).catchError((Object _) => onFontFailed());
                      },
                    ),
                  ),
              ],
            ),
          ),
          SwatchRow(
            selected: l.color,
            onPick: (c) {
              l.color = c!;
              onCommit();
            },
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _toggle(Icons.format_bold, 'Bold', l.bold, () => l.bold = !l.bold),
                _toggle(Icons.format_italic, 'Italic', l.italic, () => l.italic = !l.italic),
                _toggle(Icons.format_align_left, 'Align left', l.align == 0, () => l.align = 0),
                _toggle(Icons.format_align_center, 'Align center', l.align == 1, () => l.align = 1),
                _toggle(Icons.format_align_right, 'Align right', l.align == 2, () => l.align = 2),
                _toggle(Icons.blur_on, 'Shadow', l.shadow, () => l.shadow = !l.shadow),
                _toggle(Icons.crop_square, 'Background', l.bgColor != null, () => l.bgColor = l.bgColor == null ? 0xCC000000 : null),
                _toggle(Icons.format_size, 'Wide spacing', l.letterSpacing > 0, () => l.letterSpacing = l.letterSpacing > 0 ? 0 : .012),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showTextDialog(BuildContext context, String initial) {
  final field = TextEditingController(text: initial)..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Text'),
      content: TextField(
        controller: field,
        autofocus: true,
        maxLines: null,
        decoration: const InputDecoration(hintText: 'Type something'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, field.text), child: const Text('OK')),
      ],
    ),
  );
}
