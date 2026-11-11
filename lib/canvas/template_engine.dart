import 'dart:math' as math;

import '../core/artwork.dart';
import 'document.dart';
import 'layer.dart';
import 'template_library.dart';
import 'templates.dart';

/// A canvas size people design for, such as an Instagram story.
class TemplateFormat {
  const TemplateFormat(this.group, this.name, this.width, this.height);
  final String group;
  final String name;
  final int width;
  final int height;

  String get label => '$group $name';
}

const templateFormats = <TemplateFormat>[
  TemplateFormat('Instagram', 'Post', 1080, 1080),
  TemplateFormat('Instagram', 'Portrait post', 1080, 1350),
  TemplateFormat('Instagram', 'Story', 1080, 1920),
  TemplateFormat('Instagram', 'Reel cover', 1080, 1920),
  TemplateFormat('Instagram', 'Carousel', 1080, 1350),
  TemplateFormat('Facebook', 'Post', 1200, 630),
  TemplateFormat('Facebook', 'Cover', 1640, 624),
  TemplateFormat('Facebook', 'Event cover', 1920, 1005),
  TemplateFormat('Facebook', 'Story', 1080, 1920),
  TemplateFormat('Facebook', 'Ad', 1080, 1080),
  TemplateFormat('LinkedIn', 'Post', 1200, 627),
  TemplateFormat('LinkedIn', 'Profile banner', 1584, 396),
  TemplateFormat('LinkedIn', 'Company cover', 1128, 191),
  TemplateFormat('LinkedIn', 'Article cover', 1920, 1080),
  TemplateFormat('LinkedIn', 'Carousel', 1080, 1080),
  TemplateFormat('X', 'Post', 1600, 900),
  TemplateFormat('X', 'Header', 1500, 500),
  TemplateFormat('YouTube', 'Thumbnail', 1280, 720),
  TemplateFormat('YouTube', 'Channel banner', 2560, 1440),
  TemplateFormat('YouTube', 'Shorts cover', 1080, 1920),
  TemplateFormat('YouTube', 'End screen', 1920, 1080),
  TemplateFormat('Pinterest', 'Pin', 1000, 1500),
  TemplateFormat('Pinterest', 'Long pin', 1000, 2100),
  TemplateFormat('TikTok', 'Video cover', 1080, 1920),
  TemplateFormat('WhatsApp', 'Status', 1080, 1920),
  TemplateFormat('Twitch', 'Banner', 1200, 480),
  TemplateFormat('Twitch', 'Panel', 640, 320),
  TemplateFormat('Web', 'Leaderboard ad', 728, 90),
  TemplateFormat('Web', 'Rectangle ad', 600, 500),
  TemplateFormat('Web', 'Skyscraper ad', 320, 1200),
  TemplateFormat('Web', 'Website hero', 1920, 1080),
  TemplateFormat('Web', 'Blog header', 1200, 600),
  TemplateFormat('Web', 'Shop banner', 3360, 840),
  TemplateFormat('Email', 'Header', 1200, 400),
  TemplateFormat('Email', 'Newsletter', 1200, 2400),
  TemplateFormat('Print', 'Poster A4', 2480, 3508),
  TemplateFormat('Print', 'Poster A3', 3508, 4961),
  TemplateFormat('Print', 'Flyer', 2550, 3300),
  TemplateFormat('Print', 'Postcard', 1800, 1200),
  TemplateFormat('Print', 'Business card', 1050, 600),
  TemplateFormat('Print', 'Invitation', 1500, 2100),
  TemplateFormat('Print', 'Greeting card', 1500, 2100),
  TemplateFormat('Print', 'Certificate', 3508, 2480),
  TemplateFormat('Print', 'Menu', 2480, 3508),
  TemplateFormat('Print', 'Brochure page', 2550, 3300),
  TemplateFormat('Print', 'Ticket', 2000, 700),
  TemplateFormat('Print', 'Gift voucher', 2000, 900),
  TemplateFormat('Print', 'Label', 1200, 1200),
  TemplateFormat('Print', 'Bookmark', 600, 1800),
  TemplateFormat('Print', 'Letterhead', 2480, 3508),
  TemplateFormat('Presentation', 'Slide 16:9', 1920, 1080),
  TemplateFormat('Presentation', 'Slide 4:3', 1024, 768),
  TemplateFormat('Wallpaper', 'Phone', 1080, 2340),
  TemplateFormat('Wallpaper', 'Desktop', 2560, 1440),
  TemplateFormat('Wallpaper', 'Video call background', 1920, 1080),
  TemplateFormat('Books & music', 'Book cover', 1600, 2560),
  TemplateFormat('Books & music', 'Album cover', 1400, 1400),
  TemplateFormat('Books & music', 'Podcast cover', 1400, 1400),
  TemplateFormat('Business', 'Logo', 1000, 1000),
  TemplateFormat('Business', 'Infographic', 1000, 2500),
];

List<String> get templateFormatGroups {
  final seen = <String>{};
  return [
    for (final f in templateFormats)
      if (seen.add(f.group)) f.group,
  ];
}

/// Topics beyond the original library's, with sample wording.
const _extraCopy = <String, List<TemplateCopy>>{
  'Photography': [
    TemplateCopy('NEW SERIES', 'Through\nMy Lens', 'Moments worth keeping', 'View gallery'),
    TemplateCopy('BOOK A SHOOT', 'Capture\nYour Story', 'Portraits, events and more', 'Book now'),
    TemplateCopy('PHOTO WALK', 'Golden\nHour Club', 'Sunday at 5 PM', 'Join us'),
  ],
  'Nature': [
    TemplateCopy('GET OUTSIDE', 'Into the\nWild', 'Fresh air does wonders', 'Explore'),
    TemplateCopy('EARTH DAY', 'Protect\nOur Planet', 'Small acts, big change', 'Learn how'),
    TemplateCopy('WEEKEND TRAIL', 'Find\nYour Peak', 'Guided hikes every Saturday', 'Sign up'),
  ],
  'Coffee': [
    TemplateCopy('FRESHLY BREWED', 'But First,\nCoffee', 'Your morning starts here', 'Order now'),
    TemplateCopy('NEW BLEND', 'Bold &\nSmooth', 'Roasted in small batches', 'Try it'),
    TemplateCopy('HAPPY HOUR', 'Two for\nOne Lattes', 'Weekdays, 3 to 5 PM', 'Visit us'),
  ],
  'Pets': [
    TemplateCopy('ADOPT ME', 'Find Your\nBest Friend', 'Pets waiting for a home', 'Meet them'),
    TemplateCopy('PET CARE', 'Happy Pets\nLive Here', 'Grooming and daycare', 'Book now'),
    TemplateCopy('MEET', 'The New\nPuppy', 'Say hello to our newest member', 'Follow along'),
  ],
  'Sports': [
    TemplateCopy('MATCH DAY', 'Game\nNight', 'Saturday, 8 PM kick-off', 'Get tickets'),
    TemplateCopy('JOIN THE TEAM', 'Tryouts\nOpen', 'All skill levels welcome', 'Register'),
    TemplateCopy('FINAL SCORE', 'We\nWon', 'Thank you, fans', 'Highlights'),
  ],
  'Health': [
    TemplateCopy('WELLNESS', 'Feel\nYour Best', 'Simple habits for every day', 'Read more'),
    TemplateCopy('NOW OPEN', 'Your\nHealth First', 'Book a check-up today', 'Book now'),
    TemplateCopy('MINDFULNESS', 'Breathe\nIn, Out', 'Five minutes of calm', 'Start now'),
  ],
  'Charity': [
    TemplateCopy('MAKE A DIFFERENCE', 'Give\nHope', 'Every donation counts', 'Donate'),
    TemplateCopy('VOLUNTEER', 'Lend a\nHand', 'Join us this weekend', 'Sign up'),
    TemplateCopy('FUNDRAISER', 'Together\nWe Can', 'Help us reach our goal', 'Support us'),
  ],
  'Christmas': [
    TemplateCopy('SEASON\'S GREETINGS', 'Merry\nChristmas', 'Warm wishes to you and yours', 'With love'),
    TemplateCopy('HOLIDAY SALE', 'Gifts\nGalore', 'Up to 40% off this week', 'Shop now'),
    TemplateCopy('YOU\'RE INVITED', 'Christmas\nParty', 'December 24, 7 PM', 'RSVP'),
  ],
  'New Year': [
    TemplateCopy('CHEERS TO', 'Happy\nNew Year', 'Here\'s to new beginnings', 'Celebrate'),
    TemplateCopy('COUNTDOWN', 'New Year\nParty', 'December 31, 9 PM', 'Get tickets'),
    TemplateCopy('NEW YEAR', 'New\nGoals', 'Make this year yours', 'Start today'),
  ],
  'Valentine': [
    TemplateCopy('FEBRUARY 14', 'Be My\nValentine', 'With all my love', 'Love you'),
    TemplateCopy('LOVE SALE', 'Gifts\nFrom Heart', 'Picked for someone special', 'Shop now'),
    TemplateCopy('DATE NIGHT', 'Dinner\nFor Two', 'Reserve your table', 'Book now'),
  ],
  'Diwali': [
    TemplateCopy('FESTIVAL OF LIGHTS', 'Happy\nDiwali', 'May your home shine bright', 'Warm wishes'),
    TemplateCopy('DIWALI SALE', 'Festive\nOffers', 'Celebrate with special deals', 'Shop now'),
    TemplateCopy('JOIN US', 'Diwali\nCelebration', 'Lights, sweets and music', 'RSVP'),
  ],
  'Graduation': [
    TemplateCopy('CLASS OF 2026', 'We Did\nIt', 'Congratulations, graduates', 'Celebrate'),
    TemplateCopy('YOU\'RE INVITED', 'Graduation\nParty', 'Saturday at 6 PM', 'RSVP'),
    TemplateCopy('PROUD MOMENT', 'Future\nStarts Now', 'On to the next chapter', 'Cheers'),
  ],
  'Baby': [
    TemplateCopy('SAY HELLO TO', 'Our Little\nOne', 'Born with love', 'Welcome'),
    TemplateCopy('BABY SHOWER', 'Oh\nBaby', 'Join us to celebrate', 'RSVP'),
    TemplateCopy('IT\'S A', 'Sweet\nSurprise', 'Coming this spring', 'Stay tuned'),
  ],
  'Restaurant': [
    TemplateCopy('NOW SERVING', 'Taste\nThe Best', 'Fresh dishes every day', 'View menu'),
    TemplateCopy('GRAND OPENING', 'Dinner\nIs Served', 'Opening night offers', 'Reserve'),
    TemplateCopy('WEEKEND BRUNCH', 'Brunch\nClub', 'Saturdays and Sundays', 'Book a table'),
  ],
};

final Map<String, List<TemplateCopy>> _copy = {...templateTopicCopy, ..._extraCopy};
final List<String> templateTopicNames = _copy.keys.toList();

/// Colour moods: a name for each palette, used as a filter.
const templateColorNames = <String>[
  'Midnight',
  'Cream',
  'Royal blue',
  'Clean white',
  'Forest',
  'Peach',
  'Electric',
  'Monochrome',
  'Mint',
  'Crimson',
  'Sky',
  'Teal',
];

class TemplateStyle {
  const TemplateStyle(this.name, this.photos, this.layout);
  final String name;

  /// How many photo frames the style has.
  final int photos;
  final void Function(TemplateBuilder) layout;
}

/// One template, identified by its position in the catalogue.
class TemplateSpec {
  const TemplateSpec(this.format, this.topic, this.style, this.color);
  final int format;
  final int topic;
  final int style;
  final int color;

  TemplateFormat get formatInfo => templateFormats[format];
  String get topicName => templateTopicNames[topic];
  TemplateStyle get styleInfo => templateStyles[style];
  String get colorName => templateColorNames[color];

  String get id => '$format.$topic.$style.$color';
  String get name => '$topicName ${formatInfo.name.toLowerCase()}';
  int get _seed => (format * 7919 + topic * 104729 + style * 1299709 + color * 15485863) & 0x7fffffff;

  DesignTemplate toTemplate() => DesignTemplate(name, topicName, build, format: formatInfo.label);

  CanvasDocument build() {
    final f = formatInfo;
    final copies = _copy[topicName]!;
    final b = TemplateBuilder(
      f.width,
      f.height,
      templatePalettes[color],
      templateFontPairs[_seed % templateFontPairs.length],
      copies[_seed % copies.length],
      _seed,
    );
    if (b.ratio < .42 || b.ratio > 2.6) {
      _banner(b, styleInfo.photos);
    } else {
      styleInfo.layout(b);
    }
    return CanvasDocument(
      name: name,
      pixelWidth: f.width,
      pixelHeight: f.height,
      background: CanvasBackground(b.p.bg, color2: b.p.bg2, angle: 60),
      layers: b.layers,
    );
  }
}

/// Filters for the catalogue. A null set means any value.
class TemplateQuery {
  const TemplateQuery({this.formats, this.topics, this.styles, this.colors, this.photos, this.text = ''});
  final Set<int>? formats;
  final Set<int>? topics;
  final Set<int>? styles;
  final Set<int>? colors;

  /// Number of photo frames wanted.
  final int? photos;
  final String text;

  TemplateQuery copyWith({
    Set<int>? Function()? formats,
    Set<int>? Function()? topics,
    Set<int>? Function()? styles,
    Set<int>? Function()? colors,
    int? Function()? photos,
    String? text,
  }) => TemplateQuery(
    formats: formats == null ? this.formats : formats(),
    topics: topics == null ? this.topics : topics(),
    styles: styles == null ? this.styles : styles(),
    colors: colors == null ? this.colors : colors(),
    photos: photos == null ? this.photos : photos(),
    text: text ?? this.text,
  );

  bool get isEmpty => formats == null && topics == null && styles == null && colors == null && photos == null && text.trim().isEmpty;
}

/// The result of a query: a lazy, ordered list over every matching template.
class TemplateResults {
  TemplateResults._(this._f, this._t, this._s, this._c) {
    length = _f.length * _t.length * _s.length * _c.length;
    _stride = _strideFor(length);
    // Different filters start at different places, so rows of collections
    // shown side by side don't all open with the same look.
    _offset = length == 0 ? 0 : (_f.first * 7919 + _f.length * 104729 + _t.first * 1301 + _t.length * 613 + _s.first * 97) % length;
  }

  late final int _offset;

  final List<int> _f, _t, _s, _c;
  late final int length;
  late final int _stride;

  /// Neighbouring results should differ, so items are visited with a stride
  /// that shares no factor with the count. That visits every one exactly once.
  static int _strideFor(int n) {
    if (n < 3) return 1;
    var s = (n * .6180339887).floor() | 1;
    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    while (gcd(s, n) != 1) {
      s += 2;
    }
    return s;
  }

  TemplateSpec operator [](int i) {
    var k = (i * _stride + _offset) % length;
    final f = _f[k % _f.length];
    k ~/= _f.length;
    final t = _t[k % _t.length];
    k ~/= _t.length;
    final s = _s[k % _s.length];
    k ~/= _s.length;
    return TemplateSpec(f, t, s, _c[k % _c.length]);
  }
}

class TemplateCatalog {
  static int get total => templateFormats.length * templateTopicNames.length * templateStyles.length * templateColorNames.length;

  /// Every filter value on offer, counted across all facets.
  static int get filterCount =>
      templateFormatGroups.length + templateFormats.length + templateTopicNames.length + templateStyles.length + templateColorNames.length + 5;

  static TemplateResults search(TemplateQuery q) {
    var formats = q.formats ?? {for (var i = 0; i < templateFormats.length; i++) i};
    var topics = q.topics ?? {for (var i = 0; i < templateTopicNames.length; i++) i};
    var styles = q.styles ?? {for (var i = 0; i < templateStyles.length; i++) i};
    var colors = q.colors ?? {for (var i = 0; i < templateColorNames.length; i++) i};
    if (q.photos != null) {
      styles = styles.where((s) => templateStyles[s].photos == q.photos).toSet();
    }

    // Each search word narrows whichever facets it names. A word that names
    // nothing matches no templates.
    for (final word in q.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1)) {
      bool has(String s) => s.toLowerCase().contains(word);
      final f = {
        for (var i = 0; i < templateFormats.length; i++)
          if (has(templateFormats[i].label)) i,
      };
      final t = {
        for (var i = 0; i < templateTopicNames.length; i++)
          if (has(templateTopicNames[i])) i,
      };
      final s = {
        for (var i = 0; i < templateStyles.length; i++)
          if (has(templateStyles[i].name)) i,
      };
      final c = {
        for (var i = 0; i < templateColorNames.length; i++)
          if (has(templateColorNames[i])) i,
      };
      if (f.isEmpty && t.isEmpty && s.isEmpty && c.isEmpty) {
        formats = {};
        break;
      }
      // A word like "story" may match both a format and a topic; the facet with
      // a match narrows, the others are left alone.
      if (f.isNotEmpty) {
        formats = formats.intersection(f);
      } else if (t.isNotEmpty) {
        topics = topics.intersection(t);
      } else if (s.isNotEmpty) {
        styles = styles.intersection(s);
      } else {
        colors = colors.intersection(c);
      }
    }
    List<int> sorted(Set<int> s) => s.toList()..sort();
    return TemplateResults._(sorted(formats), sorted(topics), sorted(styles), sorted(colors));
  }

  static Set<int> formatsInGroup(String group) => {
    for (var i = 0; i < templateFormats.length; i++)
      if (templateFormats[i].group == group) i,
  };
}

// ---------------------------------------------------------------------------
// Coordinates are fractions of canvas width (x)
// and height (y), so one layout fits any size.

/// Building blocks for one template; see the layouts below.
class TemplateBuilder {
  TemplateBuilder(this.width, this.height, this.p, this.fonts, this.copy, this.seed);
  final int width;
  final int height;
  final TemplatePalette p;
  final (String, String) fonts;
  final TemplateCopy copy;
  final int seed;
  final layers = <CanvasLayer>[];
  int _photo = 0;

  /// Height divided by width.
  double get ratio => height / width;
  bool get wide => ratio < .8;

  String _nextArt() => artScenes[(seed + _photo++ * 5) % artScenes.length].path;

  CanvasLayer frame(double x0, double y0, double x1, double y1, {ShapeKind mask = ShapeKind.rectangle, double rotation = 0}) {
    final w = x1 - x0, h = y1 - y0;
    final aspect = h * ratio / w;
    if (mask == ShapeKind.arch && aspect < 1.05) mask = ShapeKind.rounded;
    final l = CanvasLayer.frame(path: _nextArt(), mask: mask, width: w, aspect: aspect)
      ..cx = x0 + w / 2
      ..cy = y0 + h / 2
      ..rotation = rotation;
    layers.add(l);
    return l;
  }

  CanvasLayer box(double x0, double y0, double x1, double y1, int color, {double opacity = 1, ShapeKind shape = ShapeKind.rectangle, double rotation = 0}) {
    final w = x1 - x0, h = y1 - y0;
    final l = CanvasLayer.shape(shape, fill: color, width: w, aspect: h * ratio / w)
      ..cx = x0 + w / 2
      ..cy = y0 + h / 2
      ..opacity = opacity
      ..rotation = rotation;
    layers.add(l);
    return l;
  }

  /// A circle [d] wide (fraction of width) centred at x, y.
  void dot(double x, double y, double d, int color, {double opacity = 1}) => layers.add(
    CanvasLayer.shape(ShapeKind.circle, fill: color, width: d)
      ..cx = x
      ..cy = y
      ..opacity = opacity,
  );

  CanvasLayer _text(String t, String font, double size, int color, {bool bold = false, int? bg, double spacing = 0, bool shadow = false}) =>
      CanvasLayer.text(t, font: font, size: size, color: color)
        ..bold = bold
        ..bgColor = bg
        ..letterSpacing = spacing
        ..shadow = shadow;

  static double _fit(String t, double room, double cap) {
    final longest = t.split('\n').map((l) => l.length).reduce(math.max);
    return math.min(cap, room / (longest * templateGlyphWidth));
  }

  /// Stacks the copy in a region. [parts] picks which lines appear.
  void text(
    double x0,
    double y0,
    double x1,
    double y1, {
    required int ink,
    int? ctaFg,
    int? ctaBg,
    bool kicker = true,
    bool sub = true,
    bool cta = true,
    bool shadow = false,
    bool oneLine = false,
  }) {
    final room = (x1 - x0) * .86;
    final headline = oneLine ? copy.headline.replaceAll('\n', ' ') : copy.headline;
    final items = <CanvasLayer>[
      if (kicker) _text(copy.kicker, fonts.$2, math.max(.006, _fit(copy.kicker, room * .78, .03)), ink, bold: true, spacing: .004, shadow: shadow),
      _text(headline, fonts.$1, templateHeadlineSize(headline, maxWidth: room), ink, shadow: shadow),
      if (sub) _text(copy.sub, fonts.$2, _fit(copy.sub, room, .04), ink, shadow: shadow),
      if (cta) _text(copy.cta, fonts.$2, _fit(copy.cta, room * .7, .036), ctaFg ?? p.onAccent, bold: true, bg: ctaBg ?? p.accent),
    ];
    stackText(items, ratio, y0, y1, gap: math.min(.025, (y1 - y0) * .05));
    for (final l in items) {
      l.cx = (x0 + x1) / 2;
    }
    layers.addAll(items);
  }
}

/// Very wide or tall formats, like web ads and banners: photos to one side and
/// a short line of copy beside them.
void _banner(TemplateBuilder b, int photos) {
  final n = math.min(math.max(photos, 0), 3);
  if (b.ratio < 1) {
    final strip = n == 0 ? 0.0 : math.min(.5, .16 * n + .1);
    for (var i = 0; i < n; i++) {
      final w = strip / n;
      b.frame(1 - strip + i * w + .004, .08, 1 - strip + (i + 1) * w - .004, .92, mask: ShapeKind.rounded);
    }
    b.box(0, 0, .012, 1, b.p.accent);
    b.text(.03, .1, 1 - strip - .02, .9, ink: b.p.ink, sub: b.ratio > .2, cta: b.ratio > .3, oneLine: true);
  } else {
    final strip = n == 0 ? 0.0 : math.min(.5, .14 * n + .1);
    for (var i = 0; i < n; i++) {
      final h = strip / n;
      b.frame(.08, i * h + .006, .92, (i + 1) * h - .006, mask: ShapeKind.rounded);
    }
    b.box(0, 1 - .01, 1, 1, b.p.accent);
    b.text(.06, strip + .03, .94, .97, ink: b.p.ink);
  }
}

// The styles. Each handles wide, square and tall canvases.
final List<TemplateStyle> templateStyles = [
  TemplateStyle('Full photo', 1, (b) {
    b.frame(0, 0, 1, 1);
    if (b.wide) {
      b.box(0, 0, .52, 1, b.p.bg, opacity: .86);
      b.text(.03, .1, .5, .9, ink: b.p.ink);
    } else {
      b.box(0, .56, 1, 1, b.p.bg, opacity: .86);
      b.text(.05, .59, .95, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Photo card', 1, (b) {
    b.frame(0, 0, 1, 1);
    final (x0, y0, x1, y1) = b.wide ? (.2, .16, .8, .84) : (.1, .26, .9, .74);
    b.box(x0, y0, x1, y1, b.p.bg, opacity: .93, shape: ShapeKind.rounded);
    b.text(x0, y0 + .03, x1, y1 - .03, ink: b.p.ink);
  }),
  TemplateStyle('Split', 1, (b) {
    if (b.wide) {
      b.frame(0, 0, .5, 1);
      b.text(.52, .1, .98, .9, ink: b.p.ink);
    } else {
      b.frame(0, 0, 1, .55);
      b.text(.05, .58, .95, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Photo panel', 1, (b) {
    if (b.wide) {
      b.frame(.46, .08, .96, .92, mask: ShapeKind.rounded);
      b.box(.04, .08, .055, .3, b.p.accent);
      b.text(.07, .1, .44, .9, ink: b.p.ink);
    } else {
      b.frame(.06, .06, .94, .58, mask: ShapeKind.rounded);
      b.text(.06, .61, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Circle', 1, (b) {
    if (b.wide) {
      final d = math.min(.4, .84 * b.ratio);
      final h = d / b.ratio;
      b.dot(.27, .5, d * 1.12, b.p.accent, opacity: .9);
      b.frame(.27 - d / 2, .5 - h / 2, .27 + d / 2, .5 + h / 2, mask: ShapeKind.circle);
      b.text(.5, .1, .97, .9, ink: b.p.ink);
    } else {
      const d = .62;
      final h = d / b.ratio;
      b.dot(.5, .06 + h / 2, d * 1.1, b.p.accent, opacity: .9);
      b.frame(.5 - d / 2, .06, .5 + d / 2, .06 + h, mask: ShapeKind.circle);
      b.text(.06, .1 + h, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Arch', 1, (b) {
    if (b.wide) {
      b.frame(.06, .08, .4, .92, mask: ShapeKind.arch);
      b.text(.44, .1, .97, .9, ink: b.p.ink);
    } else {
      b.box(0, 0, 1, .34, b.p.accent, opacity: .35);
      b.frame(.18, .05, .82, .6, mask: ShapeKind.arch);
      b.text(.06, .63, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Polaroid', 1, (b) {
    if (b.wide) {
      b.box(.06, .1, .42, .9, 0xFFFFFFFF, rotation: -.05);
      b.frame(.085, .15, .395, .72, rotation: -.05);
      b.text(.47, .1, .97, .9, ink: b.p.ink);
    } else {
      b.box(.14, .05, .86, .62, 0xFFFFFFFF, rotation: -.04);
      b.frame(.18, .08, .82, .52, rotation: -.04);
      b.text(.06, .66, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Duo', 2, (b) {
    if (b.wide) {
      b.frame(.02, .06, .34, .94, mask: ShapeKind.rounded);
      b.frame(.36, .06, .68, .94, mask: ShapeKind.rounded);
      b.text(.69, .1, .99, .9, ink: b.p.ink, sub: false);
    } else {
      b.frame(.05, .04, .495, .5, mask: ShapeKind.rounded);
      b.frame(.505, .04, .95, .5, mask: ShapeKind.rounded);
      b.text(.06, .54, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Trio', 3, (b) {
    if (b.wide) {
      b.frame(.02, .06, .4, .94, mask: ShapeKind.rounded);
      b.frame(.41, .06, .62, .495, mask: ShapeKind.rounded);
      b.frame(.41, .505, .62, .94, mask: ShapeKind.rounded);
      b.text(.64, .1, .99, .9, ink: b.p.ink, sub: false);
    } else {
      b.frame(.05, .04, .95, .34, mask: ShapeKind.rounded);
      b.frame(.05, .35, .495, .58, mask: ShapeKind.rounded);
      b.frame(.505, .35, .95, .58, mask: ShapeKind.rounded);
      b.text(.06, .61, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Grid', 4, (b) {
    if (b.wide) {
      for (var i = 0; i < 4; i++) {
        final x0 = .02 + (i % 2) * .23, y0 = .06 + (i ~/ 2) * .45;
        b.frame(x0, y0, x0 + .22, y0 + .43, mask: ShapeKind.rounded);
      }
      b.text(.5, .1, .98, .9, ink: b.p.ink);
    } else {
      for (var i = 0; i < 4; i++) {
        final x0 = .05 + (i % 2) * .455, y0 = .04 + (i ~/ 2) * .27;
        b.frame(x0, y0, x0 + .445, y0 + .26, mask: ShapeKind.rounded);
      }
      b.text(.06, .61, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Bordered', 1, (b) {
    b.box(0, 0, 1, 1, b.p.accent);
    if (b.wide) {
      b.frame(.03, .07, .55, .93);
      b.box(.57, .07, .97, .93, b.p.bg);
      b.text(.58, .1, .96, .9, ink: b.p.ink);
    } else {
      b.frame(.06, .04, .94, .6);
      b.box(.06, .62, .94, .97, b.p.bg);
      b.text(.08, .64, .92, .95, ink: b.p.ink);
    }
  }),
  TemplateStyle('Magazine', 1, (b) {
    b.frame(0, 0, 1, 1);
    b.box(0, 0, 1, b.wide ? .45 : .32, 0xFF000000, opacity: .35);
    b.text(.05, .03, .95, b.wide ? .42 : .3, ink: 0xFFFFFFFF, sub: false, cta: false, shadow: true);
    b.box(0, .86, 1, 1, 0xFF000000, opacity: .45);
    b.text(.05, .87, .95, .99, ink: 0xFFFFFFFF, kicker: false, cta: false, shadow: true, oneLine: true);
  }),
  TemplateStyle('Diagonal', 1, (b) {
    b.frame(0, 0, 1, 1);
    if (b.wide) {
      b.box(-.1, -.2, .62, 1.2, b.p.bg, opacity: .92, rotation: .08);
      b.text(.03, .1, .5, .9, ink: b.p.ink);
    } else {
      b.box(-.2, .55, 1.2, 1.15, b.p.bg, opacity: .94, rotation: -.06);
      b.text(.06, .64, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Film strip', 3, (b) {
    if (b.wide) {
      b.box(0, .14, 1, .62, 0xFF111111);
      for (var i = 0; i < 3; i++) {
        b.frame(.04 + i * .32, .19, .32 + i * .32, .57);
      }
      b.text(.05, .66, .95, .97, ink: b.p.ink, kicker: false, sub: false, oneLine: true);
    } else {
      b.box(0, .06, 1, .5, 0xFF111111);
      for (var i = 0; i < 3; i++) {
        b.frame(.05 + i * .305, .12, .315 + i * .305, .44);
      }
      b.text(.06, .54, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Offset card', 1, (b) {
    if (b.wide) {
      b.box(.08, .16, .46, .96, b.p.accent, shape: ShapeKind.rounded);
      b.frame(.04, .06, .42, .86, mask: ShapeKind.rounded);
      b.text(.5, .1, .97, .9, ink: b.p.ink);
    } else {
      b.box(.16, .08, .92, .58, b.p.accent, shape: ShapeKind.rounded);
      b.frame(.08, .04, .84, .54, mask: ShapeKind.rounded);
      b.text(.06, .62, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Bold type', 0, (b) {
    b.dot(.9, .08, .5, b.p.accent, opacity: .9);
    b.dot(.08, .96, .4, b.p.accent, opacity: .35);
    b.text(.06, .14, .94, .9, ink: b.p.ink);
  }),
  TemplateStyle('Bubbles', 2, (b) {
    if (b.wide) {
      const d = .26;
      final h = d / b.ratio;
      b.frame(.04, .5 - h * .65, .04 + d, .5 + h * .35, mask: ShapeKind.circle);
      b.frame(.2, .5 - h * .35, .2 + d, .5 + h * .65, mask: ShapeKind.circle);
      b.text(.5, .1, .97, .9, ink: b.p.ink);
    } else {
      final d = math.min(.5, .38 * b.ratio);
      final h = d / b.ratio;
      b.frame(.06, .05, .06 + d, .05 + h, mask: ShapeKind.circle);
      b.frame(.44, .05 + h * .55, .44 + d, .05 + h * 1.55, mask: ShapeKind.circle);
      b.text(.06, .1 + h * 1.55, .94, .97, ink: b.p.ink);
    }
  }),
  TemplateStyle('Inset', 1, (b) {
    if (b.wide) {
      b.frame(.7, .12, .96, .88, mask: ShapeKind.rounded);
      b.text(.03, .1, .66, .9, ink: b.p.ink);
    } else {
      b.text(.06, .04, .94, .52, ink: b.p.ink, cta: false);
      b.frame(.3, .56, .94, .96, mask: ShapeKind.rounded);
      b.box(.06, .56, .26, .96, b.p.accent, shape: ShapeKind.rounded);
    }
  }),
];
