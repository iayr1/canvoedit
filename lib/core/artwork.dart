import 'dart:math' as math;
import 'dart:ui';

/// Original scenes painted in code. They give the app real pictures to show,
/// for sample photos, filter previews and the home screen, without bundling or
/// licensing any photographs.
class ArtScene {
  const ArtScene(this.id, this.name, this.paint);
  final String id;
  final String name;
  final void Function(Canvas, Size) paint;

  /// Full-size image path, understood by the image bank.
  String get path => '$artPrefix$id';

  /// Small version for previews.
  String get thumbPath => '$artThumbPrefix$id';
}

const artPrefix = 'art://';
const artThumbPrefix = 'art-thumb://';

/// Projects saved by version 1.0.0 refer to the first sample by this path.
const legacySamplePath = 'sample://photo';

const artScenes = <ArtScene>[
  ArtScene('sunset-coast', 'Sunset Coast', _sunsetCoast),
  ArtScene('alpine-lake', 'Alpine Lake', _alpineLake),
  ArtScene('neon-city', 'Neon City', _neonCity),
  ArtScene('desert-dunes', 'Desert Dunes', _desertDunes),
  ArtScene('aurora-night', 'Aurora Night', _auroraNight),
  ArtScene('spring-blossom', 'Spring Blossom', _springBlossom),
];

/// True for the painted sample pictures, which templates use as stand-ins.
bool isArtworkPath(String path) => path == legacySamplePath || path.startsWith(artPrefix) || path.startsWith(artThumbPrefix);

/// The scene and pixel size for an artwork path, or null for ordinary files.
({ArtScene scene, int width, int height})? artworkFor(String path) {
  ArtScene? find(String id) {
    for (final s in artScenes) {
      if (s.id == id) return s;
    }
    return null;
  }

  if (path == legacySamplePath) return (scene: artScenes.first, width: 1080, height: 1350);
  if (path.startsWith(artThumbPrefix)) {
    final s = find(path.substring(artThumbPrefix.length));
    return s == null ? null : (scene: s, width: 360, height: 450);
  }
  if (path.startsWith(artPrefix)) {
    final s = find(path.substring(artPrefix.length));
    return s == null ? null : (scene: s, width: 1080, height: 1350);
  }
  return null;
}

Future<Image> renderArtwork(ArtScene scene, int width, int height) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());
  canvas.clipRect(Offset.zero & size);
  scene.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

// ---------------------------------------------------------------------------

Paint _vertical(Size s, double from, double to, List<Color> colors, [List<double>? stops]) =>
    Paint()..shader = Gradient.linear(Offset(0, s.height * from), Offset(0, s.height * to), colors, stops);

Paint _glow(Offset center, double radius, Color color) => Paint()..shader = Gradient.radial(center, radius, [color, color.withValues(alpha: 0)]);

/// A jagged ridge line across the canvas, closed down to [floor].
Path _ridge(Size s, double baseY, double amp, int seed, {int steps = 10, double? floor}) {
  final r = math.Random(seed);
  final path = Path()..moveTo(0, s.height * (baseY - amp * r.nextDouble()));
  for (var i = 1; i <= steps; i++) {
    final peak = i.isOdd ? .35 + r.nextDouble() * .65 : r.nextDouble() * .45;
    path.lineTo(s.width * i / steps, s.height * (baseY - amp * peak));
  }
  final bottom = s.height * (floor ?? 1);
  return path
    ..lineTo(s.width, bottom)
    ..lineTo(0, bottom)
    ..close();
}

/// A smooth rolling hill line, closed to the bottom of the canvas.
Path _hill(Size s, double y, double amp, double phase, {double waves = 1.3}) {
  final path = Path()..moveTo(0, s.height);
  const n = 48;
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    path.lineTo(s.width * t, s.height * (y + amp * math.sin(phase + t * waves * math.pi * 2)));
  }
  return path
    ..lineTo(s.width, s.height)
    ..close();
}

void _pine(Canvas c, Offset base, double h, Color color) {
  final paint = Paint()..color = color;
  for (var i = 0; i < 4; i++) {
    final w = h * (.42 - i * .08);
    final top = base.dy - h * (.38 + i * .2);
    final bottom = base.dy - h * (i * .2);
    c.drawPath(
      Path()
        ..moveTo(base.dx, top)
        ..lineTo(base.dx + w / 2, bottom)
        ..lineTo(base.dx - w / 2, bottom)
        ..close(),
      paint,
    );
  }
  c.drawRect(Rect.fromLTWH(base.dx - h * .02, base.dy - h * .02, h * .04, h * .06), paint);
}

void _stars(Canvas c, Size s, int count, int seed, double maxY) {
  final r = math.Random(seed);
  for (var i = 0; i < count; i++) {
    final big = r.nextDouble() > .92;
    c.drawCircle(
      Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * maxY),
      s.width * (big ? .0032 : .0016),
      Paint()..color = Color.fromRGBO(255, 255, 255, .35 + r.nextDouble() * .65),
    );
  }
}

void _sunsetCoast(Canvas c, Size s) {
  final w = s.width, h = s.height;
  const horizon = .62;
  c.drawRect(
    Offset.zero & s,
    _vertical(s, 0, horizon, const [Color(0xFF1B1F4B), Color(0xFF6A2C70), Color(0xFFE8505B), Color(0xFFF9A65A)], const [0, .42, .8, 1]),
  );
  final sun = Offset(w * .63, h * .565);
  c.drawCircle(sun, w * .5, _glow(sun, w * .5, const Color(0xBFFFE29A)));

  final cloud = Paint()
    ..color = const Color(0x66FFB199)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .02);
  for (final (x, y, cw) in const [(.18, .2, .34), (.55, .14, .26), (.8, .27, .3), (.3, .34, .22), (.72, .4, .2)]) {
    c.drawOval(Rect.fromCenter(center: Offset(w * x, h * y), width: w * cw, height: h * .018), cloud);
  }
  c.drawCircle(sun, w * .085, Paint()..color = const Color(0xFFFFF3C4));

  c.drawPath(_ridge(s, horizon, .075, 11, steps: 7, floor: horizon), Paint()..color = const Color(0xFF4A2C63));

  final sea = Rect.fromLTRB(0, h * horizon, w, h);
  c.drawRect(sea, _vertical(s, horizon, 1, const [Color(0xFFEF7F6B), Color(0xFF7B3B79), Color(0xFF1F1B45)], const [0, .35, 1]));
  final r = math.Random(4);
  for (var i = 0; i < 26; i++) {
    final t = i / 26;
    final y = h * (horizon + .008 + t * .3);
    final half = w * (.1 - t * .05 + r.nextDouble() * .05);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(sun.dx + (r.nextDouble() - .5) * w * .04, y), width: half * 2, height: h * .004),
        Radius.circular(h * .002),
      ),
      Paint()..color = Color.fromRGBO(255, 226, 154, .75 - t * .55),
    );
  }
  c.drawPath(_hill(s, .93, .025, 1.2, waves: .8), Paint()..color = const Color(0xFF14102B));
}

void _alpineLake(Canvas c, Size s) {
  final w = s.width, h = s.height;
  const shore = .58;
  c.drawRect(Offset.zero & s, _vertical(s, 0, shore, const [Color(0xFF2F6FD0), Color(0xFF8CC8F2), Color(0xFFFFE8CF)], const [0, .6, 1]));
  final sun = Offset(w * .27, h * .2);
  c.drawCircle(sun, w * .4, _glow(sun, w * .4, const Color(0x99FFFFFF)));
  c.drawCircle(sun, w * .05, Paint()..color = const Color(0xFFFFFDF2));

  void ridges(double alpha) {
    c.drawPath(_ridge(s, shore, .34, 21, floor: shore), Paint()..color = const Color(0xFF86A6D0).withValues(alpha: alpha));
    c.drawPath(_ridge(s, shore, .24, 5, steps: 8, floor: shore), Paint()..color = const Color(0xFF50739F).withValues(alpha: alpha));
    c.drawPath(_ridge(s, shore, .13, 9, steps: 12, floor: shore), Paint()..color = const Color(0xFF274766).withValues(alpha: alpha));
  }

  ridges(1);
  final lake = Rect.fromLTRB(0, h * shore, w, h);
  c.drawRect(lake, _vertical(s, shore, 1, const [Color(0xFFA9D8F5), Color(0xFF3A74A8), Color(0xFF173A5E)], const [0, .45, 1]));
  c.save();
  c.clipRect(lake);
  c.translate(0, h * shore * 2);
  c.scale(1, -1);
  ridges(.38);
  c.restore();
  final ripple = Paint()
    ..color = const Color(0x33FFFFFF)
    ..strokeWidth = h * .0018;
  final r = math.Random(8);
  for (var i = 0; i < 34; i++) {
    final y = h * (shore + .02 + r.nextDouble() * .3);
    final x = r.nextDouble() * w;
    c.drawLine(Offset(x, y), Offset(x + w * (.04 + r.nextDouble() * .1), y), ripple);
  }
  c.drawPath(_hill(s, .95, .02, .4, waves: .7), Paint()..color = const Color(0xFF0E2A2F));
  for (final (x, y, th) in const [(.06, .93, .3), (.15, .95, .22), (.24, .965, .15), (.9, .93, .34), (.8, .955, .2), (.97, .96, .26)]) {
    _pine(c, Offset(w * x, h * y), h * th, const Color(0xFF0E2A2F));
  }
}

void _neonCity(Canvas c, Size s) {
  final w = s.width, h = s.height;
  const ground = .74;
  c.drawRect(
    Offset.zero & s,
    _vertical(s, 0, ground, const [Color(0xFF0B0221), Color(0xFF2A0A4A), Color(0xFFB5179E), Color(0xFFFF7B6B)], const [0, .4, .82, 1]),
  );
  _stars(c, s, 90, 3, .4);

  final disc = Offset(w * .5, h * .5);
  final radius = w * .27;
  c.drawCircle(disc, radius * 1.9, _glow(disc, radius * 1.9, const Color(0x80FF6B9D)));
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: disc, radius: radius)));
  c.drawRect(
    Rect.fromCircle(center: disc, radius: radius),
    Paint()..shader = Gradient.linear(disc - Offset(0, radius), disc + Offset(0, radius), const [Color(0xFFFFE66D), Color(0xFFFF5D8F)]),
  );
  for (var i = 0; i < 6; i++) {
    final y = disc.dy + radius * (.12 + i * .15);
    c.drawRect(Rect.fromLTWH(0, y, w, radius * (.025 + i * .014)), Paint()..color = const Color(0xFF7A1785));
  }
  c.restore();

  void skyline(int seed, double minH, double maxH, Color wall, double lit) {
    final r = math.Random(seed);
    var x = -w * .02;
    while (x < w) {
      final bw = w * (.07 + r.nextDouble() * .09);
      final bh = h * (minH + r.nextDouble() * (maxH - minH));
      final rect = Rect.fromLTWH(x, h * ground - bh, bw, bh);
      c.drawRect(rect, Paint()..color = wall);
      if (r.nextDouble() > .6) {
        c.drawRect(Rect.fromLTWH(x + bw * .45, rect.top - h * .03, bw * .06, h * .03), Paint()..color = wall);
      }
      final cols = (bw / (w * .022)).floor(), rows = (bh / (h * .02)).floor();
      for (var i = 0; i < cols; i++) {
        for (var j = 0; j < rows; j++) {
          if (r.nextDouble() > lit) continue;
          const lights = [Color(0xFFFFD166), Color(0xFF4CC9F0), Color(0xFFF72585), Color(0xFFFFF1C1)];
          c.drawRect(
            Rect.fromLTWH(x + bw * .12 + i * w * .022, rect.top + h * .012 + j * h * .02, w * .011, h * .009),
            Paint()..color = lights[r.nextInt(lights.length)].withValues(alpha: .55 + r.nextDouble() * .45),
          );
        }
      }
      x += bw + w * .006;
    }
  }

  skyline(12, .1, .26, const Color(0xFF3A1766), .18);
  skyline(31, .05, .17, const Color(0xFF12072B), .32);

  final road = Rect.fromLTRB(0, h * ground, w, h);
  c.drawRect(road, _vertical(s, ground, 1, const [Color(0xFF3B0F5C), Color(0xFF0B0221)]));
  final grid = Paint()
    ..color = const Color(0x8CF72585)
    ..strokeWidth = h * .0018;
  for (var i = 0; i < 9; i++) {
    final t = math.pow(i / 9, 1.8).toDouble();
    final y = h * (ground + .012 + t * (1 - ground));
    c.drawLine(Offset(0, y), Offset(w, y), grid);
  }
  for (var i = -8; i <= 8; i++) {
    c.drawLine(Offset(w * (.5 + i * .035), h * ground), Offset(w * (.5 + i * .22), h), grid);
  }
}

void _desertDunes(Canvas c, Size s) {
  final w = s.width, h = s.height;
  c.drawRect(Offset.zero & s, _vertical(s, 0, .6, const [Color(0xFF6FA8DC), Color(0xFFFCE0A8), Color(0xFFF9B16E)], const [0, .62, 1]));
  final sun = Offset(w * .74, h * .24);
  c.drawCircle(sun, w * .42, _glow(sun, w * .42, const Color(0xB3FFF6D6)));
  c.drawCircle(sun, w * .075, Paint()..color = const Color(0xFFFFFBEA));

  final bird = Paint()
    ..color = const Color(0xFF5A3A2E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * .004
    ..strokeCap = StrokeCap.round;
  for (final (x, y, k) in const [(.2, .2, 1.0), (.27, .17, .7), (.33, .22, .8)]) {
    final p = Offset(w * x, h * y), d = w * .022 * k;
    c.drawPath(
      Path()
        ..moveTo(p.dx - d, p.dy - d * .5)
        ..quadraticBezierTo(p.dx - d * .4, p.dy - d * .7, p.dx, p.dy)
        ..quadraticBezierTo(p.dx + d * .4, p.dy - d * .7, p.dx + d, p.dy - d * .5),
      bird,
    );
  }

  const dunes = [
    (.52, .03, .6, 0xFFF2B872, 0xFFD98B4E, 1.1),
    (.62, .045, 2.4, 0xFFE9A15B, 0xFFBF6E3D, .9),
    (.73, .05, 4.1, 0xFFD98248, 0xFF9C4E2F, 1.2),
    (.86, .04, 5.6, 0xFFB65F38, 0xFF6B3223, .8),
  ];
  for (final (y, amp, phase, light, dark, waves) in dunes) {
    c.drawPath(
      _hill(s, y, amp, phase, waves: waves),
      Paint()..shader = Gradient.linear(Offset(w * .15, h * (y - amp)), Offset(w * .85, h * (y + .22)), [Color(light), Color(dark)]),
    );
  }
}

void _auroraNight(Canvas c, Size s) {
  final w = s.width, h = s.height;
  c.drawRect(Offset.zero & s, _vertical(s, 0, 1, const [Color(0xFF020B1F), Color(0xFF0B2545), Color(0xFF134E5E)], const [0, .55, 1]));
  _stars(c, s, 170, 6, .62);

  void ribbon(double y, double amp, double phase, List<Color> colors, double thickness) {
    final top = <Offset>[], bottom = <Offset>[];
    const n = 40;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final cy = h * (y + amp * math.sin(phase + t * math.pi * 2.2) + .05 * math.sin(phase * 2 + t * 9));
      top.add(Offset(w * t, cy - h * thickness));
      bottom.add(Offset(w * t, cy + h * thickness * .35));
    }
    final path = Path()..moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in bottom.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
      path..close(),
      Paint()
        ..shader = Gradient.linear(Offset(0, h * (y - thickness - amp)), Offset(0, h * (y + amp + thickness * .4)), colors, const [0, .55, 1])
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .035),
    );
  }

  ribbon(.3, .07, .4, const [Color(0x007BFFB0), Color(0xCC4DFFB4), Color(0x0019C6C6)], .2);
  ribbon(.36, .05, 2.2, const [Color(0x008A5CFF), Color(0x998A5CFF), Color(0x0033E6C8)], .15);
  ribbon(.24, .06, 4.0, const [Color(0x0033E6C8), Color(0x8033E6C8), Color(0x007BFFB0)], .12);

  c.drawPath(_ridge(s, .74, .16, 17, steps: 9), Paint()..color = const Color(0xFF0A1B33));
  c.drawPath(_hill(s, .82, .02, 1.0, waves: .9), _vertical(s, .78, 1, const [Color(0xFF9FD9D2), Color(0xFF2A5F6E), Color(0xFF0C2233)], const [0, .25, 1]));
  for (final (x, y, th) in const [(.08, .86, .3), (.2, .9, .2), (.86, .87, .32), (.95, .92, .22), (.72, .9, .16)]) {
    _pine(c, Offset(w * x, h * y), h * th, const Color(0xFF06111F));
  }
}

void _springBlossom(Canvas c, Size s) {
  final w = s.width, h = s.height;
  c.drawRect(
    Offset.zero & s,
    Paint()..shader = Gradient.linear(Offset.zero, Offset(w, h), const [Color(0xFF8EC5FC), Color(0xFFFBC2EB), Color(0xFFFFD3A5)], const [0, .55, 1]),
  );
  final r = math.Random(14);
  for (var i = 0; i < 46; i++) {
    const tints = [Color(0xFFFFFFFF), Color(0xFFFFE3F1), Color(0xFFFFF6C2), Color(0xFFD8ECFF)];
    c.drawCircle(
      Offset(r.nextDouble() * w, r.nextDouble() * h),
      w * (.03 + r.nextDouble() * .09),
      Paint()
        ..color = tints[r.nextInt(tints.length)].withValues(alpha: .12 + r.nextDouble() * .28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .012),
    );
  }

  final bark = Paint()
    ..color = const Color(0xFF5B3A2E)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  void branch(List<Offset> pts, double width) {
    final path = Path()..moveTo(pts[0].dx * w, pts[0].dy * h);
    path.cubicTo(pts[1].dx * w, pts[1].dy * h, pts[2].dx * w, pts[2].dy * h, pts[3].dx * w, pts[3].dy * h);
    c.drawPath(path, bark..strokeWidth = w * width);
  }

  branch(const [Offset(-.02, .86), Offset(.25, .7), Offset(.45, .52), Offset(.98, .3)], .022);
  branch(const [Offset(.36, .62), Offset(.4, .45), Offset(.5, .3), Offset(.62, .16)], .012);
  branch(const [Offset(.58, .46), Offset(.66, .52), Offset(.76, .56), Offset(.9, .62)], .01);
  branch(const [Offset(.18, .75), Offset(.2, .62), Offset(.16, .5), Offset(.2, .4)], .009);

  void flower(Offset center, double size, double turn) {
    for (var i = 0; i < 5; i++) {
      final a = turn + i * math.pi * 2 / 5;
      final p = center + Offset(math.cos(a), math.sin(a)) * size * .55;
      c.drawCircle(p, size * .5, Paint()..shader = Gradient.radial(center, size * 1.1, const [Color(0xFFFFFFFF), Color(0xFFFF8FB8)], const [.15, 1]));
    }
    c.drawCircle(center, size * .22, Paint()..color = const Color(0xFFFFD166));
  }

  const spots = [
    (.3, .66, .05),
    (.44, .55, .042),
    (.6, .44, .055),
    (.75, .38, .04),
    (.9, .33, .048),
    (.43, .42, .04),
    (.52, .27, .045),
    (.61, .17, .036),
    (.7, .53, .04),
    (.84, .6, .046),
    (.19, .56, .038),
    (.2, .42, .042),
    (.12, .8, .045),
    (.5, .5, .03),
    (.35, .5, .028),
  ];
  for (var i = 0; i < spots.length; i++) {
    final (x, y, size) = spots[i];
    flower(Offset(w * x, h * y), w * size, i * .7);
  }
  for (var i = 0; i < 14; i++) {
    c.drawOval(
      Rect.fromCenter(center: Offset(r.nextDouble() * w, r.nextDouble() * h), width: w * .022, height: w * .013),
      Paint()..color = const Color(0xCCFFB3CF),
    );
  }
}
