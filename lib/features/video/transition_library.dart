import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/expr.dart';
import 'video_project.dart';

/// One transition the user can pick. Classic presets map onto FFmpeg's built-in
/// xfade transitions; pattern presets are a mask formula written in FFmpeg's
/// expression language, which the preview evaluates with the very same text.
class TransitionPreset {
  TransitionPreset._({required this.id, required this.name, required this.category, this.classic, this.mask, this.softness = 0});

  final String id;
  final String name;
  final String category;

  /// Set for classic presets.
  final TransitionType? classic;

  /// For pattern presets: a formula of X, Y, W and H that gives every pixel a
  /// value from 0 to 1. Pixels switch to the next clip in order of that value.
  final String? mask;

  /// Width of the soft edge between the clips, as a fraction of the sweep.
  final double softness;

  bool get isPattern => mask != null;

  /// The xfade custom expression: A is the outgoing clip, B the incoming one and
  /// P runs from 1 down to 0 across the transition.
  String get exportExpr {
    final s = _n(softness);
    return 'A+(B-A)*clip(((1-P)*(1+$s)-($mask))/$s,0,1)';
  }

  /// The xfade options after "transition=".
  String get xfadeTransition => isPattern ? "custom:expr='$exportExpr'" : classic!.xfade;

  /// How much of the incoming clip shows at a mask value, for [progress] 0 to 1.
  double blend(double maskValue, double progress) {
    final t = (progress * (1 + softness) - maskValue) / softness;
    return t < 0 ? 0 : (t > 1 ? 1 : t);
  }

  late final Expr _parsed = Expr.parse(mask!);

  /// Samples the mask on a [columns] by [rows] grid of points spread across a
  /// frame of [width] by [height] pixels, edges included.
  Float32List sampleMask(int columns, int rows, double width, double height) {
    final out = Float32List(columns * rows);
    final vars = {'X': 0.0, 'Y': 0.0, 'W': width, 'H': height};
    for (var r = 0; r < rows; r++) {
      vars['Y'] = r / (rows - 1) * height;
      for (var c = 0; c < columns; c++) {
        vars['X'] = c / (columns - 1) * width;
        out[r * columns + c] = _parsed.eval(vars).clamp(0.0, 1.0);
      }
    }
    return out;
  }
}

String _n(double v) {
  final s = v.toStringAsFixed(4);
  return v < 0 ? '($s)' : s;
}

const _u = '(X/W)';
const _v = '(Y/H)';
const _aspect = '(W/H)';

/// Position along a direction, from 0 where the sweep starts to 1 where it ends.
String _linear(double degrees) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a), s = math.sin(a);
  final cx = c.abs() < 1e-9 ? 0.0 : c, sy = s.abs() < 1e-9 ? 0.0 : s;
  final norm = cx.abs() + sy.abs();
  return '((($_u-0.5)*${_n(cx)}+($_v-0.5)*${_n(sy)})/${_n(norm)}+0.5)';
}

/// Distance from a centre point, 0 there and 1 at the furthest corner.
String _radius(double cx, double cy) {
  final mx = math.max(cx, 1 - cx), my = math.max(cy, 1 - cy);
  return '(hypot(($_u-${_n(cx)})*$_aspect,$_v-${_n(cy)})/hypot(${_n(mx)}*$_aspect,${_n(my)}))';
}

/// Angle around the centre, from 0 to 1.
const _angle = '((atan2($_v-0.5,($_u-0.5)*$_aspect)+PI)/(2*PI))';

String _hash(int columns) => 'mod(sin(floor($_u*$columns)*12.9898+floor($_v*$columns/$_aspect)*78.233)*43758.5453,1)';

const _softness = [('Crisp', 's', .02), ('Soft', 'm', .12), ('Feather', 'f', .35)];

const _centers = [
  ('centre', .5, .5),
  ('top left', 0.0, 0.0),
  ('top', .5, 0.0),
  ('top right', 1.0, 0.0),
  ('right', 1.0, .5),
  ('bottom right', 1.0, 1.0),
  ('bottom', .5, 1.0),
  ('bottom left', 0.0, 1.0),
  ('left', 0.0, .5),
];

String _direction(double degrees) {
  const names = {0: 'right', 45: 'down right', 90: 'down', 135: 'down left', 180: 'left', 225: 'up left', 270: 'up', 315: 'up right'};
  final whole = degrees.round();
  return names[whole] ?? '$whole°';
}

/// Every transition, in a stable order.
class TransitionLibrary {
  TransitionLibrary._() {
    _build();
  }

  static final instance = TransitionLibrary._();

  final List<TransitionPreset> all = [];
  final Map<String, TransitionPreset> _byId = {};

  static const categories = ['Classic', 'Wipes', 'Shapes', 'Blinds', 'Stripes', 'Clocks', 'Spirals', 'Ripples', 'Checkers', 'Dissolves', 'Waves'];

  static const defaultPatternId = 'wipe-45-m';

  TransitionPreset? byId(String id) => _byId[id];

  int get length => all.length;

  void _add(TransitionPreset p) {
    assert(!_byId.containsKey(p.id), p.id);
    all.add(p);
    _byId[p.id] = p;
  }

  void _pattern(String id, String name, String category, String mask) {
    for (final (label, key, soft) in _softness) {
      _add(TransitionPreset._(id: '$id-$key', name: '$name · $label', category: category, mask: mask, softness: soft));
    }
  }

  void _build() {
    for (final t in TransitionType.values) {
      if (t == TransitionType.none || t == TransitionType.pattern) continue;
      _add(TransitionPreset._(id: t.name, name: t.label, category: 'Classic', classic: t));
    }

    for (var d = 0; d < 360; d += 15) {
      _pattern('wipe-$d', 'Wipe ${_direction(d.toDouble())}', 'Wipes', _linear(d.toDouble()));
    }

    const shapes = ['Circle', 'Diamond', 'Box'];
    for (final shape in shapes) {
      for (final (where, cx, cy) in _centers) {
        final mx = math.max(cx, 1 - cx), my = math.max(cy, 1 - cy);
        final open = switch (shape) {
          'Circle' => _radius(cx, cy),
          'Diamond' => '((abs($_u-${_n(cx)})*$_aspect+abs($_v-${_n(cy)}))/(${_n(mx)}*$_aspect+${_n(my)}))',
          _ => 'max(abs($_u-${_n(cx)})/${_n(mx)},abs($_v-${_n(cy)})/${_n(my)})',
        };
        final key = '${shape.toLowerCase()}-${where.replaceAll(' ', '')}';
        _pattern('$key-open', '$shape open · $where', 'Shapes', open);
        _pattern('$key-close', '$shape close · $where', 'Shapes', '(1-$open)');
      }
    }

    const counts = [3, 5, 8, 12, 16, 24];
    for (var i = 0; i < 8; i++) {
      final d = i * 22.5;
      for (final n in counts) {
        _pattern('blinds-${d.round()}-$n', 'Blinds ${_direction(d)} · $n', 'Blinds', 'mod(${_linear(d)}*$n,1)');
        _pattern('comb-${d.round()}-$n', 'Comb ${_direction(d)} · $n', 'Stripes', '(0.5*${_linear(d)}+0.5*mod(floor(${_linear(d + 90)}*$n),2))');
      }
    }

    for (final sectors in [1, 2, 3, 4, 6, 8]) {
      for (final start in [0, 90, 180, 270]) {
        for (final (dir, sign) in [('clockwise', 1), ('anticlockwise', -1)]) {
          final turn = sign > 0 ? _angle : '(1-$_angle)';
          _pattern(
            'clock-$sectors-$start-${sign > 0 ? 'cw' : 'ccw'}',
            '${sectors == 1 ? 'Clock' : 'Fan $sectors'} $dir from $start°',
            'Clocks',
            'mod(($turn+${_n(start / 360)})*$sectors,1)',
          );
        }
      }
    }

    for (var turns = 1; turns <= 6; turns++) {
      for (final (dir, sign) in [('in', 1), ('out', -1)]) {
        final r = _radius(.5, .5);
        _pattern('spiral-$turns-$dir', 'Spiral $dir · $turns turns', 'Spirals', 'mod($_angle${sign > 0 ? '+' : '-'}$r*$turns,1)');
      }
    }

    for (var n = 2; n <= 11; n++) {
      final r = _radius(.5, .5);
      _pattern('rings-$n-out', 'Ripple out · $n rings', 'Ripples', 'mod($r*$n,1)');
      _pattern('rings-$n-in', 'Ripple in · $n rings', 'Ripples', '(1-mod($r*$n,1))');
    }

    for (final n in [2, 3, 4, 6, 8, 12]) {
      for (var d = 0; d < 360; d += 45) {
        _pattern(
          'checker-$n-$d',
          'Checker $n ${_direction(d.toDouble())}',
          'Checkers',
          '(0.5*mod(floor($_u*$n)+floor($_v*$n/$_aspect),2)+0.5*${_linear(d.toDouble())})',
        );
      }
    }

    final biases = [
      ('random', 'Random', ''),
      ('right', 'sweep right', _linear(0)),
      ('down', 'sweep down', _linear(90)),
      ('diag', 'sweep diagonal', _linear(45)),
      ('centre', 'from centre', _radius(.5, .5)),
    ];
    for (final n in [4, 6, 8, 12, 16, 24, 32, 48, 64]) {
      for (final (key, label, bias) in biases) {
        final mask = bias.isEmpty ? _hash(n) : '(0.45*${_hash(n)}+0.55*$bias)';
        _pattern('cells-$n-$key', 'Dissolve $n · $label', 'Dissolves', mask);
      }
    }

    for (var d = 0; d < 360; d += 45) {
      for (final amp in [.05, .1, .2]) {
        for (final freq in [2, 4, 8]) {
          for (final (shape, label) in [('sine', 'Wave'), ('zigzag', 'Zigzag')]) {
            final x = '(${_linear(d + 90.0)}*$freq)';
            final wave = shape == 'sine' ? 'sin(2*PI*$x)' : '(abs(mod($x,1)*2-1)*2-1)';
            final size = amp < .07 ? 'small' : (amp < .15 ? 'medium' : 'big');
            _pattern(
              '$shape-$d-${(amp * 100).round()}-$freq',
              '$label ${_direction(d.toDouble())} · $size ×$freq',
              'Waves',
              '((${_linear(d.toDouble())}+${_n(amp)}*$wave+${_n(amp)})/${_n(1 + 2 * amp)})',
            );
          }
        }
      }
    }
  }

  /// Presets in [category] (or all) whose name contains every word of [text].
  List<TransitionPreset> search({String? category, String text = ''}) {
    final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return [
      for (final p in all)
        if ((category == null || p.category == category) && words.every((w) => p.name.toLowerCase().contains(w) || p.category.toLowerCase().contains(w))) p,
    ];
  }

  /// The preset a clip uses for its transition out, or null for a cut.
  TransitionPreset? forClip(VideoClip clip) {
    switch (clip.transition) {
      case TransitionType.none:
        return null;
      case TransitionType.pattern:
        return byId(clip.transitionPattern ?? '') ?? byId(defaultPatternId);
      default:
        return byId(clip.transition.name);
    }
  }

  /// Gives [clip] the transition [preset].
  static void apply(VideoClip clip, TransitionPreset? preset) {
    if (preset == null) {
      clip
        ..transition = TransitionType.none
        ..transitionPattern = null;
    } else if (preset.isPattern) {
      clip
        ..transition = TransitionType.pattern
        ..transitionPattern = preset.id;
    } else {
      clip
        ..transition = preset.classic!
        ..transitionPattern = null;
    }
  }
}
