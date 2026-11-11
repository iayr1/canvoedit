import 'document.dart';
import 'layer.dart';

/// Starter designs. All artwork is original and drawn in code, so templates need
/// no licensed assets and stay fully editable.
class DesignTemplate {
  const DesignTemplate(this.name, this.category, this.build, {this.format = ''});
  final String name;

  /// The topic it's filed under, such as Sale or Wedding.
  final String category;
  final CanvasDocument Function() build;

  /// The canvas shape, such as Story or Post, used in search.
  final String format;
}

CanvasLayer _text(
  String text,
  double y, {
  String font = 'Poppins',
  double size = .08,
  int color = 0xFFFFFFFF,
  bool bold = false,
  double x = .5,
  int? bg,
  double spacing = 0,
}) => CanvasLayer.text(text, font: font, size: size, color: color)
  ..cy = y
  ..cx = x
  ..bold = bold
  ..bgColor = bg
  ..letterSpacing = spacing;

CanvasLayer _shape(ShapeKind kind, double x, double y, double width, int fill, {double aspect = 1, double opacity = 1, double rotation = 0}) =>
    CanvasLayer.shape(kind, fill: fill, width: width, aspect: aspect)
      ..cx = x
      ..cy = y
      ..opacity = opacity
      ..rotation = rotation;

final List<DesignTemplate> featuredTemplates = [
  DesignTemplate(
    'Flash Sale',
    'Sale',
    () => CanvasDocument(
      name: 'Flash Sale',
      pixelWidth: 1080,
      pixelHeight: 1920,
      background: CanvasBackground(0xFFFF5C39, color2: 0xFF7C1D6F, angle: 60),
      layers: [
        _shape(ShapeKind.circle, .85, .12, .7, 0x33FFFFFF),
        _shape(ShapeKind.circle, .1, .9, .8, 0x22FFFFFF),
        _text('FLASH', .3, font: 'Anton', size: .28),
        _text('SALE', .49, font: 'Anton', size: .28, color: 0xFFFFE066),
        _text('Up to 50% off', .62, size: .07, bold: true),
        _text('Shop now', .78, size: .05, bold: true, color: 0xFF7C1D6F, bg: 0xFFFFFFFF),
      ],
    ),
  ),
  DesignTemplate(
    'Daily Quote',
    'Quote',
    () => CanvasDocument(
      name: 'Daily Quote',
      pixelWidth: 1080,
      pixelHeight: 1080,
      background: CanvasBackground(0xFFF7F1E3),
      layers: [
        _text('“', .2, font: 'Playfair Display', size: .3, color: 0xFFC8553D),
        _text('Make it simple,\nbut significant.', .5, font: 'Playfair Display', size: .085, color: 0xFF22223B),
        _shape(ShapeKind.rectangle, .5, .7, .12, 0xFFC8553D, aspect: .04),
        _text('your name', .77, size: .035, color: 0xFF4A4E69, spacing: .006),
      ],
    ),
  ),
  DesignTemplate(
    'Event Poster',
    'Event',
    () => CanvasDocument(
      name: 'Event Poster',
      pixelWidth: 2480,
      pixelHeight: 3508,
      background: CanvasBackground(0xFF10121A),
      layers: [
        _shape(ShapeKind.circle, .5, .36, .78, 0xFF7C5CFF),
        _shape(ShapeKind.circle, .62, .3, .46, 0xFFFF5C39, opacity: .92),
        _text('NIGHT\nMARKET', .68, font: 'Bebas Neue', size: .2),
        _text('SAT 14 NOV  /  7 PM  /  CITY HALL', .88, size: .032, bold: true, color: 0xFFFFE066),
      ],
    ),
  ),
  DesignTemplate(
    'Video Thumbnail',
    'Education',
    () => CanvasDocument(
      name: 'Video Thumbnail',
      pixelWidth: 1280,
      pixelHeight: 720,
      background: CanvasBackground(0xFF0F172A, color2: 0xFF1D4ED8, angle: 20),
      layers: [
        _shape(ShapeKind.star, .84, .3, .3, 0xFFFACC15, rotation: .2),
        _text('5 EDITING', .355, x: .4, font: 'Anton', size: .13),
        _text('TRICKS', .645, x: .36, font: 'Anton', size: .13, color: 0xFFFACC15),
        _text('in 60 seconds', .84, x: .28, size: .04, bold: true, color: 0xFF0F172A, bg: 0xFFFFFFFF),
      ],
    ),
  ),
  DesignTemplate(
    'Birthday',
    'Birthday',
    () => CanvasDocument(
      name: 'Birthday',
      pixelWidth: 1080,
      pixelHeight: 1350,
      background: CanvasBackground(0xFFFFD6E0, color2: 0xFFC1E1FF, angle: 110),
      layers: [
        CanvasLayer.sticker('\u{1F382}')
          ..cy = .25
          ..fontSize = .24,
        _text('Happy\nBirthday!', .52, font: 'Pacifico', size: .13, color: 0xFF3D2C8D),
        _text('wishing you the best year yet', .76, size: .04, color: 0xFF3D2C8D),
        CanvasLayer.sticker('\u{1F389}')
          ..cx = .16
          ..cy = .9
          ..fontSize = .12,
        CanvasLayer.sticker('\u{1F388}')
          ..cx = .84
          ..cy = .9
          ..fontSize = .12,
      ],
    ),
  ),
  DesignTemplate(
    'Podcast Cover',
    'Podcast',
    () => CanvasDocument(
      name: 'Podcast Cover',
      pixelWidth: 1000,
      pixelHeight: 1000,
      background: CanvasBackground(0xFF14342B),
      layers: [
        _shape(ShapeKind.hexagon, .5, .36, .5, 0xFFE9C46A),
        CanvasLayer.sticker('\u{1F399}\u{FE0F}')
          ..cy = .36
          ..fontSize = .2,
        _text('THE LONG TALK', .72, font: 'Oswald', size: .1, bold: true, color: 0xFFE9C46A),
        _text('weekly conversations', .84, size: .04, color: 0xFFF1FAEE),
      ],
    ),
  ),
  DesignTemplate(
    'Product Launch',
    'Business',
    () => CanvasDocument(
      name: 'Product Launch',
      pixelWidth: 1080,
      pixelHeight: 1920,
      background: CanvasBackground(0xFFFFFFFF),
      layers: [
        _shape(ShapeKind.rounded, .5, .42, .84, 0xFF111827, aspect: 1.1),
        _text('NEW', .1, font: 'Space Grotesk', size: .05, bold: true, color: 0xFF111827, spacing: .02),
        _text('Your product\nhere', .42, font: 'Space Grotesk', size: .1, bold: true),
        _text('Available now', .76, size: .06, color: 0xFF111827),
        _text('Learn more', .85, size: .045, bold: true, bg: 0xFFFF5C39),
      ],
    ),
  ),
  DesignTemplate(
    'Travel Story',
    'Travel',
    () => CanvasDocument(
      name: 'Travel Story',
      pixelWidth: 1080,
      pixelHeight: 1920,
      background: CanvasBackground(0xFF0EA5E9, color2: 0xFFFDE68A, angle: 90),
      layers: [
        _shape(ShapeKind.circle, .75, .22, .3, 0xFFFFFBEB),
        _shape(ShapeKind.triangle, .3, .74, 1.1, 0xFF0F766E, aspect: .7),
        _shape(ShapeKind.triangle, .78, .78, .9, 0xFF115E59, aspect: .62),
        _text('Wander', .4, font: 'Dancing Script', size: .2),
        _text('MORE', .5, font: 'Oswald', size: .09, bold: true, spacing: .03),
      ],
    ),
  ),
  DesignTemplate(
    'Business Card',
    'Business',
    () => CanvasDocument(
      name: 'Business Card',
      pixelWidth: 1050,
      pixelHeight: 600,
      background: CanvasBackground(0xFF1F2937),
      layers: [
        _shape(ShapeKind.rectangle, .03, .5, .06, 0xFFFF5C39, aspect: 10),
        _text('Your Name', .36, x: .38, size: .075, bold: true),
        _text('Job title', .52, x: .26, size: .035, color: 0xFFD1D5DB),
        _text('hello@example.com', .72, x: .32, size: .03, color: 0xFFFF9B85),
      ],
    ),
  ),
  DesignTemplate(
    'Minimal Announcement',
    'Announcement',
    () => CanvasDocument(
      name: 'Announcement',
      pixelWidth: 1080,
      pixelHeight: 1350,
      background: CanvasBackground(0xFF111111),
      layers: [
        _shape(ShapeKind.line, .5, .3, .5, 0xFFFFFFFF),
        _text('BIG\nNEWS', .5, font: 'Bebas Neue', size: .24),
        _shape(ShapeKind.line, .5, .7, .5, 0xFFFFFFFF),
        _text('details coming soon', .78, size: .035, color: 0xFFBBBBBB),
      ],
    ),
  ),
];
