import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'bmp'};

bool looksLikeImage(XFile file) {
  final mime = file.mimeType;
  if (mime != null) return mime.startsWith('image/');
  final name = file.name.isNotEmpty ? file.name : file.path;
  return _imageExtensions.contains(name.split('.').last.toLowerCase());
}

/// Copies picked files into app storage, because picker results can live in a
/// cache the OS may clear while a project still refers to them.
class MediaLibrary {
  static Future<String> import(XFile file) async {
    if (kIsWeb) return file.path;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/media');
    await dir.create(recursive: true);
    final name = file.name.isNotEmpty ? file.name : file.path.split('/').last;
    final ext = name.contains('.') ? '.${name.split('.').last}' : '';
    final target = '${dir.path}/${newId()}$ext';
    await File(file.path).copy(target);
    return target;
  }

  static Future<Directory> workDir(String name) async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/$name');
    await dir.create(recursive: true);
    return dir;
  }
}

/// Decodes and caches images used by the renderer, and notifies when one is
/// ready so canvases can repaint.
class ImageBank extends ChangeNotifier {
  ImageBank._();
  static final ImageBank instance = ImageBank._();

  static const _maxEdge = 4096;
  final Map<String, ui.Image> _images = {};
  final Map<String, Future<ui.Image>> _pending = {};

  ui.Image? peek(String path) => _images[path];

  void put(String path, ui.Image image) {
    _images[path] = image;
    notifyListeners();
  }

  Future<ui.Image> load(String path) =>
      _images.containsKey(path)
          ? Future.value(_images[path])
          : _pending[path] ??= _decode(path);

  Future<ui.Image> _decode(String path) async {
    try {
      final bytes = await XFile(path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (w, h) {
          if (w <= _maxEdge && h <= _maxEdge) return const ui.TargetImageSize();
          return w >= h
              ? const ui.TargetImageSize(width: _maxEdge)
              : const ui.TargetImageSize(height: _maxEdge);
        },
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      _images[path] = frame.image;
      notifyListeners();
      return frame.image;
    } finally {
      unawaited(_pending.remove(path));
    }
  }
}
