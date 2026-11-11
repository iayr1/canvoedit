import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/core/media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decodes exported PNG bytes and reads one pixel as [r, g, b, a].
Future<List<int>> _pixel(List<int> png, int x, int y, {void Function(int, int)? size}) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
  final image = (await codec.getNextFrame()).image;
  size?.call(image.width, image.height);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * image.width + x) * 4;
  return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2), data.getUint8(i + 3)];
}

Future<void> _solidImage(String path, Color color) async {
  final image = await SceneRenderer.rasterize(40, 40, (c, s) => c.drawRect(Offset.zero & s, Paint()..color = color));
  ImageBank.instance.put(path, image);
}

void main() {
  setUp(() => SceneRenderer.useGoogleFonts = false);

  CanvasDocument photo(String path) =>
      CanvasDocument(pixelWidth: 40, pixelHeight: 40, isPhoto: true, layers: [CanvasLayer.image(path, 40, 40, width: 1)..isBase = true]);

  testWidgets('export uses the canvas pixel size and scale', (tester) async {
    await tester.runAsync(() async {
      final doc = CanvasDocument(pixelWidth: 100, pixelHeight: 50, background: CanvasBackground(0xFF102030));
      int? w, h;
      final color = await _pixel(
        await SceneRenderer.exportPng(doc, scale: 2),
        10,
        10,
        size: (a, b) {
          w = a;
          h = b;
        },
      );
      expect([w, h], [200, 100]);
      expect(color, [0x10, 0x20, 0x30, 255]);
    });
  });

  testWidgets('a mono filter reaches the exported pixels', (tester) async {
    await tester.runAsync(() async {
      await _solidImage('red', const Color(0xFFFF0000));
      final doc = photo('red');
      final before = await _pixel(await SceneRenderer.exportPng(doc), 20, 20);
      expect(before.sublist(0, 3), [255, 0, 0]);

      doc.layers.first.grade.filterId = 'silver';
      final after = await _pixel(await SceneRenderer.exportPng(doc), 20, 20);
      expect((after[0] - after[1]).abs(), lessThanOrEqualTo(2));
      expect((after[1] - after[2]).abs(), lessThanOrEqualTo(2));
    });
  });

  testWidgets('a vignette darkens corners more than the centre', (tester) async {
    await tester.runAsync(() async {
      await _solidImage('white', Colors.white);
      final doc = photo('white');
      doc.layers.first.grade.values['vignette'] = 1;
      final png = await SceneRenderer.exportPng(doc);
      final center = await _pixel(png, 20, 20);
      final corner = await _pixel(png, 1, 1);
      expect(center[0], greaterThan(corner[0] + 40));
    });
  });

  testWidgets('crop selects the requested part of the image', (tester) async {
    await tester.runAsync(() async {
      final image = await SceneRenderer.rasterize(40, 40, (c, s) {
        c.drawRect(const Rect.fromLTWH(0, 0, 20, 40), Paint()..color = const Color(0xFF0000FF));
        c.drawRect(const Rect.fromLTWH(20, 0, 20, 40), Paint()..color = const Color(0xFF00FF00));
      });
      ImageBank.instance.put('split', image);
      final doc = photo('split');
      doc.layers.first.cropL = .5;
      doc.fitToBase();
      expect(doc.pixelWidth, 20);
      final color = await _pixel(await SceneRenderer.exportPng(doc), 2, 20);
      expect(color.sublist(0, 3), [0, 255, 0]);
    });
  });

  testWidgets('a hidden layer is left out of the export', (tester) async {
    await tester.runAsync(() async {
      final square = CanvasLayer.shape(ShapeKind.rectangle, fill: 0xFFFF0000, width: 1);
      final doc = CanvasDocument(pixelWidth: 20, pixelHeight: 20, background: CanvasBackground(0xFF000000), layers: [square]);
      expect((await _pixel(await SceneRenderer.exportPng(doc), 10, 10))[0], 255);
      square.visible = false;
      expect((await _pixel(await SceneRenderer.exportPng(doc), 10, 10))[0], 0);
    });
  });

  test('tapping finds a rotated layer in its true position', () {
    final bar = CanvasLayer.shape(ShapeKind.rectangle, width: .8, aspect: .1)..rotation = 1.5707963;
    const canvas = Size(100, 100);
    expect(SceneRenderer.hitTest(bar, const Offset(50, 15), canvas, slop: 0), isTrue);
    expect(SceneRenderer.hitTest(bar, const Offset(15, 50), canvas, slop: 0), isFalse);
  });
}
