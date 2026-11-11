// Regenerates the launcher icons, splash images and web icons from the logo
// painter. Run from the project root:
//   flutter test tool/make_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:canvo_edit/app/logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _png(String path, int size, void Function(Canvas, Size) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('make icons', () async {
    const res = 'android/app/src/main/res';
    const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
    for (final MapEntry(key: d, value: k) in densities.entries) {
      // Legacy icons are 48 dp; adaptive layers are 108 dp with a 66 dp safe zone.
      await _png('$res/mipmap-$d/ic_launcher.png', (48 * k).round(), const LogoPainter().paint);
      await _png('$res/mipmap-$d/ic_launcher_round.png', (48 * k).round(), const LogoPainter(round: true).paint);
      await _png('$res/mipmap-$d/ic_launcher_background.png', (108 * k).round(), LogoPainter.paintBackground);
      await _png('$res/mipmap-$d/ic_launcher_foreground.png', (108 * k).round(), const LogoPainter(tile: false, glyphScale: .36).paint);
    }
    // Android 12+ splash icon: 288 dp, with the visible part inside a 192 dp circle.
    await _png('$res/drawable-xxxhdpi/splash_icon.png', 1152, (c, s) {
      final side = s.width * .44;
      c.translate((s.width - side) / 2, (s.height - side) / 2);
      const LogoPainter().paint(c, Size.square(side));
    });
    // Older Android: a centred logo over the gradient window.
    await _png('$res/drawable-xxxhdpi/splash_logo.png', 512, const LogoPainter().paint);
    // Web and store.
    await _png('web/favicon.png', 64, const LogoPainter().paint);
    await _png('web/icons/Icon-192.png', 192, const LogoPainter().paint);
    await _png('web/icons/Icon-512.png', 512, const LogoPainter().paint);
    await _png('web/icons/Icon-maskable-192.png', 192, (c, s) {
      LogoPainter.paintBackground(c, s);
      const LogoPainter(tile: false, glyphScale: .4).paint(c, s);
    });
    await _png('web/icons/Icon-maskable-512.png', 512, (c, s) {
      LogoPainter.paintBackground(c, s);
      const LogoPainter(tile: false, glyphScale: .4).paint(c, s);
    });
    await _png('store-assets/icon-512.png', 512, (c, s) {
      LogoPainter.paintBackground(c, s);
      const LogoPainter(tile: false, glyphScale: .56).paint(c, s);
    });
  });
}
