import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/media.dart';
import 'document.dart';
import 'layer.dart';

const appFonts = <String>[
  'Poppins',
  'Inter',
  'Montserrat',
  'Oswald',
  'Bebas Neue',
  'Anton',
  'Playfair Display',
  'Lora',
  'Merriweather',
  'Dancing Script',
  'Pacifico',
  'Caveat',
  'Lobster',
  'Permanent Marker',
  'Space Grotesk',
  'Roboto Mono',
];

/// Paints documents and layers. The live canvas and every export use this code,
/// which is what keeps previews and exported files matching.
class SceneRenderer {
  /// Turned off in tests, which have no network access for font downloads.
  static bool useGoogleFonts = true;

  static TextStyle _textStyle(CanvasLayer l, double canvasWidth, {Paint? foreground, Color? color, List<Shadow>? shadows}) {
    final base = TextStyle(
      fontSize: l.fontSize * canvasWidth,
      color: foreground == null ? (color ?? Color(l.color)) : null,
      foreground: foreground,
      fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: l.italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: l.letterSpacing * canvasWidth,
      height: 1.15,
      shadows:
          shadows ??
          (l.shadow ? [Shadow(color: Colors.black54, blurRadius: l.fontSize * canvasWidth * .18, offset: Offset(0, l.fontSize * canvasWidth * .05))] : null),
    );
    if (l.kind == LayerKind.sticker) return base;
    // Without Google Fonts, use the family by name, for fonts loaded another way.
    if (!useGoogleFonts) return base.copyWith(fontFamily: l.fontFamily);
    return GoogleFonts.getFont(l.fontFamily, textStyle: base);
  }

  static TextPainter _textPainter(CanvasLayer l, Size canvas, {Paint? foreground, Color? color, List<Shadow>? shadows}) {
    return TextPainter(
      text: TextSpan(
        text: l.text.isEmpty ? ' ' : l.text,
        style: _textStyle(l, canvas.width, foreground: foreground, color: color, shadows: shadows),
      ),
      textAlign: const [TextAlign.left, TextAlign.center, TextAlign.right][l.align],
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: canvas.width * .96);
  }

  /// Unrotated on-canvas size of a layer.
  static Size layerSize(CanvasLayer l, Size canvas) {
    switch (l.kind) {
      case LayerKind.text:
      case LayerKind.sticker:
        final painter = _textPainter(l, canvas);
        final size = painter.size;
        painter.dispose();
        final pad = l.bgColor == null ? 0.0 : l.fontSize * canvas.width * .5;
        return Size(size.width + pad, size.height + pad);
      case LayerKind.shape:
        final w = l.width * canvas.width;
        return Size(w, w * l.aspect);
      case LayerKind.image:
        final w = l.width * canvas.width;
        return Size(w, w * (l.isFrame ? l.aspect : l.imageAspect));
      case LayerKind.stroke:
        return Size.zero;
    }
  }

  static void paintBackground(Canvas c, Size s, CanvasBackground bg) {
    final paint = Paint();
    if (bg.color2 == null) {
      paint.color = Color(bg.color);
    } else {
      final a = bg.angle * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a)) * (s.longestSide / 2);
      final center = s.center(Offset.zero);
      paint.shader = ui.Gradient.linear(center - dir, center + dir, [Color(bg.color), Color(bg.color2!)]);
    }
    c.drawRect(Offset.zero & s, paint);
  }

  static void paintLayers(Canvas c, Size s, Iterable<CanvasLayer> layers, {int? timeMs}) {
    for (final l in layers) {
      if (l.isVisibleAt(timeMs)) paintLayer(c, s, l);
    }
  }

  static void paintDocument(Canvas c, Size s, CanvasDocument doc) {
    c.save();
    c.clipRect(Offset.zero & s);
    paintBackground(c, s, doc.background);
    paintLayers(c, s, doc.layers);
    c.restore();
  }

  static void paintLayer(Canvas c, Size s, CanvasLayer l) {
    if (l.kind == LayerKind.stroke) {
      _withOpacity(c, s, l, () => _paintStroke(c, s, l));
      return;
    }
    final size = layerSize(l, s);
    c.save();
    c.translate(l.cx * s.width, l.cy * s.height);
    c.rotate(l.rotation);
    _withOpacity(c, s, l, () {
      switch (l.kind) {
        case LayerKind.text:
        case LayerKind.sticker:
          _paintText(c, s, l, size);
        case LayerKind.shape:
          _paintShape(c, s, l, size);
        case LayerKind.image:
          _paintImage(c, l, size);
        case LayerKind.stroke:
          break;
      }
    });
    c.restore();
  }

  static void _withOpacity(Canvas c, Size s, CanvasLayer l, VoidCallback draw) {
    if (l.opacity >= 1) {
      draw();
      return;
    }
    final d = s.longestSide * 2;
    c.saveLayer(Rect.fromCenter(center: Offset.zero, width: d * 2, height: d * 2), Paint()..color = Colors.white.withValues(alpha: l.opacity));
    draw();
    c.restore();
  }

  static void _paintText(Canvas c, Size canvas, CanvasLayer l, Size size) {
    final fs = l.fontSize * canvas.width;
    if (l.bgColor != null) {
      final r = Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height);
      final bg = Paint()..color = Color(l.bgColor!);
      switch (l.kind == LayerKind.text ? l.bgStyle : 0) {
        case 1:
          c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)), bg);
        case 2:
          c.drawRect(r, bg);
        case 3:
          final skew = r.height * .28;
          c.drawPath(
            Path()
              ..moveTo(r.left + skew, r.top)
              ..lineTo(r.right + skew * .4, r.top)
              ..lineTo(r.right - skew, r.bottom)
              ..lineTo(r.left - skew * .4, r.bottom)
              ..close(),
            bg,
          );
        default:
          c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(fs * .2)), bg);
      }
    }
    void draw({Paint? foreground, Color? color, List<Shadow>? shadows, Offset shift = Offset.zero}) {
      final painter = _textPainter(l, canvas, foreground: foreground, color: color, shadows: shadows);
      painter.paint(c, Offset(-painter.width / 2, -painter.height / 2) + shift);
      painter.dispose();
    }

    if (l.kind == LayerKind.sticker) {
      draw();
      return;
    }
    if (l.popColor != null) draw(color: Color(l.popColor!), shadows: const [], shift: Offset(fs * .07, fs * .07));
    if (l.glowColor != null) {
      final glow = Color(l.glowColor!);
      draw(
        color: glow,
        shadows: [
          Shadow(color: glow, blurRadius: fs * .45),
          Shadow(color: glow, blurRadius: fs * .18),
        ],
      );
    }
    if (l.strokeColor != null) {
      draw(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = l.strokeWidth * fs * 2
          ..color = Color(l.strokeColor!),
        shadows: l.popColor != null || l.glowColor != null ? const [] : null,
      );
    }
    final gradient = l.gradient;
    if (gradient != null && gradient.length >= 2) {
      final h = size.height / 2;
      draw(
        foreground: Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, -h),
            Offset(0, h),
            [for (final g in gradient) Color(g)],
            [for (var i = 0; i < gradient.length; i++) i / (gradient.length - 1)],
          ),
        shadows: l.strokeColor != null || l.popColor != null || l.glowColor != null ? const [] : null,
      );
    } else {
      draw(shadows: l.strokeColor != null || l.popColor != null || l.glowColor != null ? const [] : null);
    }
  }

  static void _paintShape(Canvas c, Size canvas, CanvasLayer l, Size size) {
    final path = shapePath(l.shape, size);
    final fill = Paint()..color = Color(l.color);
    if (l.shape == ShapeKind.line) {
      c.drawPath(
        path,
        fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, l.strokeWidth * canvas.width)
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    c.drawPath(path, fill);
    if (l.strokeColor != null) {
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Color(l.strokeColor!)
          ..strokeWidth = l.strokeWidth * canvas.width,
      );
    }
  }

  /// Path for a shape centred on the origin.
  static Path shapePath(ShapeKind kind, Size s) {
    final w = s.width, h = s.height;
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    switch (kind) {
      case ShapeKind.rectangle:
        return Path()..addRect(r);
      case ShapeKind.rounded:
        return Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(math.min(w, h) * .14)));
      case ShapeKind.circle:
        return Path()..addOval(r);
      case ShapeKind.triangle:
        return Path()
          ..moveTo(0, -h / 2)
          ..lineTo(w / 2, h / 2)
          ..lineTo(-w / 2, h / 2)
          ..close();
      case ShapeKind.line:
        return Path()
          ..moveTo(-w / 2, 0)
          ..lineTo(w / 2, 0);
      case ShapeKind.star:
        return _polygon(10, w, h, innerRatio: .45);
      case ShapeKind.hexagon:
        return _polygon(6, w, h);
      case ShapeKind.arch:
        return Path()
          ..moveTo(-w / 2, h / 2)
          ..lineTo(-w / 2, -h / 2 + w / 2)
          ..arcToPoint(Offset(w / 2, -h / 2 + w / 2), radius: Radius.circular(w / 2))
          ..lineTo(w / 2, h / 2)
          ..close();
      case ShapeKind.heart:
        return Path()
          ..moveTo(0, h * .5)
          ..cubicTo(-w * .75, -h * .02, -w * .38, -h * .62, 0, -h * .2)
          ..cubicTo(w * .38, -h * .62, w * .75, -h * .02, 0, h * .5)
          ..close();
    }
  }

  static Path _polygon(int points, double w, double h, {double innerRatio = 1}) {
    final path = Path();
    for (var i = 0; i < points; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / points;
      final k = i.isOdd ? innerRatio : 1.0;
      final p = Offset(math.cos(a) * w / 2 * k, math.sin(a) * h / 2 * k);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static void _paintImage(Canvas c, CanvasLayer l, Size size) {
    if (l.isFrame) {
      _paintFrame(c, l, size);
      return;
    }
    final rect = Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height);
    final image = l.path == null ? null : ImageBank.instance.peek(l.path!);
    if (image == null) {
      c.drawRect(rect, Paint()..color = const Color(0xFF2A2D36));
      if (l.path != null) ImageBank.instance.load(l.path!).ignore();
      return;
    }
    final w = image.width.toDouble(), h = image.height.toDouble();
    final src = Rect.fromLTRB(l.cropL * w, l.cropT * h, l.cropR * w, l.cropB * h);
    c.save();
    c.clipRect(rect);
    c.scale(l.flipH ? -1 : 1, l.flipV ? -1 : 1);
    c.rotate(l.quarterTurns * math.pi / 2);
    final dst = l.quarterTurns.isOdd ? Rect.fromCenter(center: Offset.zero, width: size.height, height: size.width) : rect;
    final paint = Paint()..filterQuality = FilterQuality.high;
    if (!l.grade.isNeutral) paint.colorFilter = ColorFilter.matrix(l.grade.matrix);
    c.drawImageRect(image, src, dst, paint);
    c.restore();
    paintVignette(c, rect, l.grade.vignette);
  }

  /// A frame crops its picture to cover its shape, centred, so any photo fits.
  static void _paintFrame(Canvas c, CanvasLayer l, Size size) {
    final rect = Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height);
    final outline = shapePath(l.shape == ShapeKind.line ? ShapeKind.rectangle : l.shape, size);
    final image = l.path == null ? null : ImageBank.instance.peek(l.path!);
    c.save();
    c.clipPath(outline);
    if (image == null) {
      if (l.path != null) ImageBank.instance.load(l.path!).ignore();
      _paintFramePlaceholder(c, rect);
      c.restore();
      return;
    }
    final w = image.width.toDouble(), h = image.height.toDouble();
    final frameRatio = rect.width / rect.height;
    final src = w / h > frameRatio
        ? Rect.fromCenter(center: Offset(w / 2, h / 2), width: h * frameRatio, height: h)
        : Rect.fromCenter(center: Offset(w / 2, h / 2), width: w, height: w / frameRatio);
    c.scale(l.flipH ? -1 : 1, l.flipV ? -1 : 1);
    final paint = Paint()..filterQuality = FilterQuality.high;
    if (!l.grade.isNeutral) paint.colorFilter = ColorFilter.matrix(l.grade.matrix);
    c.drawImageRect(image, src, rect, paint);
    c.restore();
    c.save();
    c.clipPath(outline);
    paintVignette(c, rect, l.grade.vignette);
    c.restore();
  }

  /// An empty frame: a soft panel with a picture icon.
  static void _paintFramePlaceholder(Canvas c, Rect rect) {
    c.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, const [Color(0xFFE9E6F5), Color(0xFFD6D0EC)]));
    final s = math.min(rect.width, rect.height) * .28;
    final box = Rect.fromCenter(center: rect.center, width: s * 1.3, height: s);
    final ink = Paint()..color = const Color(0xFF8E86B5);
    c.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(s * .14)),
      Paint()
        ..color = const Color(0xFF8E86B5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .08,
    );
    c.drawCircle(box.topLeft + Offset(box.width * .3, box.height * .32), s * .1, ink);
    c.drawPath(
      Path()
        ..moveTo(box.left + box.width * .14, box.bottom - box.height * .16)
        ..lineTo(box.left + box.width * .42, box.top + box.height * .5)
        ..lineTo(box.left + box.width * .6, box.top + box.height * .68)
        ..lineTo(box.left + box.width * .72, box.top + box.height * .56)
        ..lineTo(box.right - box.width * .14, box.bottom - box.height * .16)
        ..close(),
      ink,
    );
  }

  static void paintVignette(Canvas c, Rect rect, double amount) {
    if (amount <= 0) return;
    final radius = rect.size.longestSide * .72;
    c.drawRect(rect, Paint()..shader = ui.Gradient.radial(rect.center, radius, [Colors.transparent, Colors.black.withValues(alpha: amount * .85)], [.45, 1]));
  }

  static void _paintStroke(Canvas c, Size s, CanvasLayer l) {
    if (l.points.length < 2) return;
    final path = Path()..moveTo(l.points[0] * s.width, l.points[1] * s.height);
    for (var i = 2; i + 1 < l.points.length; i += 2) {
      path.lineTo(l.points[i] * s.width, l.points[i + 1] * s.height);
    }
    if (l.points.length == 2) path.lineTo(l.points[0] * s.width + .01, l.points[1] * s.height);
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = l.strokeWidth * s.width
        ..color = Color(l.color),
    );
  }

  /// Point-in-layer test, in canvas coordinates, allowing for rotation.
  static bool hitTest(CanvasLayer l, Offset p, Size canvas, {double slop = 8}) {
    if (l.kind == LayerKind.stroke) return false;
    final local = _toLocal(l, p, canvas);
    final size = layerSize(l, canvas);
    return Rect.fromCenter(center: Offset.zero, width: size.width + slop * 2, height: size.height + slop * 2).contains(local);
  }

  static Offset _toLocal(CanvasLayer l, Offset p, Size canvas) {
    final d = p - Offset(l.cx * canvas.width, l.cy * canvas.height);
    final cosA = math.cos(-l.rotation), sinA = math.sin(-l.rotation);
    return Offset(d.dx * cosA - d.dy * sinA, d.dx * sinA + d.dy * cosA);
  }

  /// Loads everything a set of layers needs, so an export is never missing an
  /// image or font that the live canvas would have painted in a moment later.
  static Future<void> prepare(Iterable<CanvasLayer> layers) async {
    for (final l in layers) {
      if (l.kind == LayerKind.image && l.path != null) await ImageBank.instance.load(l.path!);
      if (l.kind == LayerKind.text && useGoogleFonts) GoogleFonts.getFont(l.fontFamily);
    }
    if (useGoogleFonts) await GoogleFonts.pendingFonts();
  }

  static Future<ui.Image> rasterize(int width, int height, void Function(Canvas, Size) paint) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas, Size(width.toDouble(), height.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  /// Encodes a document as a PNG at its pixel size multiplied by [scale].
  static Future<Uint8List> exportPng(CanvasDocument doc, {double scale = 1}) async {
    await prepare(doc.layers);
    final w = (doc.pixelWidth * scale).round().clamp(1, 8192);
    final h = (doc.pixelHeight * scale).round().clamp(1, 8192);
    final image = await rasterize(w, h, (c, s) => paintDocument(c, s, doc));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
