import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../canvas/canvas_view.dart';
import '../../canvas/document.dart';
import '../../canvas/layer.dart';
import '../../canvas/renderer.dart';
import '../../core/media.dart';
import '../../core/output.dart';
import '../shared/grade_panels.dart';
import '../shared/layer_panels.dart';
import 'crop_screen.dart';
import 'editor_controller.dart';

enum _Tool { filters, adjust, text, stickers, shapes, draw, background, layers, resize }

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
  final _picker = ImagePicker();
  late _Tool? _tool = widget.document.isPhoto ? _Tool.filters : null;
  int _drawColor = 0xFFFF5C39;
  double _drawWidth = .012;

  @override
  void initState() {
    super.initState();
    ImageBank.instance.addListener(_c.touch);
    SceneRenderer.prepare(widget.document.layers).then((_) {
      if (mounted) _c.touch();
    }).catchError((Object e) {
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
      ? const [_Tool.filters, _Tool.adjust, _Tool.text, _Tool.stickers, _Tool.shapes, _Tool.draw, _Tool.layers]
      : const [_Tool.text, _Tool.stickers, _Tool.shapes, _Tool.background, _Tool.filters, _Tool.adjust, _Tool.draw, _Tool.layers, _Tool.resize];

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

  Future<void> _addImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
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
    final result = await Navigator.of(context).push<CanvasLayer>(
      MaterialPageRoute(builder: (_) => CropScreen(layer: target.clone())),
    );
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ExportSheet(doc: _c.doc),
    );
  }

  Future<void> _rename() async {
    final field = TextEditingController(text: _c.doc.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Project name'),
        content: TextField(controller: field, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, field.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      _c.doc.name = name.trim();
      _c.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final doc = _c.doc;
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(onTap: _rename, child: Text(doc.name, overflow: TextOverflow.ellipsis)),
            actions: [
              IconButton(tooltip: 'Undo', onPressed: _c.canUndo ? _c.undo : null, icon: const Icon(Icons.undo)),
              IconButton(tooltip: 'Redo', onPressed: _c.canRedo ? _c.redo : null, icon: const Icon(Icons.redo)),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(onPressed: _export, child: const Text('Export')),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                    ),
                  ),
                ),
                if (_c.selected != null && !_c.selected!.isBase) _selectionBar(_c.selected!),
                if (_tool != null) _panel(_tool!),
                _toolRail(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _toolRail() {
    const labels = {
      _Tool.filters: ('Filters', Icons.auto_awesome),
      _Tool.adjust: ('Adjust', Icons.tune),
      _Tool.text: ('Text', Icons.title),
      _Tool.stickers: ('Stickers', Icons.emoji_emotions_outlined),
      _Tool.shapes: ('Shapes', Icons.category_outlined),
      _Tool.draw: ('Draw', Icons.brush_outlined),
      _Tool.background: ('Background', Icons.format_color_fill),
      _Tool.layers: ('Layers', Icons.layers_outlined),
      _Tool.resize: ('Resize', Icons.aspect_ratio),
    };
    return Container(
      height: 66,
      color: AppColors.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          for (final tool in _tools)
            ToolButton(
              icon: labels[tool]!.$2,
              label: labels[tool]!.$1,
              active: _tool == tool,
              onTap: () => _selectTool(tool),
            ),
          ToolButton(icon: Icons.crop, label: 'Crop', onTap: _openCrop),
          ToolButton(icon: Icons.add_photo_alternate_outlined, label: 'Add image', onTap: _addImage),
        ],
      ),
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
          thumbnail: image == null ? const ColoredBox(color: AppColors.surfaceHigh) : RawImage(image: image, fit: BoxFit.cover),
          onChanged: _c.touch,
          onCommit: _c.commit,
        );
      case _Tool.text:
        final l = _c.selected;
        if (l == null || l.kind != LayerKind.text) {
          return const _Hint('Select a text layer, or tap Text to add one.');
        }
        return TextStylePanel(layer: l, onCommit: _c.commit, onFontReady: () {
          if (mounted) _c.touch();
        }, onFontFailed: () {
          if (mounted) _snack('Could not download that font');
        });
      case _Tool.stickers:
        return StickerGrid(onPick: (s) => _c.addLayer(CanvasLayer.sticker(s)));
      case _Tool.shapes:
        return _shapesPanel();
      case _Tool.draw:
        return Column(
          children: [
            SwatchRow(selected: _drawColor, onPick: (c) => setState(() => _drawColor = c!)),
            Row(
              children: [
                const Padding(padding: EdgeInsets.only(left: 12), child: Text('Brush', style: TextStyle(fontSize: 12))),
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
                  title: Text(
                    l.isTextual && l.text.isNotEmpty ? l.text.replaceAll('\n', ' ') : l.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    child: Center(child: Text(text, style: const TextStyle(color: AppColors.muted))),
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
  bool _busy = false;
  String? _message;

  String get _fileName => '${widget.doc.name.replaceAll(RegExp(r'[^\w-]+'), '_')}.png';

  Future<void> _run(Future<void> Function(Uint8List bytes) action, String done) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await SceneRenderer.exportPng(widget.doc, scale: _scale);
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
            const Text('Export PNG', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
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
            Text('$w × $h px', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : () => _run((b) => Output.saveImage(b, _fileName), 'Saved to your gallery'),
              icon: const Icon(Icons.download),
              label: const Text('Save to gallery'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run((b) => Output.shareBytes(b, _fileName), 'Shared'),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
