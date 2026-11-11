import 'layer.dart';

/// A colour family for designer words.
class WordPalette {
  const WordPalette(this.name, this.main, this.accent, this.gradient);
  final String name;
  final int main;
  final int accent;
  final List<int> gradient;
}

const wordPalettes = [
  WordPalette('Sunset', 0xFFFF5C39, 0xFFFFC857, [0xFFFFC857, 0xFFFF5C39, 0xFFFF3D8B]),
  WordPalette('Candy', 0xFFFF3D8B, 0xFF7C5CFF, [0xFFFF9AE0, 0xFFFF3D8B, 0xFF7C5CFF]),
  WordPalette('Ocean', 0xFF33D6E6, 0xFF2F6BFF, [0xFF8FF3FF, 0xFF33D6E6, 0xFF2F6BFF]),
  WordPalette('Lime', 0xFFB8FF3D, 0xFF00A37A, [0xFFF2FF5C, 0xFFB8FF3D, 0xFF2FD67B]),
  WordPalette('Gold', 0xFFFFD166, 0xFF9A6A00, [0xFFFFF4B8, 0xFFFFD166, 0xFFD99A00]),
  WordPalette('Mono', 0xFFFFFFFF, 0xFF15131F, [0xFFFFFFFF, 0xFFC9C6DA]),
];

const wordFonts = ['Anton', 'Bebas Neue', 'Montserrat', 'Pacifico', 'Permanent Marker', 'Playfair Display'];

/// How a word is drawn, before choosing its colours and font.
enum WordTreatment {
  solid('Solid'),
  outline('Outline'),
  pop('Pop'),
  gradient('Gradient'),
  gradientOutline('Gradient outline'),
  neon('Neon'),
  shadow('Shadow'),
  retro('Retro'),
  box('Box label'),
  pill('Pill label'),
  tag('Tag label'),
  glass('Glass label');

  const WordTreatment(this.label);
  final String label;

  bool get isLabel => index >= WordTreatment.box.index;
}

/// One designer-word look: treatment, palette and font.
class WordStyle {
  const WordStyle(this.treatment, this.palette, this.font);
  final WordTreatment treatment;
  final WordPalette palette;
  final String font;

  String get id => '${treatment.name}-${palette.name.toLowerCase()}-${font.toLowerCase().replaceAll(' ', '')}';
  String get name => '${treatment.label} · ${palette.name} · $font';

  /// Styles [layer], a text layer, with this look.
  void applyTo(CanvasLayer l) {
    final p = palette;
    final dark = p.name == 'Mono' ? p.accent : 0xFF15131F;
    final onMain = p.name == 'Mono' || p.name == 'Lime' || p.name == 'Gold' ? 0xFF15131F : 0xFFFFFFFF;
    l
      ..fontFamily = font
      ..bold = font != 'Pacifico'
      ..italic = false
      ..color = p.main
      ..gradient = null
      ..glowColor = null
      ..popColor = null
      ..strokeColor = null
      ..strokeWidth = .06
      ..shadow = false
      ..bgColor = null
      ..bgStyle = 0
      ..letterSpacing = 0;
    switch (treatment) {
      case WordTreatment.solid:
        l.shadow = true;
      case WordTreatment.outline:
        l
          ..color = 0x00FFFFFF
          ..strokeColor = p.main
          ..strokeWidth = .018;
      case WordTreatment.pop:
        l
          ..strokeColor = dark
          ..strokeWidth = .07
          ..popColor = p.accent;
      case WordTreatment.gradient:
        l
          ..gradient = p.gradient
          ..shadow = true;
      case WordTreatment.gradientOutline:
        l
          ..gradient = p.gradient
          ..strokeColor = 0xFFFFFFFF
          ..strokeWidth = .06;
      case WordTreatment.neon:
        l
          ..color = 0xFFFFFFFF
          ..glowColor = p.main;
      case WordTreatment.shadow:
        l
          ..color = 0xFFFFFFFF
          ..popColor = p.main;
      case WordTreatment.retro:
        l
          ..italic = true
          ..color = p.accent == 0xFF15131F ? 0xFFFFFFFF : p.accent
          ..popColor = p.main
          ..letterSpacing = .004;
      case WordTreatment.box:
        l
          ..bgColor = p.main
          ..bgStyle = 2
          ..color = onMain;
      case WordTreatment.pill:
        l
          ..bgColor = p.main
          ..bgStyle = 1
          ..color = onMain;
      case WordTreatment.tag:
        l
          ..bgColor = p.main
          ..bgStyle = 3
          ..color = onMain
          ..letterSpacing = .003;
      case WordTreatment.glass:
        l
          ..bgColor = 0x8C0B0A12
          ..bgStyle = 0
          ..color = p.main;
    }
  }
}

final List<WordStyle> wordStyles = [
  for (final t in WordTreatment.values)
    for (final p in wordPalettes)
      for (final f in wordFonts) WordStyle(t, p, f),
];

const wordCategories = <String, List<String>>{
  'Social': [
    'Subscribe',
    'Follow',
    'Like & share',
    'Link in bio',
    'New video',
    'Swipe up',
    'Tap here',
    'Comment below',
    'Turn on notifications',
    'Watch till the end',
  ],
  'Celebrate': [
    'Happy Birthday',
    'Congratulations',
    'Happy New Year',
    'Merry Christmas',
    'Happy Diwali',
    'Eid Mubarak',
    'Happy Holi',
    'Cheers',
    'Best day ever',
    'Party time',
  ],
  'Love': ['Love you', 'Forever', 'Mine', 'XOXO', 'Soulmate', 'Date night', 'Together', 'Just married', 'Bride to be', 'Love story'],
  'Travel': [
    'Wanderlust',
    'Road trip',
    'Adventure awaits',
    'Beach vibes',
    'Weekend getaway',
    'Explore',
    'Passport ready',
    'Mountains calling',
    'Sunset chaser',
    'Day 1',
  ],
  'Vlog': ['Vlog', 'Day in my life', 'Behind the scenes', 'Get ready with me', 'Morning routine', 'What I eat', 'Storytime', 'Q&A', 'Haul', 'Unboxing'],
  'Reactions': ['Wow', 'OMG', 'LOL', 'No way', 'Epic', 'Wait for it', 'Mind blown', 'Plot twist', 'Oops', 'Yesss'],
  'Business': ['Sale', '50% off', 'Limited offer', 'New arrival', 'Shop now', 'Free shipping', 'Coming soon', 'Grand opening', 'Book now', 'Best seller'],
  'Motivation': [
    'Dream big',
    'Never give up',
    'Stay humble',
    'Hustle',
    'Be kind',
    'You got this',
    'Keep going',
    'Good vibes only',
    'Believe',
    'Rise and shine',
  ],
  'Food': ['Yummy', "Chef's kiss", 'Foodie', 'Taste test', 'Recipe', 'Brunch time', 'Coffee first', 'Sweet tooth', 'Dinner is served', 'So good'],
  'Fitness': ['Workout', 'Leg day', 'No pain no gain', 'New PR', 'Beast mode', 'Sweat', 'Gym time', 'Before & after', 'Day 30', "Let's go"],
  'Gaming': ['Game over', 'Level up', 'Victory', 'GG', 'Winner', 'Respawn', 'Boss fight', 'Clutch', 'Loading...', 'Press start'],
  'Labels': [
    'NEW',
    'SALE',
    'LIVE',
    'HOT',
    'FREE',
    'TOP 10',
    'BREAKING NEWS',
    'EXCLUSIVE',
    'LIMITED',
    'TRENDING',
    'VS',
    'PART 1',
    'PART 2',
    'THE END',
    'TO BE CONTINUED',
    'SPOILER',
    'TIP',
    'FACT',
    'ON AIR',
    'REC',
  ],
};

/// A phrase in a style, ready to become a text layer.
class DesignerWord {
  const DesignerWord(this.text, this.category, this.style);
  final String text;
  final String category;
  final WordStyle style;

  CanvasLayer toLayer() {
    final l = CanvasLayer.text(text, size: category == 'Labels' ? .06 : .09)..name = 'Text';
    style.applyTo(l);
    return l;
  }
}

/// A lazily indexed set of designer words: every matching phrase in every
/// matching style. Phrases cycle fastest, so neighbours differ in wording, and
/// each phrase's styles are offset so neighbours also differ in look.
class WordResults {
  WordResults._(this._phrases, this._styles);

  final List<(String, String)> _phrases;
  final List<WordStyle> _styles;

  int get length => _phrases.length * _styles.length;

  DesignerWord operator [](int i) {
    final p = i % _phrases.length;
    final s = (i ~/ _phrases.length + p * 37) % _styles.length;
    final (text, category) = _phrases[p];
    return DesignerWord(text, category, _styles[s]);
  }

  static int get total => search().length;

  /// Words in [category] and [treatment] (null for any) matching [text]. Text
  /// that matches no phrase is used as the phrase itself, in every style.
  static WordResults search({String? category, WordTreatment? treatment, String text = ''}) {
    final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final phrases = <(String, String)>[
      for (final entry in wordCategories.entries)
        if (category == null || entry.key == category)
          for (final phrase in entry.value)
            if (words.every((w) => phrase.toLowerCase().contains(w) || entry.key.toLowerCase().contains(w))) (phrase, entry.key),
    ];
    if (phrases.isEmpty && text.trim().isNotEmpty) phrases.add((text.trim(), category ?? 'Custom'));
    final labelsOnly = category == 'Labels';
    final styles = [
      for (final s in wordStyles)
        if ((treatment == null || s.treatment == treatment) && (!labelsOnly || s.treatment.isLabel)) s,
    ];
    if (phrases.isEmpty || styles.isEmpty) return WordResults._(const [], const []);
    return WordResults._(phrases, styles);
  }
}
