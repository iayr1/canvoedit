import 'dart:async';
import 'dart:io' show Directory, File, FileSystemException;
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
    return store(File(file.path), name, dir, cache: await getTemporaryDirectory());
  }

  /// Copies [source] into [dir], or reuses an identical file already there.
  /// Pickers hand back their own copy in the app cache, which is removed once
  /// stored so that a video does not take up its space twice.
  @visibleForTesting
  static Future<String> store(File source, String name, Directory dir, {Directory? cache}) async {
    var target = await _findIdentical(source, dir);
    if (target == null) {
      final ext = name.contains('.') ? '.${name.split('.').last}' : '';
      target = '${dir.path}/${newId()}$ext';
      await source.copy(target);
    }
    if (cache != null && _isInside(source.path, cache.path)) {
      try {
        await source.delete();
      } on FileSystemException catch (e) {
        debugPrint('Could not remove cached pick: $e');
      }
    }
    return target;
  }

  static bool _isInside(String path, String dir) =>
      path.replaceAll(r'\', '/').startsWith('${dir.replaceAll(r'\', '/')}/');

  static Future<String?> _findIdentical(File source, Directory dir) async {
    final length = await source.length();
    await for (final item in dir.list()) {
      if (item is File && await item.length() == length && await _sameBytes(source, item)) {
        return item.path;
      }
    }
    return null;
  }

  /// Compares whole files, because reusing a file that merely looks the same
  /// would silently put the wrong video in a project. Only same-sized files get
  /// this far, so it rarely runs.
  static Future<bool> _sameBytes(File a, File b) async {
    const chunk = 1 << 20;
    final ra = await a.open(), rb = await b.open();
    try {
      while (true) {
        final x = await ra.read(chunk), y = await rb.read(chunk);
        if (x.length != y.length) return false;
        if (x.isEmpty) return true;
        for (var i = 0; i < x.length; i++) {
          if (x[i] != y[i]) return false;
        }
      }
    } finally {
      await ra.close();
      await rb.close();
    }
  }

  /// Frees storage from imports no project uses and from finished exports.
  static Future<void> cleanUp() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      await deleteUnusedMedia(Directory('${docs.path}/media'), Directory('${docs.path}/projects'));
      final temp = await getTemporaryDirectory();
      await for (final item in temp.list()) {
        final name = item.path.replaceAll(r'\', '/').split('/').last;
        if (item is Directory && name.startsWith('export-')) await item.delete(recursive: true);
      }
    } on FileSystemException catch (e) {
      debugPrint('Storage clean-up skipped: $e');
    }
  }

  /// Deletes files in [media] that no project mentions, and returns how many.
  ///
  /// This searches each project's raw text rather than parsing it, so a project
  /// too damaged to open still keeps its files, and any project that can't be
  /// read cancels the clean-up. Recent files are skipped because an editor may
  /// have imported one that it hasn't saved yet.
  @visibleForTesting
  static Future<int> deleteUnusedMedia(
    Directory media,
    Directory projects, {
    Duration grace = const Duration(minutes: 10),
    DateTime? now,
  }) async {
    if (!await media.exists()) return 0;
    final texts = <String>[];
    if (await projects.exists()) {
      await for (final item in projects.list()) {
        if (item is File && item.path.endsWith('.json')) {
          texts.add(await item.readAsString());
        }
      }
    }
    final cutoff = (now ?? DateTime.now()).subtract(grace);
    var deleted = 0;
    await for (final item in media.list()) {
      if (item is! File) continue;
      final fileName = item.path.replaceAll(r'\', '/').split('/').last;
      final used = texts.any((t) => t.contains(fileName));
      if (used || (await item.lastModified()).isAfter(cutoff)) continue;
      await item.delete();
      deleted++;
    }
    return deleted;
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
