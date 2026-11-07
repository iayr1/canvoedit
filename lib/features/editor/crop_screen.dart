import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../canvas/layer.dart';
import '../../canvas/renderer.dart';

/// Maps a point between source-image space and what the user sees after quarter
/// turns and flips. Both spaces run from -0.5 to 0.5 about the image centre.
Offset sourceToDisplay(Offset p, int quarterTurns, bool flipH, bool flipV) {
  var x = p.dx, y = p.dy;
  for (var i = 0; i < quarterTurns % 4; i++) {
    final nx = -y;
    y = x;
    x = nx;
  }
  return Offset(flipH ? -x : x, flipV ? -y : y);
}

Offset displayToSource(Offset p, int quarterTurns, bool flipH, bool flipV) {
  var x = flipH ? -p.dx : p.dx, y = flipV ? -p.dy : p.dy;
  for (var i = 0; i < quarterTurns % 4; i++) {
    final nx = y;
    y = -x;
    x = nx;
  }
  return Offset(x, y);
}

/// Crop, rotate and flip for one image layer. Applies to the layer on Done.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.layer});
  final CanvasLayer layer;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

enum _Drag { none, move, topLeft, topRight, bottomLeft, bottomRight }

class _CropScreenState extends State<CropScreen> {
  late final CanvasLayer _full;

  /// Crop in display space, from 0 to 1 across the rotated image.
  late Rect _rect;
  double? _ratio;
  _Drag _drag = _Drag.none;
  Size _view = Size.zero;

  static const _ratios = <String, double?>{
    'Free': null,
    '1:1': 1,
    '4:5': 4 / 5,
    '9:16': 9 / 16,
    '16:9': 16 / 9,
    '3:2': 3 / 2,
  };

  @override
  void initState() {
    super.initState();
    final l = widget.layer;
    _full = l.clone()
      ..cropL = 0
      ..cropT = 0
      ..cropR = 1
      ..cropB = 1
      ..cx = .5
      ..cy = .5
      ..width = 1
      ..rotation = 0
      ..opacity = 1;
    final a = _toDisplay(Offset(l.cropL - .5, l.cropT - .5));
    final b = _toDisplay(Offset(l.cropR - .5, l.cropB - .5));
    _rect = Rect.fromPoints(a, b);
  }

  Offset _toDisplay(Offset source) {
    final d = sourceToDisplay(source, _full.quarterTurns, _full.flipH, _full.flipV);
    return d + const Offset(.5, .5);
  }

  void _turn() {
    setState(() {
      // A quarter turn clockwise moves (x, y) to (1 - y, x) in display space.
      final t = _rect;
      _rect = Rect.fromLTRB(1 - t.bottom, t.left, 1 - t.top, t.right);
      _full.quarterTurns = (_full.quarterTurns + 1) % 4;
      final oldFlipH = _full.flipH;
      _full.flipH = _full.flipV;
      _full.flipV = oldFlipH;
      _ratio = null;
    });
  }

  void _flipH() => setState(() {
    _full.flipH = !_full.flipH;
    _rect = Rect.fromLTRB(1 - _rect.right, _rect.top, 1 - _rect.left, _rect.bottom);
  });

  void _flipV() => setState(() {
    _full.flipV = !_full.flipV;
    _rect = Rect.fromLTRB(_rect.left, 1 - _rect.bottom, _rect.right, 1 - _rect.top);
  });

  void _setRatio(double? ratio) {
    setState(() {
      _ratio = ratio;
      if (ratio == null) return;
      // Largest centred box of this pixel ratio inside the image.
      final imageRatio = 1 / _full.imageAspect;
      var w = 1.0, h = imageRatio / ratio;
      if (h > 1) {
        h = 1;
        w = ratio / imageRatio;
      }
      _rect = Rect.fromCenter(center: const Offset(.5, .5), width: w, height: h);
    });
  }

  void _apply() {
    final a = displayToSource(_rect.topLeft - const Offset(.5, .5), _full.quarterTurns, _full.flipH, _full.flipV);
    final b = displayToSource(_rect.bottomRight - const Offset(.5, .5), _full.quarterTurns, _full.flipH, _full.flipV);
    final src = Rect.fromPoints(a, b).shift(const Offset(.5, .5));
    final l = widget.layer
      ..quarterTurns = _full.quarterTurns
      ..flipH = _full.flipH
      ..flipV = _full.flipV
      ..cropL = src.left.clamp(0.0, 1.0)
      ..cropT = src.top.clamp(0.0, 1.0)
      ..cropR = src.right.clamp(0.0, 1.0)
      ..cropB = src.bottom.clamp(0.0, 1.0);
    Navigator.of(context).pop(l);
  }

  void _onPanStart(DragStartDetails d) {
    final p = Offset(d.localPosition.dx / _view.width, d.localPosition.dy / _view.height);
    const reach = .09;
    bool near(Offset c) => (p - c).distance < reach;
    if (near(_rect.topLeft)) {
      _drag = _Drag.topLeft;
    } else if (near(_rect.topRight)) {
      _drag = _Drag.topRight;
    } else if (near(_rect.bottomLeft)) {
      _drag = _Drag.bottomLeft;
    } else if (near(_rect.bottomRight)) {
      _drag = _Drag.bottomRight;
    } else if (_rect.contains(p)) {
      _drag = _Drag.move;
    } else {
      _drag = _Drag.none;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final dx = d.delta.dx / _view.width, dy = d.delta.dy / _view.height;
    setState(() {
      var r = _rect;
      switch (_drag) {
        case _Drag.none:
          return;
        case _Drag.move:
          r = r.shift(Offset(
            dx.clamp(-r.left, 1 - r.right),
            dy.clamp(-r.top, 1 - r.bottom),
          ));
        case _Drag.topLeft:
          r = Rect.fromLTRB(r.left + dx, r.top + dy, r.right, r.bottom);
        case _Drag.topRight:
          r = Rect.fromLTRB(r.left, r.top + dy, r.right + dx, r.bottom);
        case _Drag.bottomLeft:
          r = Rect.fromLTRB(r.left + dx, r.top, r.right, r.bottom + dy);
        case _Drag.bottomRight:
          r = Rect.fromLTRB(r.left, r.top, r.right + dx, r.bottom + dy);
      }
      _rect = _constrain(r);
    });
  }

  Rect _constrain(Rect r) {
    const minSize = .05;
    var left = math.min(r.left, r.right - minSize).clamp(0.0, 1.0);
    var top = math.min(r.top, r.bottom - minSize).clamp(0.0, 1.0);
    var right = math.max(r.right, left + minSize).clamp(0.0, 1.0);
    var bottom = math.max(r.bottom, top + minSize).clamp(0.0, 1.0);
    if (_ratio != null) {
      // Keep the pixel ratio by deriving height from the dragged width, anchored
      // to whichever edge is not being moved.
      final imageRatio = 1 / _full.imageAspect;
      final h = (right - left) * imageRatio / _ratio!;
      final fromBottom = _drag == _Drag.topLeft || _drag == _Drag.topRight;
      if (fromBottom) {
        top = (bottom - h).clamp(0.0, 1.0);
        if (bottom - top < h - 1e-6) return _rect;
      } else {
        bottom = (top + h).clamp(0.0, 1.0);
        if (bottom - top < h - 1e-6) return _rect;
      }
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop'),
        actions: [TextButton(onPressed: _apply, child: const Text('Done'))],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1 / _full.imageAspect,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        _view = box.biggest;
                        return GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          child: CustomPaint(size: _view, painter: _CropPainter(_full, _rect)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in _ratios.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.key),
                        selected: _ratio == e.value,
                        onSelected: (_) => _setRatio(e.value),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(onPressed: _turn, icon: const Icon(Icons.rotate_90_degrees_cw_outlined), label: const Text('Rotate')),
                TextButton.icon(onPressed: _flipH, icon: const Icon(Icons.flip), label: const Text('Flip H')),
                TextButton.icon(
                  onPressed: _flipV,
                  icon: const RotatedBox(quarterTurns: 1, child: Icon(Icons.flip)),
                  label: const Text('Flip V'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.layer, this.rect);
  final CanvasLayer layer;
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    SceneRenderer.paintLayer(canvas, size, layer);
    final r = Rect.fromLTRB(rect.left * size.width, rect.top * size.height, rect.right * size.width, rect.bottom * size.height);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(r),
      Paint()..color = Colors.black54,
    );
    final line = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = r.left + r.width * i / 3, y = r.top + r.height * i / 3;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), line);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), line);
    }
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 2,
    );
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas.drawCircle(c, 7, Paint()..color = AppColors.coral);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
