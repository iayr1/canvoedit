import 'layer.dart';

/// Emoji that draw as colour pictures by default, as code point ranges.
const _emojiRanges = <(int, int)>[
  (0x1F600, 0x1F64F),
  (0x1F90C, 0x1F93A),
  (0x1F93C, 0x1F945),
  (0x1F947, 0x1F9FF),
  (0x1FA70, 0x1FA7C),
  (0x1FA80, 0x1FA89),
  (0x1FA90, 0x1FABD),
  (0x1FABF, 0x1FAC5),
  (0x1FACE, 0x1FADB),
  (0x1FAE0, 0x1FAE8),
  (0x1FAF0, 0x1FAF8),
  (0x1F300, 0x1F320),
  (0x1F32D, 0x1F335),
  (0x1F337, 0x1F37C),
  (0x1F37E, 0x1F393),
  (0x1F3A0, 0x1F3CA),
  (0x1F3CF, 0x1F3D3),
  (0x1F3E0, 0x1F3F0),
  (0x1F3F4, 0x1F3F4),
  // Skips the skin-tone modifiers, which draw as plain swatches.
  (0x1F3F8, 0x1F3FA),
  (0x1F400, 0x1F43E),
  (0x1F440, 0x1F440),
  (0x1F442, 0x1F4FC),
  (0x1F4FF, 0x1F53D),
  (0x1F54B, 0x1F54E),
  (0x1F550, 0x1F567),
  (0x1F57A, 0x1F57A),
  (0x1F595, 0x1F596),
  (0x1F5A4, 0x1F5A4),
  (0x1F5FB, 0x1F5FF),
  (0x1F680, 0x1F6C5),
  (0x1F6CC, 0x1F6CC),
  (0x1F6D0, 0x1F6D2),
  (0x1F6D5, 0x1F6D7),
  (0x1F6DC, 0x1F6DF),
  (0x1F6EB, 0x1F6EC),
  (0x1F6F4, 0x1F6FC),
  (0x1F7E0, 0x1F7EB),
  (0x1F7F0, 0x1F7F0),
  (0x2600, 0x2601),
  (0x2614, 0x2615),
  (0x2648, 0x2653),
  (0x267F, 0x267F),
  (0x2693, 0x2693),
  (0x26A1, 0x26A1),
  (0x26AA, 0x26AB),
  (0x26BD, 0x26BE),
  (0x26C4, 0x26C5),
  (0x26CE, 0x26CE),
  (0x26D4, 0x26D4),
  (0x26EA, 0x26EA),
  (0x26F2, 0x26F3),
  (0x26F5, 0x26F5),
  (0x26FA, 0x26FA),
  (0x26FD, 0x26FD),
  (0x2705, 0x2705),
  (0x270A, 0x270B),
  (0x2728, 0x2728),
  (0x274C, 0x274C),
  (0x274E, 0x274E),
  (0x2753, 0x2755),
  (0x2757, 0x2757),
  (0x2795, 0x2797),
  (0x27B0, 0x27B0),
  (0x27BF, 0x27BF),
  (0x2B1B, 0x2B1C),
  (0x2B50, 0x2B50),
  (0x2B55, 0x2B55),
  (0x2764, 0x2764),
];

String _categoryOf(int cp) {
  // Clothing and accessories.
  if ((cp >= 0x1F451 && cp <= 0x1F462) || (cp >= 0x1F97B && cp <= 0x1F97F) || (cp >= 0x1F9BA && cp <= 0x1F9BF) || (cp >= 0x1FA70 && cp <= 0x1FA7C)) {
    return 'Objects';
  }
  if ((cp >= 0x1F463 && cp <= 0x1F465) || cp == 0x1F440 || cp == 0x1F48F || cp == 0x1F491) return 'People';
  if (cp == 0x1F490) return 'Nature';
  if (cp >= 0x1F493 && cp <= 0x1F49F) return 'Symbols';
  if (cp >= 0x1F488 && cp <= 0x1F492) return 'Objects';
  if ((cp >= 0x1F600 && cp <= 0x1F64F) || (cp >= 0x1F910 && cp <= 0x1F92F) || (cp >= 0x1F970 && cp <= 0x1F97A) || (cp >= 0x1FAE0 && cp <= 0x1FAE8)) {
    return 'Faces';
  }
  if ((cp >= 0x1F466 && cp <= 0x1F487) ||
      (cp >= 0x1F442 && cp <= 0x1F450) ||
      (cp >= 0x1F90C && cp <= 0x1F90F) ||
      (cp >= 0x1F930 && cp <= 0x1F93A) ||
      (cp >= 0x1F9B0 && cp <= 0x1F9B9) ||
      (cp >= 0x1F9CD && cp <= 0x1F9DF) ||
      (cp >= 0x1FAF0 && cp <= 0x1FAF8) ||
      cp == 0x270A ||
      cp == 0x270B ||
      cp == 0x1F595 ||
      cp == 0x1F596 ||
      cp == 0x1F57A) {
    return 'People';
  }
  if ((cp >= 0x1F400 && cp <= 0x1F43E) ||
      (cp >= 0x1F980 && cp <= 0x1F9AE) ||
      (cp >= 0x1F330 && cp <= 0x1F344) ||
      (cp >= 0x1FAB0 && cp <= 0x1FABD) ||
      (cp >= 0x1FABF && cp <= 0x1FAC5) ||
      (cp >= 0x1F300 && cp <= 0x1F320)) {
    return 'Nature';
  }
  if ((cp >= 0x1F345 && cp <= 0x1F37F) ||
      (cp >= 0x1F950 && cp <= 0x1F96F) ||
      (cp >= 0x1F9C0 && cp <= 0x1F9CB) ||
      (cp >= 0x1FAD0 && cp <= 0x1FADB) ||
      (cp >= 0x1F32D && cp <= 0x1F32F)) {
    return 'Food';
  }
  if ((cp >= 0x1F380 && cp <= 0x1F3F8) ||
      (cp >= 0x1F93C && cp <= 0x1F94F) ||
      (cp >= 0x1FA70 && cp <= 0x1FA7C) ||
      cp == 0x26BD ||
      cp == 0x26BE ||
      cp == 0x26F3) {
    return 'Activities';
  }
  if ((cp >= 0x1F680 && cp <= 0x1F6FF) ||
      (cp >= 0x1F3E0 && cp <= 0x1F3F0) ||
      (cp >= 0x1F5FB && cp <= 0x1F5FF) ||
      cp == 0x26F5 ||
      cp == 0x26FD ||
      cp == 0x2693 ||
      cp == 0x26EA ||
      cp == 0x26F2 ||
      cp == 0x26FA) {
    return 'Travel';
  }
  if ((cp >= 0x1F4A0 && cp <= 0x1F4FF) || (cp >= 0x1F500 && cp <= 0x1F53D) || (cp >= 0x1FA80 && cp <= 0x1FAAF) || (cp >= 0x1F9E0 && cp <= 0x1F9FF)) {
    return 'Objects';
  }
  return 'Symbols';
}

/// A sticker: an emoji, or a shape drawn by the app.
class StickerItem {
  const StickerItem.emoji(this.emoji, this.category) : shape = null, color = 0;
  const StickerItem.shape(this.shape, this.color) : emoji = null, category = 'Shapes';

  final String? emoji;
  final ShapeKind? shape;
  final int color;
  final String category;

  CanvasLayer toLayer() {
    if (emoji != null) return CanvasLayer.sticker(emoji!);
    return CanvasLayer.shape(shape!, fill: color, width: .26, aspect: shape == ShapeKind.line ? .1 : 1)..name = 'Shape';
  }
}

const shapeStickerColors = [
  0xFFFF5C39,
  0xFFFF3D8B,
  0xFF7C5CFF,
  0xFF33D6E6,
  0xFFFFC857,
  0xFF2FD67B,
  0xFFFFFFFF,
  0xFF15131F,
  0xFFFF9AE0,
  0xFF2F6BFF,
  0xFFB8FF3D,
  0xFFE63946,
];

class StickerLibrary {
  StickerLibrary._() {
    for (final (from, to) in _emojiRanges) {
      for (var cp = from; cp <= to; cp++) {
        // Older symbols need the emoji presentation selector to draw in colour.
        final text = cp < 0x1F000 ? '${String.fromCharCode(cp)}️' : String.fromCharCode(cp);
        all.add(StickerItem.emoji(text, _categoryOf(cp)));
      }
    }
    for (final shape in ShapeKind.values) {
      for (final color in shapeStickerColors) {
        all.add(StickerItem.shape(shape, color));
      }
    }
  }

  static final instance = StickerLibrary._();

  final List<StickerItem> all = [];

  static const categories = ['Faces', 'People', 'Nature', 'Food', 'Activities', 'Travel', 'Objects', 'Symbols', 'Shapes'];

  int get length => all.length;

  List<StickerItem> inCategory(String? category) => category == null
      ? all
      : [
          for (final s in all)
            if (s.category == category) s,
        ];
}
