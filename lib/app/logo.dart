import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The Canvo Edit mark: a soft play shape with a spark, on the brand gradient.
/// The same painter draws the in-app logo, the launcher icons and the splash.
class LogoPainter extends CustomPainter {
  const LogoPainter({this.tile = true, this.round = false, this.glyphScale = .56});

  /// Paints the gradient tile behind the glyph. Off for adaptive-icon foregrounds.
  final bool tile;

  /// A circle instead of the rounded square.
  final bool round;

  /// Size of the glyph relative to the canvas.
  final double glyphScale;

  static const colors = [Color(0xFFFF8A3D), AppColors.pink, Color(0xFF8B4DFF), Color(0xFF5B3CF5)];

  /// Paints only the gradient, edge to edge, for adaptive-icon backgrounds.
  static void paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = _gradient(rect));
    _sheen(canvas, rect);
  }

  static ui.Shader _gradient(Rect rect) => ui.Gradient.linear(rect.topLeft, rect.bottomRight, colors, const [0, .38, .72, 1]);

  static void _sheen(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(rect.topLeft + Offset(rect.width * .22, rect.height * .14), rect.shortestSide * .75, [
          Colors.white.withValues(alpha: .32),
          Colors.white.withValues(alpha: 0),
        ]),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final s = size.shortestSide;
    if (tile) {
      final shape = round ? (Path()..addOval(rect)) : (Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * .26))));
      canvas.save();
      canvas.clipPath(shape);
      paintBackground(canvas, size);
      canvas.restore();
    }
    paintGlyph(canvas, size.center(Offset.zero), s * glyphScale);
  }

  /// The white play-and-spark glyph centred on [center], [extent] wide.
  static void paintGlyph(Canvas canvas, Offset center, double extent) {
    final e = extent;
    // A play triangle with generously rounded corners, nudged right so it looks centred.
    final c = center + Offset(-e * .02, e * .06);
    final h = e * .92, w = h * .92;
    final a = c + Offset(-w * .45, -h / 2), b = c + Offset(w * .55, 0), d = c + Offset(-w * .45, h / 2);
    final r = e * .14;
    final play = _roundedTriangle(a, b, d, r);
    canvas.drawPath(
      play.shift(Offset(0, e * .035)),
      Paint()
        ..color = const Color(0x33300A50)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, e * .04),
    );
    canvas.drawPath(play, Paint()..color = Colors.white);
    // A cut in the triangle, like a film frame being edited.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w * .05, c.dy - h * .16)
        ..lineTo(c.dx + w * .16, c.dy)
        ..lineTo(c.dx - w * .05, c.dy + h * .16)
        ..close(),
      Paint()..shader = _gradient(Rect.fromCenter(center: c, width: e * 1.6, height: e * 1.6)),
    );
    // The spark, top right.
    _spark(canvas, center + Offset(e * .44, -e * .42), e * .14);
    _spark(canvas, center + Offset(e * .62, -e * .2), e * .06);
  }

  static void _spark(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final k = i.isEven ? r : r * .3;
      final p = c + Offset(math.cos(angle) * k, math.sin(angle) * k);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = Colors.white);
  }

  static Path _roundedTriangle(Offset a, Offset b, Offset c, double r) {
    final pts = [a, b, c];
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final p = pts[i], prev = pts[(i + 2) % 3], next = pts[(i + 1) % 3];
      final inDir = (p - prev) / (p - prev).distance, outDir = (next - p) / (next - p).distance;
      final start = p - inDir * r, end = p + outDir * r;
      i == 0 ? path.moveTo(start.dx, start.dy) : path.lineTo(start.dx, start.dy);
      path.quadraticBezierTo(p.dx, p.dy, end.dx, end.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant LogoPainter old) => old.tile != tile || old.round != round || old.glyphScale != glyphScale;
}

/// The logo as a widget.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const LogoPainter());
}
