import 'dart:io';
import 'dart:ui' as ui;

import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/canvas/template_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Rect _bounds(CanvasLayer l, Size canvas) {
  final s = SceneRenderer.layerSize(l, canvas);
  return Rect.fromCenter(center: Offset(l.cx * canvas.width, l.cy * canvas.height), width: s.width, height: s.height);
}

/// Text problems in a template, measured with its real fonts.
List<String> textProblems(CanvasDocument doc) {
  final canvas = Size(doc.pixelWidth.toDouble(), doc.pixelHeight.toDouble());
  final texts = doc.layers.where((l) => l.kind == LayerKind.text).toList();
  final problems = <String>[];
  for (var i = 0; i < texts.length; i++) {
    final a = _bounds(texts[i], canvas);
    final label = texts[i].text.replaceAll('\n', ' ');
    if (a.left < -1 || a.top < -1 || a.right > canvas.width + 1 || a.bottom > canvas.height + 1) {
      problems.add('off canvas: "$label"');
    }
    for (var j = i + 1; j < texts.length; j++) {
      final overlap = a.intersect(_bounds(texts[j], canvas));
      if (overlap.width > 0 && overlap.height > canvas.height * .004) {
        problems.add('overlap: "$label" and "${texts[j].text.replaceAll('\n', ' ')}"');
      }
    }
  }
  return problems;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every template fits, using its real fonts', (tester) async {
    final failures = <String>[];
    for (final t in allTemplates) {
      final doc = t.build();
      await SceneRenderer.prepare(doc.layers);
      for (final p in textProblems(doc)) {
        failures.add('${t.name} [${doc.pixelWidth}x${doc.pixelHeight}]: $p');
      }
    }
    for (final f in failures) {
      debugPrint('LAYOUT $f');
    }
    debugPrint('LAYOUT total ${failures.length} problems in ${allTemplates.length} templates');
    expect(failures, isEmpty);
  });

  testWidgets('draw contact sheets for review', (tester) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/sheets');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create();
    const columns = 8, rows = 5, cell = 180.0, gap = 8.0;
    for (var sheet = 0; sheet * columns * rows < allTemplates.length; sheet++) {
      final items = allTemplates.skip(sheet * columns * rows).take(columns * rows).toList();
      final docs = [for (final t in items) t.build()];
      for (final d in docs) {
        await SceneRenderer.prepare(d.layers);
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final width = columns * (cell + gap) + gap, height = rows * (cell * 1.8 + gap) + gap;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFF444444));
      for (var i = 0; i < docs.length; i++) {
        final d = docs[i];
        final maxHeight = cell * 1.8;
        final scale = d.aspectRatio >= cell / maxHeight ? cell / d.pixelWidth : maxHeight / d.pixelHeight;
        final size = Size(d.pixelWidth * scale, d.pixelHeight * scale);
        canvas.save();
        canvas.translate(gap + (i % columns) * (cell + gap), gap + (i ~/ columns) * (maxHeight + gap));
        SceneRenderer.paintDocument(canvas, size, d);
        canvas.restore();
      }
      final image = await recorder.endRecording().toImage(width.round(), height.round());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${dir.path}/sheet-$sheet.png').writeAsBytes(data!.buffer.asUint8List());
    }
    debugPrint('SHEETS ${dir.path}');
  });
}
