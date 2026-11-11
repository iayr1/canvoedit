import '../core/color/grade.dart';
import '../core/media.dart';

enum LayerKind { text, sticker, shape, image, stroke }

enum ShapeKind { rectangle, rounded, circle, triangle, star, heart, hexagon, line, arch }

/// One element on a canvas. Positions and sizes are fractions of the canvas
/// width and height, so a design renders identically at any resolution.
class CanvasLayer {
  CanvasLayer({required this.kind, String? id, this.name = ''}) : id = id ?? newId();

  factory CanvasLayer.text(String text, {String font = 'Poppins', double size = .08, int color = 0xFFFFFFFF}) => CanvasLayer(kind: LayerKind.text, name: 'Text')
    ..text = text
    ..fontFamily = font
    ..fontSize = size
    ..color = color;

  factory CanvasLayer.sticker(String emoji) => CanvasLayer(kind: LayerKind.sticker, name: 'Sticker')
    ..text = emoji
    ..fontSize = .18;

  factory CanvasLayer.shape(ShapeKind shape, {int fill = 0xFFFF5C39, double width = .4, double aspect = 1}) => CanvasLayer(kind: LayerKind.shape, name: 'Shape')
    ..shape = shape
    ..color = fill
    ..width = width
    ..aspect = aspect;

  factory CanvasLayer.image(String path, int imageWidth, int imageHeight, {double width = .6}) => CanvasLayer(kind: LayerKind.image, name: 'Image')
    ..path = path
    ..imgW = imageWidth
    ..imgH = imageHeight
    ..width = width;

  /// A photo frame: a fixed shape that a picture fills, cropped to fit. With no
  /// [path] it shows a placeholder inviting the user to add a photo.
  factory CanvasLayer.frame({String? path, ShapeKind mask = ShapeKind.rectangle, double width = .5, double aspect = 1}) =>
      CanvasLayer(kind: LayerKind.image, name: 'Photo frame')
        ..isFrame = true
        ..path = path
        ..shape = mask
        ..width = width
        ..aspect = aspect;

  factory CanvasLayer.stroke(List<double> points, int color, double strokeWidth) => CanvasLayer(kind: LayerKind.stroke, name: 'Drawing')
    ..points = points
    ..color = color
    ..strokeWidth = strokeWidth;

  factory CanvasLayer.fromJson(Map<String, dynamic> j) {
    double d(String k, double fallback) => (j[k] as num?)?.toDouble() ?? fallback;
    return CanvasLayer(kind: LayerKind.values.byName(j['kind'] as String), id: j['id'] as String, name: j['name'] as String? ?? '')
      ..cx = d('cx', .5)
      ..cy = d('cy', .5)
      ..width = d('width', .5)
      ..rotation = d('rotation', 0)
      ..opacity = d('opacity', 1)
      ..visible = j['visible'] as bool? ?? true
      ..locked = j['locked'] as bool? ?? false
      ..isBase = j['isBase'] as bool? ?? false
      ..isFrame = j['isFrame'] as bool? ?? false
      ..startMs = j['startMs'] as int?
      ..endMs = j['endMs'] as int?
      ..text = j['text'] as String? ?? ''
      ..fontFamily = j['fontFamily'] as String? ?? 'Poppins'
      ..fontSize = d('fontSize', .08)
      ..color = j['color'] as int? ?? 0xFFFFFFFF
      ..bold = j['bold'] as bool? ?? false
      ..italic = j['italic'] as bool? ?? false
      ..align = j['align'] as int? ?? 1
      ..letterSpacing = d('letterSpacing', 0)
      ..shadow = j['shadow'] as bool? ?? false
      ..bgColor = j['bgColor'] as int?
      ..bgStyle = j['bgStyle'] as int? ?? 0
      ..gradient = (j['gradient'] as List?)?.map((e) => e as int).toList()
      ..glowColor = j['glowColor'] as int?
      ..popColor = j['popColor'] as int?
      ..shape = ShapeKind.values.byName(j['shape'] as String? ?? 'rectangle')
      ..aspect = d('aspect', 1)
      ..strokeColor = j['strokeColor'] as int?
      ..strokeWidth = d('strokeWidth', .01)
      ..path = j['path'] as String?
      ..imgW = j['imgW'] as int? ?? 1
      ..imgH = j['imgH'] as int? ?? 1
      ..grade = Grade.fromJson((j['grade'] as Map?)?.cast<String, dynamic>())
      ..cropL = d('cropL', 0)
      ..cropT = d('cropT', 0)
      ..cropR = d('cropR', 1)
      ..cropB = d('cropB', 1)
      ..quarterTurns = j['quarterTurns'] as int? ?? 0
      ..flipH = j['flipH'] as bool? ?? false
      ..flipV = j['flipV'] as bool? ?? false
      ..points = (j['points'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
  }

  final String id;
  final LayerKind kind;
  String name;

  double cx = .5;
  double cy = .5;

  /// Width as a fraction of canvas width, for shapes and images.
  double width = .5;
  double rotation = 0;
  double opacity = 1;
  bool visible = true;
  bool locked = false;

  /// True for the full-frame photo in photo-editing mode.
  bool isBase = false;

  /// True for photo frames, which keep their own shape and size whatever picture
  /// fills them. [shape] is the frame's outline and [aspect] its proportions.
  bool isFrame = false;

  /// Visible time range in video projects. Null means the whole timeline.
  int? startMs;
  int? endMs;

  // Text and stickers.
  String text = '';
  String fontFamily = 'Poppins';

  /// Font size as a fraction of canvas width.
  double fontSize = .08;
  int color = 0xFFFFFFFF;
  bool bold = false;
  bool italic = false;

  /// 0 left, 1 center, 2 right.
  int align = 1;
  double letterSpacing = 0;
  bool shadow = false;
  int? bgColor;

  /// Background shape behind text: 0 rounded box, 1 pill, 2 square, 3 slanted tag.
  int bgStyle = 0;

  /// Text fill gradient, top to bottom. Replaces [color] when set.
  List<int>? gradient;

  /// Neon glow colour around text.
  int? glowColor;

  /// Colour of a hard offset shadow behind text, for a pop-art look.
  int? popColor;

  // Text outline: [strokeColor], with [strokeWidth] as a fraction of font size.

  // Shapes.
  ShapeKind shape = ShapeKind.rectangle;

  /// Height divided by width.
  double aspect = 1;
  int? strokeColor;
  double strokeWidth = .01;

  // Images.
  String? path;
  int imgW = 1;
  int imgH = 1;
  Grade grade = Grade();
  double cropL = 0;
  double cropT = 0;
  double cropR = 1;
  double cropB = 1;
  int quarterTurns = 0;
  bool flipH = false;
  bool flipV = false;

  // Freehand strokes: x,y pairs as fractions of canvas width and height.
  List<double> points = [];

  bool get isTextual => kind == LayerKind.text || kind == LayerKind.sticker;

  /// Height divided by width of the image after crop and rotation.
  double get imageAspect {
    final w = imgW * (cropR - cropL);
    final h = imgH * (cropB - cropT);
    return quarterTurns.isOdd ? w / h : h / w;
  }

  bool isVisibleAt(int? timeMs) {
    if (!visible) return false;
    if (timeMs == null) return true;
    if (startMs != null && timeMs < startMs!) return false;
    if (endMs != null && timeMs > endMs!) return false;
    return true;
  }

  CanvasLayer clone({bool newIdentity = false}) {
    final copy = CanvasLayer.fromJson(toJson());
    if (!newIdentity) return copy;
    final json = copy.toJson()..['id'] = newId();
    return CanvasLayer.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'name': name,
    'cx': cx,
    'cy': cy,
    'width': width,
    'rotation': rotation,
    'opacity': opacity,
    'visible': visible,
    'locked': locked,
    'isBase': isBase,
    'isFrame': isFrame,
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'color': color,
    'bold': bold,
    'italic': italic,
    'align': align,
    'letterSpacing': letterSpacing,
    'shadow': shadow,
    'bgColor': bgColor,
    'bgStyle': bgStyle,
    'gradient': gradient,
    'glowColor': glowColor,
    'popColor': popColor,
    'shape': shape.name,
    'aspect': aspect,
    'strokeColor': strokeColor,
    'strokeWidth': strokeWidth,
    'path': path,
    'imgW': imgW,
    'imgH': imgH,
    'grade': grade.toJson(),
    'cropL': cropL,
    'cropT': cropT,
    'cropR': cropR,
    'cropB': cropB,
    'quarterTurns': quarterTurns,
    'flipH': flipH,
    'flipV': flipV,
    'points': points,
  };
}
