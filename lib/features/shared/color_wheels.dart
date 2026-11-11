import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/color/grade.dart';

/// One grading wheel's settings: which grade values it drives.
class _WheelSpec {
  const _WheelSpec(this.label, this.prefix, this.master, this.masterLabel);
  final String label;

  /// Prefix of its red, green and blue values, such as "lift" for liftR.
  final String prefix;

  /// Key of its brightness slider.
  final String master;
  final String masterLabel;
}

const _wheels = [
  _WheelSpec('Shadows', 'lift', 'liftY', 'Lift'),
  _WheelSpec('Highlights', 'gain', 'gainY', 'Gain'),
  _WheelSpec('Offset', 'off', 'offY', 'Offset'),
];

/// How far the colour values move when the puck reaches the wheel's rim.
const _reach = .8;

/// Colour wheels in the style of a grading suite: drag a puck towards a hue to
/// push that tone range's colour, and use the slider for its brightness.
/// Everything stays a linear colour matrix, so preview and export agree.
class ColorWheelsPanel extends StatefulWidget {
  const ColorWheelsPanel({super.key, required this.grade, required this.onChanged, required this.onCommit});
  final Grade grade;
  final VoidCallback onChanged;
  final VoidCallback onCommit;

  @override
  State<ColorWheelsPanel> createState() => _ColorWheelsPanelState();
}

class _ColorWheelsPanelState extends State<ColorWheelsPanel> {
  Map<String, double> get _v => widget.grade.values;

  /// Puck position, -1 to 1 on each axis, from the wheel's colour values.
  Offset _puck(_WheelSpec w) {
    final r = _v['${w.prefix}R'] ?? 0, g = _v['${w.prefix}G'] ?? 0, b = _v['${w.prefix}B'] ?? 0;
    // Colours are r = cos(a), g = cos(a - 120°), b = cos(a + 120°), scaled.
    final x = (r - (g + b) / 2) / 1.5 / _reach;
    final y = (g - b) / math.sqrt(3) / _reach;
    return Offset(x, -y);
  }

  void _setPuck(_WheelSpec w, Offset p) {
    var d = p;
    if (d.distance > 1) d = d / d.distance;
    final a = math.atan2(-d.dy, d.dx), rho = d.distance * _reach;
    double clean(double x) => (x * 1000).roundToDouble() / 1000;
    _v['${w.prefix}R'] = clean(rho * math.cos(a));
    _v['${w.prefix}G'] = clean(rho * math.cos(a - 2 * math.pi / 3));
    _v['${w.prefix}B'] = clean(rho * math.cos(a + 2 * math.pi / 3));
    setState(() {});
    widget.onChanged();
  }

  void _reset(_WheelSpec w) {
    for (final k in ['R', 'G', 'B']) {
      _v.remove('${w.prefix}$k');
    }
    _v.remove(w.master);
    setState(() {});
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(
          children: [
            for (final w in _wheels)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            w.label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9.5, letterSpacing: .6, fontWeight: FontWeight.w800, color: AppColors.muted),
                          ),
                        ),
                        GestureDetector(
                          key: ValueKey('reset-${w.prefix}'),
                          onTap: () => _reset(w),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.refresh_rounded, size: 14, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(box.maxWidth, box.maxHeight) - 4;
                          Offset toPuck(Offset local) => Offset(local.dx / side * 2 - 1, local.dy / side * 2 - 1);
                          return Center(
                            child: GestureDetector(
                              key: ValueKey('wheel-${w.prefix}'),
                              onPanStart: (d) => _setPuck(w, toPuck(d.localPosition)),
                              onPanUpdate: (d) => _setPuck(w, toPuck(d.localPosition)),
                              onPanEnd: (_) => widget.onCommit(),
                              onTapUp: (d) {
                                _setPuck(w, toPuck(d.localPosition));
                                widget.onCommit();
                              },
                              child: CustomPaint(size: Size.square(side), painter: _WheelPainter(_puck(w))),
                            ),
                          );
                        },
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        key: ValueKey('master-${w.prefix}'),
                        value: (_v[w.master] ?? 0).clamp(-1.0, 1.0),
                        min: -1,
                        max: 1,
                        onChanged: (x) {
                          setState(() => _v[w.master] = (x * 100).roundToDouble() / 100);
                          widget.onChanged();
                        },
                        onChangeEnd: (_) => widget.onCommit(),
                      ),
                    ),
                    Text(
                      '${w.masterLabel} ${((_v[w.master] ?? 0) * 100).round()}',
                      style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.puck);
  final Offset puck;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    // Hue around the rim, matching the puck maths: red at 0°, then
    // counter-clockwise through yellow, green, cyan, blue and magenta.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [Color(0xFFFF4D4D), Color(0xFFFF4DFF), Color(0xFF4D4DFF), Color(0xFF4DFFFF), Color(0xFF4DFF4D), Color(0xFFFFFF4D), Color(0xFFFF4D4D)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = RadialGradient(colors: [const Color(0xFF2A2638), const Color(0xFF2A2638).withValues(alpha: .15)]).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white24,
    );
    final cross = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(c - Offset(r * .25, 0), c + Offset(r * .25, 0), cross);
    canvas.drawLine(c - Offset(0, r * .25), c + Offset(0, r * .25), cross);
    final p = c + Offset(puck.dx * r, puck.dy * r);
    canvas.drawCircle(p, 8, Paint()..color = Colors.black45);
    canvas.drawCircle(p, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(p, 3.5, Paint()..shader = AppGradients.brand.createShader(Rect.fromCircle(center: p, radius: 4)));
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.puck != puck;
}
