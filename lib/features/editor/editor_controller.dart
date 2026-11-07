import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../canvas/document.dart';
import '../../canvas/layer.dart';
import '../../canvas/renderer.dart';
import '../../core/history.dart';
import '../../core/project_store.dart';

/// Holds a photo or design document along with its selection and undo history,
/// and autosaves shortly after each completed edit.
class EditorController extends ChangeNotifier {
  EditorController(this.doc) : _history = History(jsonEncode(doc.toJson()));

  CanvasDocument doc;
  final History _history;
  String? selectedId;
  Timer? _saveTimer;
  bool _dirty = false;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  CanvasLayer? get selected {
    for (final l in doc.layers) {
      if (l.id == selectedId) return l;
    }
    return null;
  }

  /// The image the filter and adjust tools act on: the selected image, else the
  /// base photo.
  CanvasLayer? get gradeTarget {
    final s = selected;
    if (s != null && s.kind == LayerKind.image) return s;
    return doc.baseLayer;
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  /// Repaint for an in-progress change, such as a slider drag.
  void touch() => notifyListeners();

  /// Record a finished edit as one undo step.
  void commit() {
    _history.push(jsonEncode(doc.toJson()));
    commitless();
  }

  void undo() => _restore(_history.undo());
  void redo() => _restore(_history.redo());

  void _restore(String? snapshot) {
    if (snapshot == null) return;
    doc = CanvasDocument.fromJson(jsonDecode(snapshot) as Map<String, dynamic>);
    if (selected == null) selectedId = null;
    commitless();
  }

  /// Notifies and schedules a save without adding an undo step.
  void commitless() {
    _dirty = true;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), save);
  }

  void addLayer(CanvasLayer layer, {bool select = true}) {
    doc.layers.add(layer);
    if (select && layer.kind != LayerKind.stroke) selectedId = layer.id;
    commit();
  }

  void deleteSelected() {
    final s = selected;
    if (s == null || s.isBase) return;
    doc.layers.remove(s);
    selectedId = null;
    commit();
  }

  void duplicateSelected() {
    final s = selected;
    if (s == null || s.isBase) return;
    final copy = s.clone(newIdentity: true)
      ..cx = (s.cx + .04).clamp(0, 1)
      ..cy = (s.cy + .04).clamp(0, 1);
    doc.layers.insert(doc.layers.indexOf(s) + 1, copy);
    selectedId = copy.id;
    commit();
  }

  /// Moves a layer through the stack. Nothing can go beneath the base photo.
  void moveLayer(CanvasLayer layer, int delta) {
    if (layer.isBase) return;
    final from = doc.layers.indexOf(layer);
    final floor = doc.baseLayer == null ? 0 : 1;
    final to = (from + delta).clamp(floor, doc.layers.length - 1);
    if (to == from) return;
    doc.layers
      ..removeAt(from)
      ..insert(to, layer);
    commit();
  }

  void resizeCanvas(int width, int height) {
    doc
      ..pixelWidth = width
      ..pixelHeight = height;
    commit();
  }

  /// Saves pending edits. Opening a project without changing it saves nothing,
  /// so browsing templates does not fill the project list.
  Future<void> flush() async {
    if (_dirty) await save();
  }

  Future<void> save() async {
    _dirty = false;
    Uint8List? thumb;
    try {
      thumb = await SceneRenderer.exportPng(doc, scale: 360 / doc.pixelWidth);
    } catch (e) {
      debugPrint('Thumbnail failed: $e');
    }
    await ProjectStore.instance.save(
      ProjectEntry(
        id: doc.id,
        name: doc.name,
        type: doc.isPhoto ? ProjectType.photo : ProjectType.design,
        updatedAt: DateTime.now(),
        data: doc.toJson(),
        thumbnail: thumb,
      ),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
