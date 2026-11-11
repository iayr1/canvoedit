import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/art_image.dart';
import '../../app/theme.dart';
import '../../canvas/canvas_view.dart';
import '../../canvas/document.dart';
import '../../canvas/image_export.dart';
import '../../canvas/layer.dart';
import '../../canvas/renderer.dart';
import '../../core/artwork.dart';
import '../../core/media.dart';
import '../../core/media_picker.dart';
import '../../core/output.dart';
import '../shared/color_wheels.dart';
import '../shared/editor_chrome.dart';
import '../shared/grade_panels.dart';
import '../shared/layer_panels.dart';
import '../shared/library_sheet.dart';
import 'crop_screen.dart';
import 'editor_controller.dart';

enum _Tool { photos, filters, adjust, color, text, stickers, shapes, draw, background, layers, resize }

/// The shared editor for photos and designs. Available tools depend on the
/// document's mode.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.document});
  final CanvasDocument document;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _c = EditorController(widget.document);
  late _Tool? _tool = widget.document.isPhoto ? _Tool.filters : (widget.document.layers.any((l) => l.isFrame) ? _Tool.photos : null);
  int _drawColor = 0xFFFF5C39;

  /// Photos added this session, shown in the Photos tray for dragging into frames.
  final List<String> _tray = [];
  double _drawWidth = .012;

  @override
  void initState() {
    super.initState();
    ImageBank.instance.addListener(_c.touch);
    SceneRenderer.prepare(widget.document.layers)
        .then((_) {
          if (mounted) _c.touch();
        })
        .catchError((Object e) {
          debugPrint('Could not load all assets: $e');
        });
  }

  @override
  void dispose() {
    ImageBank.instance.removeListener(_c.touch);
    _c.flush();
    _c.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<_Tool> get _tools => _c.doc.isPhoto
      ? const [_Tool.filters, _Tool.adjust, _Tool.color, _Tool.text, _Tool.stickers, _Tool.shapes, _Tool.draw, _Tool.layers]
      : const [
          _Tool.photos,
          _Tool.text,
          _Tool.stickers,
          _Tool.shapes,
          _Tool.background,
          _Tool.filters,
          _Tool.adjust,
          _Tool.color,
          _Tool.draw,
          _Tool.layers,
          _Tool.resize,
        ];

  void _selectTool(_Tool tool) {
    setState(() => _tool = _tool == tool ? null : tool);
    if (_tool == _Tool.text && _c.selected?.kind != LayerKind.text) _addText();
  }

  Future<void> _addText() async {
    final text = await _editText('Your text');
    if (text == null || text.trim().isEmpty) return;
    _c.addLayer(CanvasLayer.text(text, color: _c.doc.isPhoto ? 0xFFFFFFFF : 0xFF111111)..shadow = _c.doc.isPhoto);
  }

  Future<String?> _editText(String initial) => showTextDialog(context, initial);

  Future<void> _editLayerText(CanvasLayer layer) async {
    final text = await _editText(layer.text);
    if (text == null || text.trim().isEmpty) return;
    layer.text = text;
    _c.commit();
  }

  List<CanvasLayer> get _frames => _c.doc.layers.where((l) => l.isFrame).toList();

  /// Fills [frame] with [path], or the selected frame, or the first empty one;
  /// with no frame at all, the photo is added as a new image.
  Future<void> _placePhoto(String path, {CanvasLayer? frame}) async {
    final selected = _c.selected;
    final target =
        frame ?? (selected != null && selected.isFrame ? selected : null) ?? _frames.where((f) => f.path == null || isArtworkPath(f.path!)).firstOrNull;
    if (target != null) {
      target.path = path;
      target.grade = target.grade.clone();
      _c.select(target.id);
      _c.commit();
      await ImageBank.instance.load(path);
      _c.touch();
      return;
    }
    final image = await ImageBank.instance.load(path);
    _c.addLayer(CanvasLayer.image(path, image.width, image.height));
  }

  Future<void> _addToTray() async {
    final files = await MediaPicker.media(onError: _snack);
    for (final file in files) {
      if (!looksLikeImage(file)) continue;
      final path = await MediaLibrary.import(file);
      if (!_tray.contains(path)) setState(() => _tray.insert(0, path));
      ImageBank.instance.load(path).ignore();
    }
  }

  Future<void> _replaceFramePhoto(CanvasLayer frame) async {
    final file = await MediaPicker.image(onError: _snack);
    if (file == null) return;
    final path = await MediaLibrary.import(file);
    if (!_tray.contains(path)) setState(() => _tray.insert(0, path));
    await _placePhoto(path, frame: frame);
  }

  Widget _photosPanel() {
    final samples = [for (final s in artScenes) s.path];
    final items = [..._tray, ...samples];
    return SizedBox(
      height: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Text(
              _frames.isEmpty ? 'Tap a photo to add it, or hold and drag it.' : 'Tap to fill a frame, or hold and drag onto one.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                GestureDetector(
                  onTap: _addToTray,
                  child: Container(
                    width: 68,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(14)),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
                        SizedBox(height: 4),
                        Text('Gallery', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                for (final path in items)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LongPressDraggable<String>(
                      data: path,
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      feedback: SizedBox(width: 72, height: 72, child: Opacity(opacity: .85, child: _TrayThumb(path))),
                      childWhenDragging: Opacity(opacity: .35, child: _TrayThumb(path)),
                      child: GestureDetector(onTap: () => _placePhoto(path), child: _TrayThumb(path)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addImage() async {
    final file = await MediaPicker.image(onError: _snack);
    if (file == null) return;
    final path = await MediaLibrary.import(file);
    final image = await ImageBank.instance.load(path);
    _c.addLayer(CanvasLayer.image(path, image.width, image.height));
  }

  Future<void> _openCrop() async {
    final target = _c.gradeTarget;
    if (target == null) {
      _snack('Select an image first');
      return;
    }
    if (target.isFrame) {
      _snack('Frames fit their photo automatically. Resize the frame to change the crop.');
      return;
    }
    final result = await Navigator.of(context).push<CanvasLayer>(MaterialPageRoute(builder: (_) => CropScreen(layer: target.clone())));
    if (result == null) return;
    target
      ..cropL = result.cropL
      ..cropT = result.cropT
      ..cropR = result.cropR
      ..cropB = result.cropB
      ..quarterTurns = result.quarterTurns
      ..flipH = result.flipH
      ..flipV = result.flipV;
    if (target.isBase) _c.doc.fitToBase();
    _c.commit();
  }

  Future<void> _export() async {
    final before = _c.doc.name;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ExportSheet(doc: _c.doc),
      ),
    );
    // The sheet may have renamed the design; keep that in the project.
    if (mounted && _c.doc.name != before) _c.commit();
  }

  Future<void> _rename() async {
    final name = await showNameDialog(
      context,
      title: _c.doc.isPhoto ? 'Name your photo' : 'Name your design',
      initial: _c.doc.name,
      hint: _c.doc.isPhoto ? 'Photo name' : 'Design name',
    );
    if (name == null) return;
    _c.doc.name = name;
    _c.commit();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final doc = _c.doc;
        return Scaffold(
          backgroundColor: AppColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.backdrop),
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = useWideEditor(box.biggest);
                  final topBar = EditorTopBar(
                    kind: doc.isPhoto ? 'Photo' : 'Design',
                    detail: '${doc.pixelWidth} × ${doc.pixelHeight}',
                    name: doc.name,
                    onRename: _rename,
                    canUndo: _c.canUndo,
                    canRedo: _c.canRedo,
                    onUndo: _c.undo,
                    onRedo: _c.redo,
                    onExport: _export,
                  );
                  final canvas = Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: CanvasView(
                      aspectRatio: doc.aspectRatio,
                      layers: doc.layers,
                      selectedId: _c.selectedId,
                      background: (canvas, size) => SceneRenderer.paintBackground(canvas, size, doc.background),
                      onSelect: _c.select,
                      onChanged: _c.touch,
                      onCommit: _c.commit,
                      onEditText: _editLayerText,
                      draw: _tool == _Tool.draw ? DrawSettings(_drawColor, _drawWidth) : null,
                      onStroke: (stroke) => _c.addLayer(stroke, select: false),
                      onDropPhoto: (path, frame) => _placePhoto(path, frame: frame),
                    ),
                  );
                  final selection = _c.selected != null && !_c.selected!.isBase ? _selectionBar(_c.selected!) : null;
                  if (wide) {
                    // Landscape and big screens: tools beside the canvas.
                    return Column(
                      children: [
                        topBar,
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(child: canvas),
                                    ?selection,
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: (box.maxWidth * .32).clamp(280.0, 420.0),
                                child: EditorSidePanel(
                                  panel: _tool == null ? null : _panel(_tool!),
                                  panelTitle: _tool == null ? null : '${_tool!.name[0].toUpperCase()}${_tool!.name.substring(1)}',
                                  onClosePanel: () => setState(() => _tool = null),
                                  tools: _toolRail(vertical: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      topBar,
                      Expanded(child: canvas),
                      ?selection,
                      if (_tool != null) _panel(_tool!),
                      _toolRail(),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _toolRail({bool vertical = false}) {
    const labels = {
      _Tool.filters: ('Filters', Icons.auto_awesome),
      _Tool.adjust: ('Adjust', Icons.tune),
      _Tool.color: ('Color', Icons.palette_outlined),
      _Tool.text: ('Text', Icons.title),
      _Tool.stickers: ('Stickers', Icons.emoji_emotions_outlined),
      _Tool.shapes: ('Shapes', Icons.category_outlined),
      _Tool.draw: ('Draw', Icons.brush_outlined),
      _Tool.background: ('Background', Icons.format_color_fill),
      _Tool.layers: ('Layers', Icons.layers_outlined),
      _Tool.resize: ('Resize', Icons.aspect_ratio),
      _Tool.photos: ('Photos', Icons.photo_library_outlined),
    };
    return ToolDock(
      vertical: vertical,
      tools: [
        for (final tool in _tools) ToolButton(icon: labels[tool]!.$2, label: labels[tool]!.$1, active: _tool == tool, onTap: () => _selectTool(tool)),
        ToolButton(icon: Icons.crop, label: 'Crop', onTap: _openCrop),
        ToolButton(icon: Icons.add_photo_alternate_outlined, label: 'Add image', onTap: _addImage),
      ],
    );
  }

  Widget _selectionBar(CanvasLayer l) {
    return Container(
      height: 44,
      color: AppColors.surfaceHigh,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (l.kind == LayerKind.text) IconButton(tooltip: 'Edit text', icon: const Icon(Icons.edit, size: 20), onPressed: () => _editLayerText(l)),
          if (l.isFrame)
            IconButton(tooltip: 'Replace photo', icon: const Icon(Icons.add_photo_alternate_outlined, size: 20), onPressed: () => _replaceFramePhoto(l)),
          if (l.isFrame && l.path != null)
            IconButton(
              tooltip: 'Remove photo',
              icon: const Icon(Icons.hide_image_outlined, size: 20),
              onPressed: () {
                l.path = null;
                _c.commit();
              },
            ),
          IconButton(tooltip: 'Duplicate', icon: const Icon(Icons.copy, size: 20), onPressed: _c.duplicateSelected),
          IconButton(tooltip: 'Bring forward', icon: const Icon(Icons.flip_to_front, size: 20), onPressed: () => _c.moveLayer(l, 1)),
          IconButton(tooltip: 'Send backward', icon: const Icon(Icons.flip_to_back, size: 20), onPressed: () => _c.moveLayer(l, -1)),
          IconButton(
            tooltip: l.locked ? 'Unlock' : 'Lock',
            icon: Icon(l.locked ? Icons.lock : Icons.lock_open, size: 20),
            onPressed: () {
              l.locked = !l.locked;
              _c.commit();
            },
          ),
          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 20), onPressed: _c.deleteSelected),
          SizedBox(
            width: 170,
            child: Slider(
              value: l.opacity,
              onChanged: (v) {
                l.opacity = v;
                _c.touch();
              },
              onChangeEnd: (_) => _c.commit(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(_Tool tool) {
    switch (tool) {
      case _Tool.color:
        final target = _c.gradeTarget;
        if (target == null) return const _Hint('Select an image on the canvas to use this tool.');
        return ColorWheelsPanel(key: ValueKey('wheels-${target.id}'), grade: target.grade, onChanged: _c.touch, onCommit: _c.commit);
      case _Tool.filters:
      case _Tool.adjust:
        final target = _c.gradeTarget;
        if (target == null) {
          return const _Hint('Select an image on the canvas to use this tool.');
        }
        if (tool == _Tool.adjust) {
          return AdjustPanel(grade: target.grade, onChanged: _c.touch, onCommit: _c.commit);
        }
        final image = target.path == null ? null : ImageBank.instance.peek(target.path!);
        return FilterStrip(
          grade: target.grade,
          thumbnail: image == null ? ArtImage(artScenes.first) : RawImage(image: image, fit: BoxFit.cover),
          onChanged: _c.touch,
          onCommit: _c.commit,
        );
      case _Tool.text:
        final l = _c.selected;
        if (l == null || l.kind != LayerKind.text) {
          return const _Hint('Select a text layer, or tap Text to add one.');
        }
        return TextStylePanel(
          layer: l,
          onCommit: _c.commit,
          onFontReady: () {
            if (mounted) _c.touch();
          },
          onFontFailed: () {
            if (mounted) _snack('Could not download that font');
          },
        );
      case _Tool.stickers:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: 'All stickers',
                      icon: Icons.emoji_emotions_rounded,
                      compact: true,
                      onPressed: () => showLibrarySheet<void>(
                        context,
                        (sheet) => StickerBrowser(
                          onPick: (item) {
                            Navigator.pop(sheet);
                            _c.addLayer(item.toLayer());
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GradientButton(
                      label: 'Designer words',
                      icon: Icons.auto_awesome,
                      compact: true,
                      gradient: AppGradients.ocean,
                      onPressed: () => showLibrarySheet<void>(
                        context,
                        (sheet) => WordBrowser(
                          onPick: (word) {
                            Navigator.pop(sheet);
                            final layer = word.toLayer();
                            _c.addLayer(layer);
                            SceneRenderer.prepare([layer])
                                .then((_) {
                                  if (mounted) _c.touch();
                                })
                                .catchError((Object _) {});
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            StickerGrid(onPick: (s) => _c.addLayer(CanvasLayer.sticker(s))),
          ],
        );
      case _Tool.shapes:
        return _shapesPanel();
      case _Tool.draw:
        return Column(
          children: [
            SwatchRow(selected: _drawColor, onPick: (c) => setState(() => _drawColor = c!)),
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text('Brush', style: TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: Slider(min: .003, max: .06, value: _drawWidth, onChanged: (v) => setState(() => _drawWidth = v)),
                ),
              ],
            ),
          ],
        );
      case _Tool.background:
        return _backgroundPanel();
      case _Tool.layers:
        return _layersPanel();
      case _Tool.photos:
        return _photosPanel();
      case _Tool.resize:
        return SizedBox(
          height: 120,
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final p in canvasSizePresets)
                    ActionChip(
                      label: Text(p.name, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _c.resizeCanvas(p.width, p.height),
                    ),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _shapesPanel() {
    final selected = _c.selected;
    final isShape = selected?.kind == LayerKind.shape;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final kind in ShapeKind.values)
                InkWell(
                  onTap: () => _c.addLayer(CanvasLayer.shape(kind)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: CustomPaint(size: const Size(36, 36), painter: _ShapeIcon(kind)),
                  ),
                ),
            ],
          ),
        ),
        if (isShape)
          SwatchRow(
            selected: selected!.color,
            onPick: (c) {
              selected.color = c!;
              _c.commit();
            },
          ),
      ],
    );
  }

  Widget _backgroundPanel() {
    final bg = _c.doc.background;
    const gradients = [
      (0xFFFF5C39, 0xFF7C1D6F),
      (0xFF0EA5E9, 0xFF7C5CFF),
      (0xFFFDE68A, 0xFFF472B6),
      (0xFF14B8A6, 0xFF0F172A),
      (0xFFFFD6E0, 0xFFC1E1FF),
      (0xFF111827, 0xFF374151),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwatchRow(
          selected: bg.color2 == null ? bg.color : null,
          onPick: (c) {
            bg
              ..color = c!
              ..color2 = null;
            _c.commit();
          },
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final g in gradients)
                GestureDetector(
                  onTap: () {
                    bg
                      ..color = g.$1
                      ..color2 = g.$2;
                    _c.commit();
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(colors: [Color(g.$1), Color(g.$2)]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _layersPanel() {
    final layers = _c.doc.layers.reversed.toList();
    return SizedBox(
      height: 190,
      child: layers.isEmpty
          ? const _Hint('No layers yet.')
          : ListView.builder(
              itemCount: layers.length,
              itemBuilder: (context, i) {
                final l = layers[i];
                return ListTile(
                  dense: true,
                  selected: l.id == _c.selectedId,
                  leading: Icon(_layerIcon(l.kind), size: 20),
                  title: Text(l.isTextual && l.text.isNotEmpty ? l.text.replaceAll('\n', ' ') : l.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _c.select(l.kind == LayerKind.stroke ? null : l.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Move up',
                        icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                        onPressed: l.isBase ? null : () => _c.moveLayer(l, 1),
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        onPressed: l.isBase ? null : () => _c.moveLayer(l, -1),
                      ),
                      IconButton(
                        tooltip: l.visible ? 'Hide' : 'Show',
                        icon: Icon(l.visible ? Icons.visibility : Icons.visibility_off, size: 20),
                        onPressed: () {
                          l.visible = !l.visible;
                          _c.commit();
                        },
                      ),
                      if (!l.isBase)
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () {
                            _c.doc.layers.remove(l);
                            if (_c.selectedId == l.id) _c.selectedId = null;
                            _c.commit();
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  IconData _layerIcon(LayerKind kind) => switch (kind) {
    LayerKind.text => Icons.title,
    LayerKind.sticker => Icons.emoji_emotions_outlined,
    LayerKind.shape => Icons.category_outlined,
    LayerKind.image => Icons.image_outlined,
    LayerKind.stroke => Icons.brush_outlined,
  };
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: Text(text, style: const TextStyle(color: AppColors.muted)),
    ),
  );
}

class _ShapeIcon extends CustomPainter {
  _ShapeIcon(this.kind);
  final ShapeKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final paint = Paint()..color = Colors.white;
    if (kind == ShapeKind.line) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
    }
    canvas.drawPath(SceneRenderer.shapePath(kind, size), paint);
  }

  @override
  bool shouldRepaint(covariant _ShapeIcon old) => old.kind != kind;
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.doc});
  final CanvasDocument doc;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  double _scale = 1;
  ImageExportFormat _format = ImageExportFormat.png;
  bool _busy = false;
  String? _message;

  late final _name = TextEditingController(text: widget.doc.name);

  String get _fileName => '${fileSafeName(widget.doc.name)}.${_format.extension}';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(Uint8List bytes) action, String done) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await exportDocument(widget.doc, _format, scale: _scale);
      await action(bytes);
      if (mounted) setState(() => _message = done);
    } catch (e) {
      if (mounted) setState(() => _message = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = (widget.doc.pixelWidth * _scale).round(), h = (widget.doc.pixelHeight * _scale).round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.doc.isPhoto ? 'Save your photo' : 'Save your design', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            NameField(
              controller: _name,
              hint: widget.doc.isPhoto ? 'Photo name' : 'Design name',
              onChanged: (v) {
                if (v.trim().isNotEmpty) widget.doc.name = v.trim();
              },
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            SegmentedButton<ImageExportFormat>(
              segments: [for (final f in ImageExportFormat.values) ButtonSegment(value: f, label: Text(f.label))],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: .5, label: Text('0.5x')),
                ButtonSegment(value: 1, label: Text('1x')),
                ButtonSegment(value: 2, label: Text('2x')),
              ],
              selected: {_scale},
              onSelectionChanged: (s) => setState(() => _scale = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              '$w × $h px',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            if (_format != ImageExportFormat.pdf) ...[
              FilledButton.icon(
                onPressed: _busy ? null : () => _run((b) => Output.saveImage(b, _fileName), 'Saved to your gallery'),
                icon: const Icon(Icons.download),
                label: const Text('Save to gallery'),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run((b) => Output.shareBytes(b, _fileName), 'Shared'),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrayThumb extends StatefulWidget {
  const _TrayThumb(this.path);
  final String path;

  @override
  State<_TrayThumb> createState() => _TrayThumbState();
}

class _TrayThumbState extends State<_TrayThumb> {
  @override
  void initState() {
    super.initState();
    if (ImageBank.instance.peek(widget.path) == null) {
      ImageBank.instance.load(widget.path).then((_) {
        if (mounted) setState(() {});
      }).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = ImageBank.instance.peek(widget.path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 68,
        height: 68,
        child: image == null ? const ColoredBox(color: AppColors.surfaceHigh) : RawImage(image: image, fit: BoxFit.cover),
      ),
    );
  }
}
