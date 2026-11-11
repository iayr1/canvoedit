import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'effect_library.dart';
import 'transition_library.dart';

/// Draws a clip with an effect applied at [timeMs] into a clip of [durationMs].
class EffectView extends StatelessWidget {
  const EffectView({super.key, required this.effect, required this.timeMs, required this.durationMs, required this.child, this.fps = 30});

  final ClipEffect effect;
  final int timeMs;
  final int durationMs;
  final int fps;
  final Widget child;

  static const _red = <double>[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0];
  static const _cyan = <double>[0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final f = effectFrameAt(effect, timeMs, durationMs, fps: fps);
        var view = child;
        final t = effect.texture;
        if (t.rgbSplit > 0) {
          final px = t.rgbSplit * size.width / 1080;
          view = Stack(
            fit: StackFit.expand,
            children: [
              view,
              Transform.translate(
                offset: Offset(-px, 0),
                child: Opacity(
                  opacity: .4,
                  child: ColorFiltered(colorFilter: const ColorFilter.matrix(_red), child: child),
                ),
              ),
              Transform.translate(
                offset: Offset(px, 0),
                child: Opacity(
                  opacity: .4,
                  child: ColorFiltered(colorFilter: const ColorFilter.matrix(_cyan), child: child),
                ),
              ),
            ],
          );
        }
        if (t.blur > 0) {
          final sigma = t.blur * size.width / 1080;
          view = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
            child: view,
          );
        }
        if (t.pixel > 0 && size.width > 0) {
          final k = math.max(1.0, t.pixel * size.width / 1080);
          view = ImageFiltered(
            imageFilter: ui.ImageFilter.compose(
              outer: ui.ImageFilter.matrix(Matrix4.diagonal3Values(k, k, 1).storage, filterQuality: FilterQuality.none),
              inner: ui.ImageFilter.matrix(Matrix4.diagonal3Values(1 / k, 1 / k, 1).storage, filterQuality: FilterQuality.low),
            ),
            child: view,
          );
        }
        if (f.zoom != 1 || f.centerX != .5 || f.centerY != .5) {
          view = Transform.scale(
            scale: f.zoom,
            child: FractionalTranslation(translation: Offset(.5 - f.centerX, .5 - f.centerY), child: view),
          );
        }
        if (f.rotation != 0) view = Transform.rotate(angle: f.rotation, child: view);
        if (f.brightness != 0) {
          final b = f.brightness * 255;
          view = ColorFiltered(colorFilter: ColorFilter.matrix([1, 0, 0, 0, b, 0, 1, 0, 0, b, 0, 0, 1, 0, b, 0, 0, 0, 1, 0]), child: view);
        }
        final l = effect.light;
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              view,
              if (t.grain > 0) IgnorePointer(child: CustomPaint(painter: _GrainPainter(timeMs ~/ 40, t.grain))),
              if (f.overlay != null && f.overlayOpacity > 0) ColoredBox(color: Color(0xFF000000 | f.overlay!).withValues(alpha: f.overlayOpacity)),
              if (l.bars > 0) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: size.height * l.bars,
                  child: const ColoredBox(color: Colors.black),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: size.height * l.bars,
                  child: const ColoredBox(color: Colors.black),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.seed, this.amount);
  final int seed;
  final double amount;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final count = (size.width * size.height / 90).clamp(0, 6000).round();
    final light = <Offset>[], dark = <Offset>[];
    for (var i = 0; i < count; i++) {
      (r.nextBool() ? light : dark).add(Offset(r.nextDouble() * size.width, r.nextDouble() * size.height));
    }
    final alpha = (amount / 40).clamp(.05, .6);
    final paint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    canvas.drawPoints(ui.PointMode.points, light, paint..color = Colors.white.withValues(alpha: alpha));
    canvas.drawPoints(ui.PointMode.points, dark, paint..color = Colors.black.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.seed != seed || old.amount != amount;
}

/// A mask grid for a pattern transition, ready to be painted as a mesh.
class PatternMesh {
  PatternMesh(this.preset, double width, double height, {this.columns = 96, this.rows = 96}) : values = preset.sampleMask(columns, rows, width, height) {
    final positions = Float32List(columns * rows * 2);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final i = (r * columns + c) * 2;
        positions[i] = c / (columns - 1);
        positions[i + 1] = r / (rows - 1);
      }
    }
    _unit = positions;
    final indices = Uint16List((columns - 1) * (rows - 1) * 6);
    var k = 0;
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < columns - 1; c++) {
        final a = r * columns + c, b = a + 1, d = a + columns, e = d + 1;
        indices
          ..[k++] = a
          ..[k++] = b
          ..[k++] = d
          ..[k++] = b
          ..[k++] = e
          ..[k++] = d;
      }
    }
    _indices = indices;
  }

  final TransitionPreset preset;
  final int columns;
  final int rows;
  final Float32List values;
  late final Float32List _unit;
  late final Uint16List _indices;

  /// The incoming clip's coverage at [progress], painted in [color] over [size].
  ui.Vertices vertices(Size size, double progress, Color color) {
    final positions = Float32List(_unit.length);
    for (var i = 0; i < _unit.length; i += 2) {
      positions[i] = _unit[i] * size.width;
      positions[i + 1] = _unit[i + 1] * size.height;
    }
    final colors = Int32List(values.length);
    final rgb = color.toARGB32() & 0xFFFFFF;
    for (var i = 0; i < values.length; i++) {
      final a = (preset.blend(values[i], progress) * 255).round();
      colors[i] = (a << 24) | rgb;
    }
    return ui.Vertices.raw(ui.VertexMode.triangles, positions, colors: colors, indices: _indices);
  }

  static final _cache = <String, PatternMesh>{};

  /// A shared mesh per preset and frame shape; the newest dozen are kept.
  static PatternMesh of(TransitionPreset preset, double width, double height, {int grid = 96}) {
    final key = '${preset.id}@${(width / height).toStringAsFixed(3)}/$grid';
    final hit = _cache.remove(key);
    final mesh = hit ?? PatternMesh(preset, width, height, columns: grid, rows: grid);
    _cache[key] = mesh;
    while (_cache.length > 40) {
      _cache.remove(_cache.keys.first);
    }
    return mesh;
  }
}

/// The preview of a pattern transition: [incoming] revealed over [outgoing].
class PatternTransitionView extends StatefulWidget {
  const PatternTransitionView({
    super.key,
    required this.preset,
    required this.progress,
    required this.outgoing,
    required this.incoming,
    required this.frameWidth,
    required this.frameHeight,
  });

  final TransitionPreset preset;
  final double progress;
  final Widget outgoing;
  final Widget incoming;
  final int frameWidth;
  final int frameHeight;

  @override
  State<PatternTransitionView> createState() => _PatternTransitionViewState();
}

class _PatternTransitionViewState extends State<PatternTransitionView> {
  ui.Image? _mask;

  @override
  void dispose() {
    _mask?.dispose();
    super.dispose();
  }

  ui.Image _render() {
    final mesh = PatternMesh.of(widget.preset, widget.frameWidth.toDouble(), widget.frameHeight.toDouble());
    const side = 192.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawVertices(mesh.vertices(const Size(side, side), widget.progress, Colors.white), BlendMode.dst, Paint());
    final picture = recorder.endRecording();
    final image = picture.toImageSync(side.toInt(), side.toInt());
    picture.dispose();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final old = _mask;
    final mask = _mask = _render();
    old?.dispose();
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.outgoing,
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) =>
              ImageShader(mask, TileMode.clamp, TileMode.clamp, Matrix4.diagonal3Values(rect.width / mask.width, rect.height / mask.height, 1).storage),
          child: widget.incoming,
        ),
      ],
    );
  }
}

/// Small animated card showing a transition from one colour to another.
class TransitionThumbPainter extends CustomPainter {
  TransitionThumbPainter(this.preset, this.progress, {required this.from, required this.to}) : super();

  final TransitionPreset preset;
  final double progress;
  final Gradient from;
  final Gradient to;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = from.createShader(rect));
    final p = progress;
    if (preset.isPattern) {
      final mesh = PatternMesh.of(preset, size.width, size.height, grid: 40);
      canvas.saveLayer(rect, Paint());
      canvas.drawRect(rect, Paint()..shader = to.createShader(rect));
      canvas.drawVertices(mesh.vertices(size, p, Colors.white), BlendMode.dst, Paint()..blendMode = BlendMode.dstIn);
      canvas.restore();
      return;
    }
    final toPaint = Paint()..shader = to.createShader(rect);
    switch (preset.classic!.name) {
      case 'crossfade':
        canvas.drawRect(rect, toPaint..color = Colors.white.withValues(alpha: p));
      case 'fadeBlack' || 'fadeWhite':
        final color = preset.classic!.name == 'fadeBlack' ? Colors.black : Colors.white;
        if (p >= .5) canvas.drawRect(rect, toPaint);
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 1 - (p - .5).abs() * 2));
      case 'wipeLeft':
        canvas.drawRect(Rect.fromLTRB(size.width * (1 - p), 0, size.width, size.height), toPaint);
      case 'wipeRight':
        canvas.drawRect(Rect.fromLTRB(0, 0, size.width * p, size.height), toPaint);
      case 'slideLeft':
        canvas.drawRect(rect.shift(Offset(size.width * (1 - p), 0)), toPaint);
      case 'slideRight':
        canvas.drawRect(rect.shift(Offset(-size.width * (1 - p), 0)), toPaint);
      case 'circleOpen':
        canvas.drawCircle(size.center(Offset.zero), size.longestSide * .72 * p, toPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TransitionThumbPainter old) => old.preset != preset || old.progress != progress;
}
