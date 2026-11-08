import 'dart:math' as math;

import 'document.dart';
import 'layer.dart';
import 'templates.dart';

/// Colours for one generated template. `ink` sits on `bg`, and `onAccent` sits
/// on `accent`; a test holds every palette to readable contrast.
class TemplatePalette {
  const TemplatePalette(this.bg, this.bg2, this.ink, this.accent, this.onAccent);
  final int bg;
  final int? bg2;
  final int ink;
  final int accent;
  final int onAccent;
}

const templatePalettes = <TemplatePalette>[
  TemplatePalette(0xFF10121A, 0xFF23263A, 0xFFFFFFFF, 0xFFFF5C39, 0xFF10121A),
  TemplatePalette(0xFFF7F1E3, null, 0xFF22223B, 0xFFB8452E, 0xFFFFFFFF),
  TemplatePalette(0xFF0F172A, 0xFF1D4ED8, 0xFFFFFFFF, 0xFFFACC15, 0xFF0F172A),
  TemplatePalette(0xFFFFFFFF, null, 0xFF111827, 0xFF7C3AED, 0xFFFFFFFF),
  TemplatePalette(0xFF14342B, null, 0xFFF1FAEE, 0xFFE9C46A, 0xFF14342B),
  TemplatePalette(0xFFFFE8D6, 0xFFFFD6E0, 0xFF3D2C8D, 0xFFE11D74, 0xFFFFFFFF),
  TemplatePalette(0xFF3A0CA3, 0xFF7209B7, 0xFFFFFFFF, 0xFF4CC9F0, 0xFF10121A),
  TemplatePalette(0xFF111111, null, 0xFFFFFFFF, 0xFFFFFFFF, 0xFF111111),
  TemplatePalette(0xFFECFDF5, null, 0xFF064E3B, 0xFF047857, 0xFFFFFFFF),
  TemplatePalette(0xFF7F1D1D, 0xFFB91C1C, 0xFFFFF7ED, 0xFFFDE68A, 0xFF7F1D1D),
  TemplatePalette(0xFFEFF6FF, 0xFFDBEAFE, 0xFF1E3A8A, 0xFF1D4ED8, 0xFFFFFFFF),
  TemplatePalette(0xFF1F2937, null, 0xFFF9FAFB, 0xFF2DD4BF, 0xFF0F172A),
  TemplatePalette(0xFFFEF3C7, null, 0xFF78350F, 0xFFB45309, 0xFFFFFFFF),
  TemplatePalette(0xFF042F2E, 0xFF115E59, 0xFFF0FDFA, 0xFFFB923C, 0xFF042F2E),
  TemplatePalette(0xFFFDF2F8, null, 0xFF831843, 0xFFBE185D, 0xFFFFFFFF),
  TemplatePalette(0xFF2B2118, null, 0xFFF5E6D3, 0xFFD4A373, 0xFF2B2118),
  TemplatePalette(0xFFF1F5F9, null, 0xFF0F172A, 0xFF0F172A, 0xFFF8FAFC),
  TemplatePalette(0xFF4C1D95, 0xFFBE185D, 0xFFFFFFFF, 0xFFFDE047, 0xFF3B0764),
  TemplatePalette(0xFF0C4A6E, 0xFF0369A1, 0xFFF0F9FF, 0xFFFDE68A, 0xFF0C4A6E),
  TemplatePalette(0xFFFFF7ED, 0xFFFFEDD5, 0xFF7C2D12, 0xFFC2410C, 0xFFFFFFFF),
];

const _fontPairs = <(String, String)>[
  ('Anton', 'Poppins'),
  ('Bebas Neue', 'Inter'),
  ('Playfair Display', 'Lora'),
  ('Montserrat', 'Inter'),
  ('Oswald', 'Poppins'),
  ('Space Grotesk', 'Inter'),
  ('Merriweather', 'Poppins'),
  ('Pacifico', 'Montserrat'),
  ('Lobster', 'Inter'),
  ('Dancing Script', 'Lora'),
];

class _Copy {
  const _Copy(this.kicker, this.headline, this.sub, this.cta);
  final String kicker;
  final String headline;
  final String sub;
  final String cta;
}

/// Sample wording by topic. Users replace it, so it stays generic.
const _topics = <String, List<_Copy>>{
  'Sale': [
    _Copy('LIMITED TIME', 'Mega\nSale', 'Up to 50% off everything', 'Shop now'),
    _Copy('THIS WEEKEND', 'Flash\nDeals', 'New offers every hour', 'Grab yours'),
    _Copy('END OF SEASON', 'Last\nChance', 'While stocks last', 'See offers'),
  ],
  'Quote': [
    _Copy('DAILY QUOTE', 'Start where\nyou are', 'Use what you have', '@yourname'),
    _Copy('THINK ABOUT IT', 'Small steps\ncount', 'Every day, a little more', '@yourname'),
    _Copy('A REMINDER', 'Be kind\nto yourself', 'You are doing fine', '@yourname'),
  ],
  'Birthday': [
    _Copy('TODAY WE CELEBRATE', 'Happy\nBirthday', 'Wishing you the best year yet', 'With love'),
    _Copy('YOU ARE INVITED', 'Birthday\nParty', 'Saturday, 7 PM at our place', 'RSVP'),
    _Copy('ANOTHER YEAR', 'Cheers\nto You', 'May this year be your best', 'Celebrate'),
  ],
  'Wedding': [
    _Copy('SAVE THE DATE', 'Together\nForever', 'Sunday, 14 February', 'Details inside'),
    _Copy('PLEASE JOIN US', 'We Are\nGetting Married', 'Your name and partner', 'RSVP'),
    _Copy('WITH GRATITUDE', 'Thank You\nFor Coming', 'Our hearts are full', 'Love, us'),
  ],
  'Event': [
    _Copy('LIVE THIS MONTH', 'Night\nMarket', 'Food, music and makers', 'Get tickets'),
    _Copy('JOIN US', 'Open Day\n2026', 'Saturday from 10 AM', 'Register'),
    _Copy('ONE NIGHT ONLY', 'City\nLights', 'Doors open at 7 PM', 'Book now'),
  ],
  'Podcast': [
    _Copy('NEW EPISODE', 'The Long\nTalk', 'Honest stories every week', 'Listen now'),
    _Copy('EPISODE 12', 'Ideas\nThat Stick', 'With your special guest', 'Play'),
    _Copy('OUT NOW', 'Behind\nThe Mic', 'Available on all apps', 'Subscribe'),
  ],
  'Fitness': [
    _Copy('NEW PROGRAM', 'Stronger\nEvery Day', '30 days to a better you', 'Join today'),
    _Copy('NO EXCUSES', 'Train\nHard', 'Classes start Monday', 'Sign up'),
    _Copy('MORNING SESSION', 'Move\nYour Body', 'All levels welcome', 'Book a spot'),
  ],
  'Food': [
    _Copy('FRESH TODAY', 'Chef\nSpecial', 'Made from scratch daily', 'Order now'),
    _Copy('NEW ON THE MENU', 'Taste\nThe Season', 'Try it this week', 'View menu'),
    _Copy('HAPPY HOUR', 'Good Food\nGood Mood', 'Every day, 4 to 7 PM', 'Reserve'),
  ],
  'Travel': [
    _Copy('NEXT STOP', 'Wander\nMore', 'Find your next escape', 'Plan a trip'),
    _Copy('SUMMER GETAWAY', 'Island\nDays', 'Packages from your city', 'Book now'),
    _Copy('TRAVEL DIARY', 'Lost in\nThe Hills', 'Notes from the road', 'Read more'),
  ],
  'Real Estate': [
    _Copy('JUST LISTED', 'Your Dream\nHome', '3 bedrooms, great location', 'Book a visit'),
    _Copy('OPEN HOUSE', 'Come\nSee It', 'Sunday from 11 AM', 'Get directions'),
    _Copy('NOW SELLING', 'Modern\nLiving', 'Ready to move in', 'Enquire'),
  ],
  'Education': [
    _Copy('NOW ENROLLING', 'Learn\nSomething New', 'Courses for every level', 'Apply now'),
    _Copy('FREE WORKSHOP', 'Five Quick\nTips', 'Learn in under an hour', 'Save a seat'),
    _Copy('BACK TO SCHOOL', 'Study\nSmarter', 'Simple habits that work', 'Find out how'),
  ],
  'Music': [
    _Copy('NEW SINGLE', 'Midnight\nDrive', 'Out everywhere Friday', 'Stream now'),
    _Copy('ON TOUR', 'Live\nIn Concert', 'Tickets on sale now', 'Get tickets'),
    _Copy('THE PLAYLIST', 'Late Night\nVibes', 'Fresh songs every week', 'Listen'),
  ],
  'Fashion': [
    _Copy('NEW COLLECTION', 'Style\nEdit', 'Fresh looks for the season', 'Shop the look'),
    _Copy('JUST DROPPED', 'Street\nWear', 'Limited pieces only', 'Explore'),
    _Copy('LOOKBOOK', 'Wear It\nYour Way', 'Everyday essentials', 'View all'),
  ],
  'Technology': [
    _Copy('NOW AVAILABLE', 'Meet the\nNew App', 'Faster, simpler, smarter', 'Download'),
    _Copy('PRODUCT UPDATE', 'Version\n2.0', 'See what changed', 'Learn more'),
    _Copy('TECH TALK', 'Build\nBetter', 'Tips for your next project', 'Read on'),
  ],
  'Hiring': [
    _Copy('JOIN OUR TEAM', 'We Are\nHiring', 'Roles open in every team', 'Apply today'),
    _Copy('OPEN ROLE', 'Your Next\nJob', 'Remote friendly', 'See the role'),
    _Copy('GROW WITH US', 'Careers\nStart Here', 'Interviews this month', 'Send your CV'),
  ],
  'Thank You': [
    _Copy('FROM ALL OF US', 'Thank\nYou', 'We could not do it without you', 'With thanks'),
    _Copy('10K STRONG', 'You Made\nThis Happen', 'Thanks for being here', 'Stay tuned'),
    _Copy('GRATEFUL', 'Thanks\nA Lot', 'Your support means everything', 'Keep in touch'),
  ],
  'Festival': [
    _Copy('WARM WISHES', 'Happy\nDiwali', 'May your home be full of light', 'From our family'),
    _Copy('SEASON\'S GREETINGS', 'Merry\nChristmas', 'Peace and joy to you', 'With love'),
    _Copy('BLESSINGS TO YOU', 'Eid\nMubarak', 'Joy and peace to your family', 'Warm regards'),
  ],
  'Giveaway': [
    _Copy('ENTER TO WIN', 'Big\nGiveaway', 'Follow, like and tag a friend', 'Enter now'),
    _Copy('WIN THIS', 'Free\nPrize', 'Winner announced Friday', 'Join in'),
    _Copy('CONTEST', 'Your Turn\nTo Win', 'Three lucky winners', 'How to enter'),
  ],
  'Testimonial': [
    _Copy('HAPPY CUSTOMER', 'Simply\nThe Best', 'Five stars from our clients', 'Read reviews'),
    _Copy('WHAT THEY SAY', 'Worth\nEvery Penny', 'A customer in your city', 'See more'),
    _Copy('REAL REVIEWS', 'Loved\nBy Many', 'Thousands of happy people', 'Try it'),
  ],
  'Announcement': [
    _Copy('IMPORTANT', 'Big\nNews', 'Details coming very soon', 'Stay tuned'),
    _Copy('WE MOVED', 'New\nAddress', 'Come see our new space', 'Find us'),
    _Copy('UPDATE', 'Opening\nHours', 'Changing from next week', 'See times'),
  ],
  'Coming Soon': [
    _Copy('GET READY', 'Coming\nSoon', 'Something new is on the way', 'Notify me'),
    _Copy('COUNTDOWN', 'Just\nDays Left', 'Mark your calendar', 'Set a reminder'),
    _Copy('SNEAK PEEK', 'Almost\nHere', 'Be the first to know', 'Join the list'),
  ],
  'Beauty': [
    _Copy('SELF CARE', 'Glow\nUp', 'Skin care made simple', 'Shop now'),
    _Copy('NEW IN', 'Pure\nRadiance', 'Gentle on every skin type', 'Discover'),
    _Copy('SALON DAY', 'Fresh\nLook', 'Book your appointment', 'Book now'),
  ],
  'Gaming': [
    _Copy('LIVE NOW', 'Game\nOn', 'Streaming every night', 'Watch live'),
    _Copy('TOURNAMENT', 'Final\nRound', 'Top teams, big prizes', 'Register'),
    _Copy('NEW VIDEO', 'Level\nUp', 'Tips to win every match', 'Watch now'),
  ],
  'Motivation': [
    _Copy('MONDAY MOOD', 'Keep\nGoing', 'Progress over perfection', 'You got this'),
    _Copy('DREAM BIG', 'Dream\nBigger', 'Then work for it', 'Start today'),
    _Copy('STAY FOCUSED', 'One Day\nAt a Time', 'Consistency wins', 'Keep moving'),
  ],
  'Business': [
    _Copy('WHO WE ARE', 'Grow Your\nBusiness', 'Strategy that delivers', 'Contact us'),
    _Copy('OUR SERVICES', 'Work\nSmarter', 'Plans for every budget', 'Get a quote'),
    _Copy('FREE WEBINAR', 'Marketing\nMade Simple', 'Live this Thursday', 'Register'),
  ],
  'Kids': [
    _Copy('STORY TIME', 'Fun\nFor All', 'Games, songs and crafts', 'Join us'),
    _Copy('SUMMER CAMP', 'Play and\nLearn', 'Ages 5 to 12', 'Enrol now'),
    _Copy('PARTY TIME', 'Kids\nCorner', 'Every Saturday morning', 'Come along'),
  ],
};

const _formats = <(String, int, int)>[
  ('Post', 1080, 1080),
  ('Portrait', 1080, 1350),
  ('Story', 1080, 1920),
  ('Thumbnail', 1280, 720),
  ('Facebook', 1200, 630),
  ('Poster', 2480, 3508),
];

class _Ctx {
  _Ctx(this.p, this.copy, this.display, this.body, this.width, this.height);
  final TemplatePalette p;
  final _Copy copy;
  final String display;
  final String body;
  final int width;
  final int height;

  /// Canvas height divided by width.
  double get ratio => height / width;

  CanvasLayer text(String t, double y, String font, double size, int color, {bool bold = false, int? bg, double spacing = 0}) =>
      CanvasLayer.text(t, font: font, size: size, color: color)
        ..cy = y
        ..bold = bold
        ..bgColor = bg
        ..letterSpacing = spacing;

  CanvasLayer kicker(int color) => text(copy.kicker, 0, body, .03, color, bold: true, spacing: .006);
  CanvasLayer headline(int color, {double maxWidth = .84}) =>
      text(copy.headline, 0, display, templateHeadlineSize(copy.headline, maxWidth: maxWidth), color);
  CanvasLayer sub(int color) => text(copy.sub, 0, body, math.min(.04, .84 / (copy.sub.length * templateGlyphWidth)), color);
  CanvasLayer cta(int fg, int? bg) => text(copy.cta, 0, body, .036, fg, bold: true, bg: bg);

  CanvasLayer shape(ShapeKind kind, double x, double y, double w, int fill, {double aspect = 1, double rotation = 0, double opacity = 1, int? stroke}) =>
      CanvasLayer.shape(kind, fill: fill, width: w, aspect: aspect)
        ..cx = x
        ..cy = y
        ..rotation = rotation
        ..opacity = opacity
        ..strokeColor = stroke
        ..strokeWidth = .008;

  /// A full-width bar [h] tall as a fraction of canvas height.
  CanvasLayer band(double y, double h, int fill, {double opacity = 1}) =>
      shape(ShapeKind.rectangle, .5, y, 1, fill, aspect: h * ratio, opacity: opacity);

  /// Stacks [items] centred between [top] and [bottom] (fractions of height),
  /// shrinking every font in proportion if they don't fit. Line height is fixed
  /// by the renderer, so these heights are exact rather than estimated.
  List<CanvasLayer> column(List<CanvasLayer> items, double top, double bottom, {double gap = .025}) =>
      stackText(items, ratio, top, bottom, gap: gap);
}

/// Height of a text layer as a fraction of canvas height.
double templateTextHeight(CanvasLayer l, double ratio) {
  final lines = '\n'.allMatches(l.text).length + 1;
  final pad = l.bgColor == null ? 0.0 : l.fontSize * .5;
  return (lines * l.fontSize * 1.15 + pad) / ratio;
}

/// See [_Ctx.column].
List<CanvasLayer> stackText(List<CanvasLayer> items, double ratio, double top, double bottom, {double gap = .025}) {
  final gaps = gap * (items.length - 1);
  final available = bottom - top - gaps;
  final natural = items.fold(0.0, (sum, l) => sum + templateTextHeight(l, ratio));
  if (natural > available) {
    final scale = available / natural;
    for (final l in items) {
      l.fontSize *= scale;
      l.letterSpacing *= scale;
    }
  }
  final used = items.fold(0.0, (sum, l) => sum + templateTextHeight(l, ratio)) + gaps;
  var y = top + (bottom - top - used) / 2;
  for (final l in items) {
    final h = templateTextHeight(l, ratio);
    l.cy = y + h / 2;
    y += h + gap;
  }
  return items;
}

/// Sizes a headline by its longest line; [stackText] handles height.
double templateHeadlineSize(String headline, {double maxWidth = .84}) {
  final longest = headline.split('\n').map((l) => l.length).reduce(math.max);
  return math.min(.24, maxWidth / (longest * templateGlyphWidth));
}

/// Assumed average glyph width, as a fraction of font size.
const templateGlyphWidth = .62;

List<CanvasLayer> _all(_Ctx c, int ink) => [c.kicker(ink), c.headline(ink), c.sub(ink), c.cta(c.p.onAccent, c.p.accent)];

/// Decorative arrangements. Text is stacked into regions that avoid the
/// decoration, so every layout works on tall, square and wide canvases.
final List<List<CanvasLayer> Function(_Ctx)> _layouts = [
  (c) => c.column(_all(c, c.p.ink), .1, .9),
  (c) => [
    c.shape(ShapeKind.rectangle, .5, .5, .9, 0x00000000, aspect: (1 - .1 / c.ratio) * c.ratio / .9, stroke: c.p.accent),
    ...c.column(_all(c, c.p.ink), .12, .88),
  ],
  (c) => [
    c.shape(ShapeKind.circle, .95, 0, .7, c.p.accent, opacity: .9),
    c.shape(ShapeKind.circle, .05, 1, .55, c.p.accent, opacity: .35),
    ...c.column(_all(c, c.p.ink), .15, .85),
  ],
  (c) => [
    c.band(.86, .28, c.p.accent),
    ...c.column([c.kicker(c.p.ink), c.headline(c.p.ink)], .06, .68),
    ...c.column([c.sub(c.p.onAccent), c.cta(c.p.onAccent, null)], .75, .97, gap: .015),
  ],
  (c) => [
    c.band(.1, .2, c.p.accent),
    ...c.column([c.kicker(c.p.onAccent)], .02, .18),
    ...c.column([c.headline(c.p.ink), c.sub(c.p.ink), c.cta(c.p.onAccent, c.p.accent)], .25, .95),
  ],
  (c) => [
    c.shape(ShapeKind.rectangle, .5, .98, 2, c.p.accent, aspect: .12, rotation: -.2, opacity: .85),
    c.shape(ShapeKind.rectangle, .5, .02, 2, c.p.accent, aspect: .08, rotation: -.2, opacity: .5),
    ...c.column([c.kicker(c.p.ink), c.headline(c.p.ink), c.sub(c.p.ink)], .16, .8),
  ],
  (c) => [
    c.band(.34, .68, c.p.accent),
    ...c.column([c.kicker(c.p.onAccent), c.headline(c.p.onAccent)], .05, .63),
    ...c.column([c.sub(c.p.ink), c.cta(c.p.onAccent, c.p.accent)], .71, .97, gap: .015),
  ],
  (c) => [
    c.shape(ShapeKind.rounded, .5, .5, .84, c.p.accent, aspect: .76 * c.ratio / .84),
    ...c.column(
      [c.kicker(c.p.onAccent), c.headline(c.p.onAccent, maxWidth: .7), c.sub(c.p.onAccent), c.cta(c.p.onAccent, null)],
      .17,
      .83,
    ),
  ],
  (c) => [
    for (var i = 0; i < 5; i++)
      for (var j = 0; j < 3; j++) ...[
        c.shape(ShapeKind.circle, .06 + i * .07, .05 + j * .05 / c.ratio, .025, c.p.accent),
        c.shape(ShapeKind.circle, .94 - i * .07, .95 - j * .05 / c.ratio, .025, c.p.accent),
      ],
    ...c.column(_all(c, c.p.ink), .05 + .15 / c.ratio, .95 - .15 / c.ratio),
  ],
  (c) {
    final star = c.ratio < 1 ? .2 : .3;
    return [
      c.shape(ShapeKind.star, 1 - star * .55, star * .55 / c.ratio, star, c.p.accent, rotation: .25),
      ...c.column(_all(c, c.p.ink), .06 + star * 1.1 / c.ratio, .95),
    ];
  },
  (c) {
    final d = math.min(.9, .62 * c.ratio);
    final h = d / c.ratio;
    const center = .45;
    return [
      c.shape(ShapeKind.circle, .5, center, d, c.p.accent),
      ...c.column([c.kicker(c.p.ink)], .02, center - h / 2 - .01),
      ...c.column([c.headline(c.p.onAccent, maxWidth: d * .72)], center - h * .3, center + h * .3),
      ...c.column([c.sub(c.p.ink), c.cta(c.p.onAccent, c.p.accent)], center + h / 2 + .02, .98, gap: .015),
    ];
  },
  (c) => [
    c.shape(ShapeKind.triangle, .22, 1 - .14 / c.ratio, .9, c.p.accent, aspect: .32, opacity: .55),
    c.shape(ShapeKind.triangle, .78, 1 - .1 / c.ratio, .8, c.p.accent, aspect: .25),
    ...c.column([c.kicker(c.p.ink), c.headline(c.p.ink), c.sub(c.p.ink)], .06, 1 - .3 / c.ratio),
  ],
  (c) {
    final size = math.min(.22, .2 * c.ratio);
    final h = size / c.ratio;
    return [
      c.shape(ShapeKind.hexagon, .5, .04 + h / 2, size, c.p.accent),
      ...c.column(_all(c, c.p.ink), .07 + h, .96),
    ];
  },
  (c) {
    final items = c.column([c.kicker(c.p.ink), c.headline(c.p.ink), c.sub(c.p.ink)], .1, .9, gap: .07);
    final headline = items[1];
    final half = templateTextHeight(headline, c.ratio) / 2;
    return [
      c.shape(ShapeKind.line, .5, headline.cy - half - .035, .4, c.p.accent)..strokeWidth = .006,
      c.shape(ShapeKind.line, .5, headline.cy + half + .035, .4, c.p.accent)..strokeWidth = .006,
      ...items,
    ];
  },
];

List<DesignTemplate> _generate() {
  final out = <DesignTemplate>[];
  var topicIndex = 0;
  _topics.forEach((topic, copies) {
    for (var i = 0; i < _layouts.length; i++) {
      final palette = templatePalettes[(topicIndex * 7 + i * 3) % templatePalettes.length];
      final fonts = _fontPairs[(topicIndex * 3 + i) % _fontPairs.length];
      final format = _formats[(topicIndex + i) % _formats.length];
      final copy = copies[i % copies.length];
      final layout = _layouts[i];
      final name = '$topic ${i + 1}';
      out.add(
        DesignTemplate(name, topic, () {
          final ctx = _Ctx(palette, copy, fonts.$1, fonts.$2, format.$2, format.$3);
          return CanvasDocument(
            name: name,
            pixelWidth: format.$2,
            pixelHeight: format.$3,
            background: CanvasBackground(palette.bg, color2: palette.bg2, angle: 60),
            layers: layout(ctx),
          );
        }, format: format.$1),
      );
    }
    topicIndex++;
  });
  return out;
}

/// Every template: the hand-made ones first, then the generated library.
final List<DesignTemplate> allTemplates = [...featuredTemplates, ..._generate()];

List<String> get templateTopics {
  final seen = <String>{};
  return [for (final t in allTemplates) if (seen.add(t.category)) t.category];
}

/// Matches name, topic or format, such as "story" or "wedding".
List<DesignTemplate> searchTemplates(String query, {String? topic}) {
  final q = query.trim().toLowerCase();
  return [
    for (final t in allTemplates)
      if ((topic == null || t.category == topic) &&
          (q.isEmpty || t.name.toLowerCase().contains(q) || t.category.toLowerCase().contains(q) || t.format.toLowerCase().contains(q)))
        t,
  ];
}
