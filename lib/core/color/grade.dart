import 'dart:math' as math;

import 'filter_presets.dart';

/// A 4x5 colour matrix in Flutter's layout: 20 values, row-major, with the
/// fifth column holding offsets on a 0-255 scale.
typedef ColorMatrix = List<double>;

const ColorMatrix identityMatrix = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Returns the matrix that applies [b] first and then [a].
ColorMatrix multiplyMatrix(ColorMatrix a, ColorMatrix b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var sum = 0.0;
      for (var k = 0; k < 4; k++) {
        sum += a[row * 5 + k] * b[k * 5 + col];
      }
      if (col == 4) sum += a[row * 5 + 4];
      out[row * 5 + col] = sum;
    }
  }
  return out;
}

ColorMatrix lerpMatrix(ColorMatrix a, ColorMatrix b, double t) => List<double>.generate(20, (i) => a[i] + (b[i] - a[i]) * t);

ColorMatrix _scale(double r, double g, double b) => [
  r, 0, 0, 0, 0, //
  0, g, 0, 0, 0, //
  0, 0, b, 0, 0, //
  0, 0, 0, 1, 0, //
];

ColorMatrix _offset(double r, double g, double b) => [
  1, 0, 0, 0, r, //
  0, 1, 0, 0, g, //
  0, 0, 1, 0, b, //
  0, 0, 0, 1, 0, //
];

ColorMatrix _saturation(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final i = 1 - s;
  return [
    lr * i + s, lg * i, lb * i, 0, 0, //
    lr * i, lg * i + s, lb * i, 0, 0, //
    lr * i, lg * i, lb * i + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

ColorMatrix _hue(double degrees) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a), s = math.sin(a);
  const lr = 0.213, lg = 0.715, lb = 0.072;
  return [
    lr + c * (1 - lr) + s * -lr,
    lg + c * -lg + s * -lg,
    lb + c * -lb + s * (1 - lb),
    0,
    0,
    lr + c * -lr + s * 0.143,
    lg + c * (1 - lg) + s * 0.140,
    lb + c * -lb + s * -0.283,
    0,
    0,
    lr + c * -lr + s * -(1 - lr),
    lg + c * -lg + s * lg,
    lb + c * (1 - lb) + s * lb,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

const ColorMatrix _sepia = [
  0.393, 0.769, 0.189, 0, 0, //
  0.349, 0.686, 0.168, 0, 0, //
  0.272, 0.534, 0.131, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Describes one slider in the adjust panel. Zero is always neutral.
class AdjustParam {
  const AdjustParam(this.key, this.label, this.min, this.max, this.group);
  final String key;
  final String label;
  final double min;
  final double max;
  final String group;
}

const adjustParams = <AdjustParam>[
  AdjustParam('exposure', 'Exposure', -1, 1, 'Light'),
  AdjustParam('brightness', 'Brightness', -1, 1, 'Light'),
  AdjustParam('contrast', 'Contrast', -1, 1, 'Light'),
  AdjustParam('fade', 'Fade', 0, 1, 'Light'),
  AdjustParam('saturation', 'Saturation', -1, 1, 'Color'),
  AdjustParam('temperature', 'Temperature', -1, 1, 'Color'),
  AdjustParam('tint', 'Tint', -1, 1, 'Color'),
  AdjustParam('hue', 'Hue', -180, 180, 'Color'),
  AdjustParam('sepia', 'Sepia', 0, 1, 'Color'),
  AdjustParam('vignette', 'Vignette', 0, 1, 'Effects'),
  AdjustParam('liftR', 'Shadows red', -1, 1, 'Grade'),
  AdjustParam('liftG', 'Shadows green', -1, 1, 'Grade'),
  AdjustParam('liftB', 'Shadows blue', -1, 1, 'Grade'),
  AdjustParam('gainR', 'Highlights red', -1, 1, 'Grade'),
  AdjustParam('gainG', 'Highlights green', -1, 1, 'Grade'),
  AdjustParam('gainB', 'Highlights blue', -1, 1, 'Grade'),
];

/// Builds a colour matrix from slider values. Only linear operations are used
/// so the same matrix can drive both the Flutter preview and the FFmpeg export.
ColorMatrix matrixFromValues(Map<String, double> v) {
  double p(String key) => v[key] ?? 0;
  var m = identityMatrix;

  final exposure = math.pow(2, p('exposure')).toDouble();
  m = multiplyMatrix(_scale(exposure, exposure, exposure), m);

  final gain = 0.5;
  final gainY = 1 + p('gainY') * gain;
  m = multiplyMatrix(_scale((1 + p('gainR') * gain) * gainY, (1 + p('gainG') * gain) * gainY, (1 + p('gainB') * gain) * gainY), m);
  const lift = 48.0;
  // Lift raises the darks more than the lights: out = in * (1 - l) + l.
  final liftY = p('liftY') * lift;
  final keep = 1 - liftY / 255;
  m = multiplyMatrix(multiplyMatrix(_offset(liftY, liftY, liftY), _scale(keep, keep, keep)), m);
  m = multiplyMatrix(_offset(p('liftR') * lift, p('liftG') * lift, p('liftB') * lift), m);
  // Offset moves every tone by the same amount, like a grading suite's offset wheel.
  const shift = 40.0;
  final offY = p('offY') * shift;
  m = multiplyMatrix(_offset(p('offR') * shift + offY, p('offG') * shift + offY, p('offB') * shift + offY), m);

  final t = p('temperature'), tint = p('tint');
  m = multiplyMatrix(_scale((1 + 0.2 * t) * (1 + 0.075 * tint), 1 - 0.15 * tint, (1 - 0.2 * t) * (1 + 0.075 * tint)), m);

  final b = p('brightness') * 64;
  m = multiplyMatrix(_offset(b, b, b), m);

  final k = 1 + p('contrast');
  final kOffset = 127.5 * (1 - k);
  m = multiplyMatrix(multiplyMatrix(_offset(kOffset, kOffset, kOffset), _scale(k, k, k)), m);

  m = multiplyMatrix(_saturation(1 + p('saturation')), m);
  if (p('hue') != 0) m = multiplyMatrix(_hue(p('hue')), m);
  if (p('sepia') != 0) {
    m = multiplyMatrix(lerpMatrix(identityMatrix, _sepia, p('sepia')), m);
  }

  final f = p('fade');
  if (f != 0) {
    final lifted = 255 * 0.12 * f;
    final s = 1 - 0.24 * f;
    m = multiplyMatrix(multiplyMatrix(_offset(lifted, lifted, lifted), _scale(s, s, s)), m);
  }
  return m;
}

/// The look of one image or clip: a filter preset at some strength, plus manual
/// adjustments applied on top.
class Grade {
  Grade({this.filterId = 'original', this.strength = 1, Map<String, double>? values}) : values = values ?? {};

  factory Grade.fromJson(Map<String, dynamic>? j) {
    if (j == null) return Grade();
    return Grade(
      filterId: j['filterId'] as String? ?? 'original',
      strength: (j['strength'] as num?)?.toDouble() ?? 1,
      values: (j['values'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    );
  }

  String filterId;
  double strength;
  final Map<String, double> values;

  Map<String, dynamic> toJson() => {'filterId': filterId, 'strength': strength, 'values': values};

  Grade clone() => Grade(filterId: filterId, strength: strength, values: Map.of(values));

  FilterPreset get preset => filterById(filterId);

  ColorMatrix get matrix {
    final filter = lerpMatrix(identityMatrix, preset.matrix, strength);
    return multiplyMatrix(matrixFromValues(values), filter);
  }

  /// Combined vignette amount from the preset and the manual slider, 0 to 1.
  double get vignette {
    final fromPreset = (preset.values['vignette'] ?? 0) * strength;
    return (fromPreset + (values['vignette'] ?? 0)).clamp(0.0, 1.0);
  }

  bool get isNeutral => filterId == 'original' && values.values.every((v) => v == 0);
}
