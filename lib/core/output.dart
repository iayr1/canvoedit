import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Delivers finished exports to the device gallery or the share sheet. On web,
/// where there is no gallery, it falls back to a browser download.
class Output {
  static Future<void> saveImage(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      await XFile.fromData(bytes, name: fileName, mimeType: _mime(fileName)).saveTo(fileName);
      return;
    }
    await _ensureAccess();
    await Gal.putImageBytes(bytes, name: fileName.split('.').first, album: 'Canvo Edit');
  }

  static Future<void> saveVideo(String path) async {
    await _ensureAccess();
    await Gal.putVideo(path, album: 'Canvo Edit');
  }

  static Future<void> shareBytes(Uint8List bytes, String fileName) => SharePlus.instance.share(
    ShareParams(files: [XFile.fromData(bytes, name: fileName, mimeType: _mime(fileName))]),
  );

  static Future<void> shareFile(String path) =>
      SharePlus.instance.share(ShareParams(files: [XFile(path)]));

  static Future<void> _ensureAccess() async {
    if (!await Gal.hasAccess(toAlbum: true)) {
      await Gal.requestAccess(toAlbum: true);
    }
  }

  static String _mime(String name) {
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
