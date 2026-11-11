import 'dart:math' as math;

import '../../core/expr.dart';

/// The three layers an effect is built from.
enum EffectLayer { motion, texture, light }

/// One building block of an effect.
///
/// Motion parts are written as FFmpeg expressions over the output frame number
/// `on`: zoom ([zoom]), and where the visible window sits horizontally and
/// vertically ([panX], [panY], 0 to 1). The preview evaluates the same text.
class EffectPart {
  const EffectPart(
    this.id,
    this.name,
    this.layer,
    this.group, {
    this.zoom = '1',
    this.panX = '0.5',
    this.panY = '0.5',
    this.rotate,
    this.grain = 0,
    this.blur = 0,
    this.sharpen = false,
    this.pixel = 0,
    this.rgbSplit = 0,
    this.fadeIn,
    this.fadeOut,
    this.flicker = 0,
    this.bars = 0,
  });

  final String id;
  final String name;
  final EffectLayer layer;

  /// Browsing group, such as Zoom or Grain.
  final String group;

  // Motion. Expressions may use `on` (frame number), `N` (frames in the clip)
  // and, for [rotate], `t` (seconds).
  final String zoom;
  final String panX;
  final String panY;
  final String? rotate;

  // Texture.
  final double grain;
  final double blur;
  final bool sharpen;
  final int pixel;
  final int rgbSplit;

  // Light. Fades are (colour, seconds); colour is 0xRRGGBB.
  final (int, double)? fadeIn;
  final (int, double)? fadeOut;
  final double flicker;

  /// Height of black bars at top and bottom, as a fraction of the frame.
  final double bars;

  bool get isNone => id == 'none';
  bool get moves => zoom != '1' || panX != '0.5' || panY != '0.5' || rotate != null;
}

const _p = 'min(on/N,1)';

List<EffectPart> _motion() {
  final parts = <EffectPart>[const EffectPart('none', 'None', EffectLayer.motion, '')];
  for (final (key, label, k) in [('1', 'gentle', .1), ('2', 'medium', .22), ('3', 'strong', .4)]) {
    parts
      ..add(EffectPart('zin$key', 'Zoom in $label', EffectLayer.motion, 'Zoom', zoom: '1+$k*$_p'))
      ..add(EffectPart('zout$key', 'Zoom out $label', EffectLayer.motion, 'Zoom', zoom: '1+$k*(1-$_p)'));
  }
  for (final (key, label, z) in [('s', 'slow', 1.15), ('f', 'fast', 1.32)]) {
    parts
      ..add(EffectPart('panr$key', 'Pan right $label', EffectLayer.motion, 'Pan', zoom: '$z', panX: _p))
      ..add(EffectPart('panl$key', 'Pan left $label', EffectLayer.motion, 'Pan', zoom: '$z', panX: '(1-$_p)'))
      ..add(EffectPart('pand$key', 'Pan down $label', EffectLayer.motion, 'Pan', zoom: '$z', panY: _p))
      ..add(EffectPart('panu$key', 'Pan up $label', EffectLayer.motion, 'Pan', zoom: '$z', panY: '(1-$_p)'));
  }
  for (final (key, label, x, y) in [
    ('dr', 'Drift down right', _p, _p),
    ('dl', 'Drift down left', '(1-$_p)', _p),
    ('ur', 'Drift up right', _p, '(1-$_p)'),
    ('ul', 'Drift up left', '(1-$_p)', '(1-$_p)'),
  ]) {
    parts.add(EffectPart('drift$key', label, EffectLayer.motion, 'Pan', zoom: '1.2+0.08*$_p', panX: x, panY: y));
  }
  for (final (key, label, beats) in [('1', 'Pulse slow', 1), ('2', 'Pulse', 2), ('3', 'Pulse fast', 4)]) {
    parts.add(EffectPart('pulse$key', label, EffectLayer.motion, 'Pulse & shake', zoom: '1+0.07*abs(sin(PI*$beats*on/30))'));
  }
  for (final (key, label, a) in [('1', 'Shake subtle', .25), ('2', 'Shake', .55), ('3', 'Earthquake', 1.0)]) {
    parts.add(
      EffectPart(
        'shake$key',
        label,
        EffectLayer.motion,
        'Pulse & shake',
        zoom: '1.1',
        panX: '(0.5+0.5*$a*sin(on*1.7)*cos(on*0.9))',
        panY: '(0.5+0.5*$a*cos(on*2.3)*sin(on*1.3))',
      ),
    );
  }
  for (final (key, label, a) in [('1', 'Sway', .025), ('2', 'Rock', .055)]) {
    parts.add(EffectPart('sway$key', label, EffectLayer.motion, 'Pulse & shake', zoom: '1.15', rotate: '$a*sin(2*PI*t*0.5)'));
  }
  return parts;
}

const _textures = [
  EffectPart('none', 'None', EffectLayer.texture, ''),
  EffectPart('grain1', 'Film grain', EffectLayer.texture, 'Grain', grain: 12),
  EffectPart('grain2', 'Heavy grain', EffectLayer.texture, 'Grain', grain: 28),
  EffectPart('blur1', 'Soft focus', EffectLayer.texture, 'Blur', blur: 3),
  EffectPart('blur2', 'Dream blur', EffectLayer.texture, 'Blur', blur: 9),
  EffectPart('sharp', 'Sharpen', EffectLayer.texture, 'Blur', sharpen: true),
  EffectPart('pixel', '8-bit pixels', EffectLayer.texture, 'Retro', pixel: 24),
  EffectPart('rgb', 'RGB split', EffectLayer.texture, 'Retro', rgbSplit: 8),
];

const _lights = [
  EffectPart('none', 'None', EffectLayer.light, ''),
  EffectPart('flash', 'Flash in', EffectLayer.light, 'Flash & fade', fadeIn: (0xFFFFFF, .4)),
  EffectPart('fib', 'Fade from black', EffectLayer.light, 'Flash & fade', fadeIn: (0x000000, .8)),
  EffectPart('fob', 'Fade to black', EffectLayer.light, 'Flash & fade', fadeOut: (0x000000, .8)),
  EffectPart('fiw', 'Fade from white', EffectLayer.light, 'Flash & fade', fadeIn: (0xFFFFFF, .8)),
  EffectPart('flicker', 'Flicker', EffectLayer.light, 'Flash & fade', flicker: .07),
  EffectPart('bars1', 'Cinema bars', EffectLayer.light, 'Cinema', bars: .07),
  EffectPart('bars2', 'Wide cinema', EffectLayer.light, 'Cinema', bars: .13),
];

/// A clip effect: one motion, one texture and one light part, any of which may
/// be "none". Its id joins the three part ids with dots.
class ClipEffect {
  const ClipEffect(this.motion, this.texture, this.light);

  final EffectPart motion;
  final EffectPart texture;
  final EffectPart light;

  String get id => '${motion.id}.${texture.id}.${light.id}';

  List<EffectPart> get parts => [motion, texture, light];

  bool get isNone => motion.isNone && texture.isNone && light.isNone;

  String get name => parts.where((p) => !p.isNone).map((p) => p.name).join(' + ');

  Set<String> get groups => {
    for (final p in parts)
      if (!p.isNone) p.group,
  };
}

/// Every combination of motion, texture and light.
class EffectLibrary {
  EffectLibrary._() {
    final singles = <ClipEffect>[], pairs = <ClipEffect>[], triples = <ClipEffect>[];
    for (final m in motions) {
      for (final t in textures) {
        for (final l in lights) {
          final e = ClipEffect(m, t, l);
          if (e.isNone) continue;
          final count = e.parts.where((p) => !p.isNone).length;
          (count == 1 ? singles : (count == 2 ? pairs : triples)).add(e);
          _byId[e.id] = e;
        }
      }
    }
    // Single effects lead with motion, then texture, then light. (List.sort
    // is not stable, so group them by hand.)
    final ordered = [
      for (final layer in EffectLayer.values)
        for (final e in singles)
          if (_layerOf(e) == layer) e,
    ];
    all = [...ordered, ...pairs, ...triples];
  }

  static final instance = EffectLibrary._();

  static EffectLayer _layerOf(ClipEffect e) => e.parts.firstWhere((p) => !p.isNone).layer;

  final List<EffectPart> motions = _motion();
  List<EffectPart> get textures => _textures;
  List<EffectPart> get lights => _lights;

  late final List<ClipEffect> all;
  final Map<String, ClipEffect> _byId = {};

  static const groups = ['Zoom', 'Pan', 'Pulse & shake', 'Grain', 'Blur', 'Retro', 'Flash & fade', 'Cinema'];

  int get length => all.length;

  ClipEffect? byId(String? id) => id == null ? null : _byId[id];

  List<ClipEffect> search({String? group, String text = ''}) {
    final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return [
      for (final e in all)
        if ((group == null || e.groups.contains(group)) && words.every((w) => e.name.toLowerCase().contains(w))) e,
    ];
  }
}

String _f(double v) => v.toStringAsFixed(4);

/// FFmpeg filters for an effect on a clip already scaled to [width] by [height].
List<String> effectFilters(ClipEffect effect, {required int width, required int height, required int fps, required int durationMs}) {
  final filters = <String>[];
  final frames = (durationMs / 1000 * fps).round().clamp(1, 1 << 30);
  final seconds = durationMs / 1000;
  String withFrames(String e) => e.replaceAll('N', '$frames').replaceAll('on/30', 'on/$fps');

  final m = effect.motion;
  if (m.moves) {
    final z = withFrames(m.zoom);
    filters.add("zoompan=z='$z':x='(iw-iw/zoom)*${withFrames(m.panX)}':y='(ih-ih/zoom)*${withFrames(m.panY)}':d=1:s=${width}x$height:fps=$fps");
    if (m.rotate != null) filters.add("rotate=a='${m.rotate}':c=black");
  }

  final t = effect.texture;
  if (t.grain > 0) filters.add('noise=alls=${t.grain.round()}:allf=t+u');
  if (t.blur > 0) filters.add('gblur=sigma=${_f(t.blur * width / 1080)}');
  if (t.sharpen) filters.add('unsharp=5:5:1.2:5:5:0');
  if (t.pixel > 0) {
    final w = (width / t.pixel).round().clamp(2, width), h = (height / t.pixel).round().clamp(2, height);
    filters.add('scale=$w:$h:flags=neighbor,scale=$width:$height:flags=neighbor');
  }
  if (t.rgbSplit > 0) {
    final px = (t.rgbSplit * width / 1080).round().clamp(1, 64);
    filters.add('rgbashift=rh=-$px:bh=$px');
  }

  final l = effect.light;
  String hex(int c) => '0x${c.toRadixString(16).padLeft(6, '0')}';
  if (l.fadeIn != null) {
    final (color, d) = l.fadeIn!;
    filters.add('fade=t=in:st=0:d=${_f(_fadeLength(d, seconds))}:color=${hex(color)}');
  }
  if (l.fadeOut != null) {
    final (color, d) = l.fadeOut!;
    final len = _fadeLength(d, seconds);
    filters.add('fade=t=out:st=${_f(seconds - len)}:d=${_f(len)}:color=${hex(color)}');
  }
  if (l.flicker > 0) filters.add("eq=brightness='${_f(l.flicker)}*sin(t*40)':eval=frame");
  if (l.bars > 0) {
    final bar = (height * l.bars).round();
    filters.add('drawbox=x=0:y=0:w=iw:h=$bar:color=black:t=fill,drawbox=x=0:y=ih-$bar:w=iw:h=$bar:color=black:t=fill');
  }
  return filters;
}

/// Fades never take more than a third of the clip.
double _fadeLength(double wanted, double clipSeconds) => wanted < clipSeconds / 3 ? wanted : clipSeconds / 3;

/// What an effect does to the picture at one moment, for the preview.
class EffectFrame {
  const EffectFrame({this.zoom = 1, this.centerX = .5, this.centerY = .5, this.rotation = 0, this.overlay, this.overlayOpacity = 0, this.brightness = 0});

  final double zoom;

  /// Centre of the visible window, 0 to 1 across the frame.
  final double centerX;
  final double centerY;
  final double rotation;

  /// Colour (0xRRGGBB) washed over the frame by a fade, at [overlayOpacity].
  final int? overlay;
  final double overlayOpacity;

  /// Added brightness, -1 to 1.
  final double brightness;
}

final _compiled = <String, Expr>{};
double _eval(String source, Map<String, double> vars) => (_compiled[source] ??= Expr.parse(source)).eval(vars);

/// Evaluates the effect's motion and light at [timeMs] into a clip of [durationMs].
EffectFrame effectFrameAt(ClipEffect effect, int timeMs, int durationMs, {int fps = 30}) {
  final seconds = timeMs / 1000;
  final vars = {'on': seconds * fps, 'N': (durationMs / 1000 * fps).roundToDouble().clamp(1.0, double.infinity), 't': seconds};
  final m = effect.motion;
  var zoom = 1.0, cx = .5, cy = .5, rotation = 0.0;
  if (m.moves) {
    zoom = _eval(m.zoom.replaceAll('on/30', 'on/$fps'), vars);
    final px = _eval(m.panX, vars), py = _eval(m.panY, vars);
    // zoompan places the window's left edge at (iw - iw/zoom) * px.
    cx = (1 - 1 / zoom) * px + .5 / zoom;
    cy = (1 - 1 / zoom) * py + .5 / zoom;
    if (m.rotate != null) rotation = _eval(m.rotate!, vars);
  }
  final l = effect.light;
  final clipSeconds = durationMs / 1000;
  int? overlay;
  var opacity = 0.0;
  if (l.fadeIn != null) {
    final (color, d) = l.fadeIn!;
    final len = _fadeLength(d, clipSeconds);
    if (seconds < len) {
      overlay = color;
      opacity = 1 - seconds / len;
    }
  }
  if (l.fadeOut != null) {
    final (color, d) = l.fadeOut!;
    final len = _fadeLength(d, clipSeconds);
    final start = clipSeconds - len;
    if (seconds > start) {
      overlay = color;
      opacity = ((seconds - start) / len).clamp(0.0, 1.0);
    }
  }
  final brightness = l.flicker > 0 ? l.flicker * math.sin(seconds * 40) : 0.0;
  return EffectFrame(zoom: zoom, centerX: cx, centerY: cy, rotation: rotation, overlay: overlay, overlayOpacity: opacity, brightness: brightness);
}
