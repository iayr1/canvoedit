import '../core/media.dart';
import 'layer.dart';

class CanvasBackground {
  CanvasBackground(this.color, {this.color2, this.angle = 90});

  factory CanvasBackground.fromJson(Map<String, dynamic> j) => CanvasBackground(
    j['color'] as int,
    color2: j['color2'] as int?,
    angle: (j['angle'] as num?)?.toDouble() ?? 90,
  );

  int color;
  int? color2;

  /// Gradient direction in degrees.
  double angle;

  Map<String, dynamic> toJson() => {'color': color, 'color2': color2, 'angle': angle};
}

/// A design or photo project.
class CanvasDocument {
  CanvasDocument({
    String? id,
    this.name = 'Untitled',
    this.isPhoto = false,
    required this.pixelWidth,
    required this.pixelHeight,
    CanvasBackground? background,
    List<CanvasLayer>? layers,
  }) : id = id ?? newId(),
       background = background ?? CanvasBackground(0xFFFFFFFF),
       layers = layers ?? [];

  factory CanvasDocument.fromJson(Map<String, dynamic> j) => CanvasDocument(
    id: j['id'] as String,
    name: j['name'] as String,
    isPhoto: j['isPhoto'] as bool? ?? false,
    pixelWidth: j['pixelWidth'] as int,
    pixelHeight: j['pixelHeight'] as int,
    background: CanvasBackground.fromJson((j['background'] as Map).cast<String, dynamic>()),
    layers: (j['layers'] as List)
        .map((e) => CanvasLayer.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  final String id;
  String name;
  bool isPhoto;
  int pixelWidth;
  int pixelHeight;
  CanvasBackground background;
  List<CanvasLayer> layers;

  double get aspectRatio => pixelWidth / pixelHeight;

  CanvasLayer? get baseLayer {
    for (final l in layers) {
      if (l.isBase) return l;
    }
    return null;
  }

  /// In photo mode the canvas tracks the photo, so re-derive its size after a
  /// crop or rotation.
  void fitToBase() {
    final base = baseLayer;
    if (base == null) return;
    final cropW = base.imgW * (base.cropR - base.cropL);
    final cropH = base.imgH * (base.cropB - base.cropT);
    pixelWidth = (base.quarterTurns.isOdd ? cropH : cropW).round().clamp(1, 8192);
    pixelHeight = (base.quarterTurns.isOdd ? cropW : cropH).round().clamp(1, 8192);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isPhoto': isPhoto,
    'pixelWidth': pixelWidth,
    'pixelHeight': pixelHeight,
    'background': background.toJson(),
    'layers': layers.map((l) => l.toJson()).toList(),
  };
}

class CanvasSizePreset {
  const CanvasSizePreset(this.name, this.width, this.height);
  final String name;
  final int width;
  final int height;
}

const canvasSizePresets = <CanvasSizePreset>[
  CanvasSizePreset('Instagram post', 1080, 1080),
  CanvasSizePreset('Portrait post', 1080, 1350),
  CanvasSizePreset('Story / Reel', 1080, 1920),
  CanvasSizePreset('YouTube thumbnail', 1280, 720),
  CanvasSizePreset('Facebook post', 1200, 630),
  CanvasSizePreset('Poster (A3)', 3508, 4961),
  CanvasSizePreset('Document (A4)', 2480, 3508),
  CanvasSizePreset('Business card', 1050, 600),
  CanvasSizePreset('Presentation', 1920, 1080),
  CanvasSizePreset('Logo', 1000, 1000),
];
