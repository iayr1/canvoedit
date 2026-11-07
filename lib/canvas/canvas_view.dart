import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layer.dart';
import 'renderer.dart';

/// Freehand drawing settings. A non-null value puts the canvas in draw mode.
class DrawSettings {
  const DrawSettings(this.color, this.width);
  final int color;

  /// Fraction of canvas width.
  final double width;
}

/// Interactive canvas: tap to select, drag to move, pinch or use the corner
/// handle to scale and rotate. It edits layers in place and calls back so the
/// owner can repaint and record undo history.
class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.aspectRatio,
    required this.layers,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
    required this.onCommit,
    this.background,
    this.onEditText,
    this.draw,
    this.onStroke,
    this.timeMs,
  });

  final double aspectRatio;
  final List<CanvasLayer> layers;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onChanged;
  final VoidCallback onCommit;
  final void Function(Canvas, Size)? background;
  final ValueChanged<CanvasLayer>? onEditText;
  final DrawSettings? draw;
  final ValueChanged<CanvasLayer>? onStroke;

  /// Current time in a video project. Layers outside it are hidden.
  final int? timeMs;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

enum _Gesture { none, transform, handle, draw }

class _CanvasViewState extends State<CanvasView> {
  static const _handleRadius = 28.0;

  _Gesture _gesture = _Gesture.none;
  CanvasLayer? _active;
  double _startSize = 0;
  double _startRotation = 0;
  double _handleStartDistance = 1;
  double _handleStartAngle = 0;
  List<double>? _stroke;
  bool _snapX = false;
  bool _snapY = false;
  Size _canvas = Size.zero;

  CanvasLayer? get _selected {
    for (final l in widget.layers) {
      if (l.id == widget.selectedId) return l;
    }
    return null;
  }

  Offset _center(CanvasLayer l) => Offset(l.cx * _canvas.width, l.cy * _canvas.height);

  Offset _handlePosition(CanvasLayer l) {
    final size = SceneRenderer.layerSize(l, _canvas);
    final corner = Offset(size.width / 2, size.height / 2);
    final c = math.cos(l.rotation), s = math.sin(l.rotation);
    return _center(l) + Offset(corner.dx * c - corner.dy * s, corner.dx * s + corner.dy * c);
  }

  CanvasLayer? _hit(Offset p) {
    for (final l in widget.layers.reversed) {
      if (l.locked || !l.isVisibleAt(widget.timeMs)) continue;
      if (SceneRenderer.hitTest(l, p, _canvas)) return l;
    }
    return null;
  }

  double _sizeOf(CanvasLayer l) => l.isTextual ? l.fontSize : l.width;

  void _setSize(CanvasLayer l, double v) {
    if (l.isTextual) {
      l.fontSize = v.clamp(.01, 1.2);
    } else {
      l.width = v.clamp(.03, 3);
    }
  }

  void _begin(CanvasLayer l, _Gesture gesture) {
    _active = l;
    _gesture = gesture;
    _startSize = _sizeOf(l);
    _startRotation = l.rotation;
  }

  void _onScaleStart(ScaleStartDetails d) {
    final p = d.localFocalPoint;
    if (widget.draw != null) {
      _gesture = _Gesture.draw;
      _stroke = [p.dx / _canvas.width, p.dy / _canvas.height];
      setState(() {});
      return;
    }
    final selected = _selected;
    if (selected != null && !selected.locked && selected.isVisibleAt(widget.timeMs)) {
      final toHandle = p - _handlePosition(selected);
      if (toHandle.distance <= _handleRadius) {
        _begin(selected, _Gesture.handle);
        final fromCenter = p - _center(selected);
        _handleStartDistance = math.max(1, fromCenter.distance);
        _handleStartAngle = fromCenter.direction;
        return;
      }
    }
    // Two fingers anywhere keep working on the current selection.
    if (d.pointerCount > 1 && selected != null && !selected.locked) {
      _begin(selected, _Gesture.transform);
      return;
    }
    final hit = _hit(p);
    if (hit != null && !hit.isBase) {
      if (hit.id != widget.selectedId) widget.onSelect(hit.id);
      _begin(hit, _Gesture.transform);
    } else {
      _gesture = _Gesture.none;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    switch (_gesture) {
      case _Gesture.none:
        return;
      case _Gesture.draw:
        final p = d.localFocalPoint;
        setState(() => _stroke!.addAll([p.dx / _canvas.width, p.dy / _canvas.height]));
        return;
      case _Gesture.handle:
        final l = _active!;
        final fromCenter = d.localFocalPoint - _center(l);
        _setSize(l, _startSize * fromCenter.distance / _handleStartDistance);
        l.rotation = _snapAngle(_startRotation + fromCenter.direction - _handleStartAngle);
      case _Gesture.transform:
        final l = _active!;
        l.cx += d.focalPointDelta.dx / _canvas.width;
        l.cy += d.focalPointDelta.dy / _canvas.height;
        _snapX = (l.cx - .5).abs() < .012;
        _snapY = (l.cy - .5).abs() < .012;
        if (_snapX) l.cx = .5;
        if (_snapY) l.cy = .5;
        if (d.pointerCount > 1) {
          _setSize(l, _startSize * d.scale);
          l.rotation = _snapAngle(_startRotation + d.rotation);
        }
    }
    widget.onChanged();
    setState(() {});
  }

  double _snapAngle(double a) {
    const step = math.pi / 2;
    final nearest = (a / step).round() * step;
    return (a - nearest).abs() < .035 ? nearest : a;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_gesture == _Gesture.draw) {
      final draw = widget.draw;
      final points = _stroke;
      _stroke = null;
      if (draw != null && points != null) {
        widget.onStroke?.call(CanvasLayer.stroke(points, draw.color, draw.width));
      }
    } else if (_gesture != _Gesture.none) {
      widget.onCommit();
    }
    _gesture = _Gesture.none;
    _active = null;
    setState(() {
      _snapX = false;
      _snapY = false;
    });
  }

  void _onTapUp(TapUpDetails d) {
    if (widget.draw != null) return;
    final hit = _hit(d.localPosition);
    widget.onSelect(hit?.id);
  }

  void _onDoubleTapDown(TapDownDetails d) {
    final hit = _hit(d.localPosition);
    if (hit != null && hit.kind == LayerKind.text) widget.onEditText?.call(hit);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        var w = box.maxWidth, h = w / widget.aspectRatio;
        if (h > box.maxHeight) {
          h = box.maxHeight;
          w = h * widget.aspectRatio;
        }
        _canvas = Size(w, h);
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: GestureDetector(
              key: const ValueKey('canvas-gestures'),
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onDoubleTapDown: _onDoubleTapDown,
              onDoubleTap: () {},
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: ClipRect(
                child: CustomPaint(
                  size: _canvas,
                  painter: _ScenePainter(widget.layers, widget.background, widget.timeMs, _stroke, widget.draw),
                  foregroundPainter: _SelectionPainter(_selected, widget.timeMs, _snapX, _snapY),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.layers, this.background, this.timeMs, this.stroke, this.draw);
  final List<CanvasLayer> layers;
  final void Function(Canvas, Size)? background;
  final int? timeMs;
  final List<double>? stroke;
  final DrawSettings? draw;

  @override
  void paint(Canvas canvas, Size size) {
    background?.call(canvas, size);
    SceneRenderer.paintLayers(canvas, size, layers, timeMs: timeMs);
    if (stroke != null && draw != null) {
      SceneRenderer.paintLayer(canvas, size, CanvasLayer.stroke(stroke!, draw!.color, draw!.width));
    }
  }

  // Layers are edited in place, so any rebuild has to repaint.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.layer, this.timeMs, this.snapX, this.snapY);
  final CanvasLayer? layer;
  final int? timeMs;
  final bool snapX;
  final bool snapY;

  static const _accent = Color(0xFFFF5C39);

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = const Color(0xFF7C5CFF)
      ..strokeWidth = 1;
    if (snapX) canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), guide);
    if (snapY) canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), guide);

    final l = layer;
    if (l == null || l.kind == LayerKind.stroke || l.isBase || !l.isVisibleAt(timeMs)) return;
    final s = SceneRenderer.layerSize(l, size);
    canvas.save();
    canvas.translate(l.cx * size.width, l.cy * size.height);
    canvas.rotate(l.rotation);
    final rect = Rect.fromCenter(center: Offset.zero, width: s.width, height: s.height);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _accent
        ..strokeWidth = 1.5,
    );
    if (!l.locked) {
      canvas.drawCircle(rect.bottomRight, 9, Paint()..color = Colors.white);
      canvas.drawCircle(rect.bottomRight, 6, Paint()..color = _accent);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
