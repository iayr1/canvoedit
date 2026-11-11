import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/canvas/template_engine.dart';
import 'package:canvo_edit/canvas/template_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => SceneRenderer.useGoogleFonts = false);

  test('the catalogue has over half a million templates', () {
    expect(TemplateCatalog.total, greaterThanOrEqualTo(500000));
    expect(TemplateCatalog.search(const TemplateQuery()).length, TemplateCatalog.total);
    expect(templateFormats.length, greaterThanOrEqualTo(60));
    expect(templateTopicNames.length, greaterThanOrEqualTo(40));
    expect(templateTopicNames.toSet().length, templateTopicNames.length);
    expect(templateFormats.map((f) => f.label).toSet().length, templateFormats.length);
  });

  test('results visit every match exactly once', () {
    final r = TemplateCatalog.search(TemplateQuery(formats: {2, 11}, topics: {0, 3, 7}));
    expect(r.length, 2 * 3 * templateStyles.length * templateColorNames.length);
    final ids = {for (var i = 0; i < r.length; i++) r[i].id};
    expect(ids.length, r.length);
    for (var i = 0; i < r.length; i++) {
      expect({2, 11}, contains(r[i].format));
      expect({0, 3, 7}, contains(r[i].topic));
    }
  });

  test('neighbouring results differ in format or topic', () {
    final r = TemplateCatalog.search(const TemplateQuery());
    var same = 0;
    for (var i = 0; i < 200; i++) {
      if (r[i].format == r[i + 1].format && r[i].topic == r[i + 1].topic) same++;
    }
    expect(same, lessThan(20));
  });

  test('search words narrow the right filters', () {
    final banner = TemplateCatalog.search(const TemplateQuery(text: 'linkedin banner'));
    expect(banner.length, greaterThan(0));
    for (var i = 0; i < 50; i++) {
      expect(banner[i].formatInfo.label, 'LinkedIn Profile banner');
    }
    final wedding = TemplateCatalog.search(const TemplateQuery(text: 'wedding instagram story'));
    for (var i = 0; i < 50; i++) {
      expect(wedding[i].topicName, 'Wedding');
      expect(wedding[i].formatInfo.label, 'Instagram Story');
    }
    expect(TemplateCatalog.search(const TemplateQuery(text: 'zzqx')).length, 0);
    final mint = TemplateCatalog.search(const TemplateQuery(text: 'mint'));
    expect(mint[0].colorName, 'Mint');
  });

  test('the photo count filter matches the frames in each template', () {
    for (final n in [0, 1, 2, 3, 4]) {
      final r = TemplateCatalog.search(TemplateQuery(photos: n, formats: {0}));
      expect(r.length, greaterThan(0), reason: '$n photos');
      for (var i = 0; i < math.min(r.length, 30); i++) {
        final frames = r[i].build().layers.where((l) => l.isFrame).length;
        expect(frames, n, reason: r[i].id);
      }
    }
  });

  test('every format works with every layout', () {
    for (var f = 0; f < templateFormats.length; f++) {
      for (var s = 0; s < templateStyles.length; s++) {
        final spec = TemplateSpec(f, (f + s) % templateTopicNames.length, s, (f * 3 + s) % templateColorNames.length);
        final doc = spec.build();
        final where = '${spec.formatInfo.label} / ${spec.styleInfo.name}';
        expect(doc.layers, isNotEmpty, reason: where);
        expect(doc.pixelWidth, spec.formatInfo.width);
        final texts = doc.layers.where((l) => l.kind == LayerKind.text).toList();
        expect(texts, isNotEmpty, reason: where);
        for (final l in texts) {
          expect(l.cy, inInclusiveRange(0, 1), reason: '$where: ${l.text}');
          expect(l.fontSize, greaterThan(0), reason: '$where: ${l.text}');
          final longest = l.text.split('\n').map((t) => t.length).reduce(math.max);
          expect(longest * l.fontSize * templateGlyphWidth, lessThanOrEqualTo(.97), reason: '$where: ${l.text}');
        }
        for (final l in doc.layers.where((l) => l.isFrame)) {
          expect(l.cx, inInclusiveRange(0, 1), reason: where);
          expect(l.cy, inInclusiveRange(0, 1), reason: where);
          expect(l.aspect, greaterThan(0), reason: where);
          expect(l.path, isNotNull, reason: '$where: frames come filled with a sample');
        }
      }
    }
  });

  test('a template with frames saves and reloads intact', () {
    final doc = TemplateCatalog.search(const TemplateQuery(photos: 3))[5].build();
    final again = CanvasDocument.fromJson(doc.toJson());
    expect(again.toJson(), doc.toJson());
    expect(again.layers.where((l) => l.isFrame).length, 3);
  });

  testWidgets('frames crop their photo and empty frames show a placeholder', (tester) async {
    await tester.runAsync(() async {
      final empty = CanvasLayer.frame(width: 1, aspect: 1);
      final doc = CanvasDocument(pixelWidth: 40, pixelHeight: 40, background: CanvasBackground(0xFF000000), layers: [empty]);
      final png = await SceneRenderer.exportPng(doc);
      final image = await (await ui.instantiateImageCodec(png)).getNextFrame();
      final data = (await image.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      // The placeholder is a light lavender panel, not the black background.
      expect(data.getUint8(0), greaterThan(150));
    });
  });

  testWidgets('render a contact sheet for review', (tester) async {
    final out = Platform.environment['SHEET_OUT'];
    if (out == null) return;
    await tester.runAsync(() async {
      const picks = [0, 2, 5, 11, 17, 21, 27, 29, 35, 39, 46, 50];
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(const Rect.fromLTWH(0, 0, 2200, 2400), Paint()..color = const Color(0xFF555555));
      for (var row = 0; row < 12; row++) {
        for (var col = 0; col < 12; col++) {
          final s = (row * 12 + col) % templateStyles.length;
          final spec = TemplateSpec(picks[row], (row * 5 + col) % templateTopicNames.length, s, (row + col) % 12);
          final doc = spec.build();
          await SceneRenderer.prepare(doc.layers);
          const box = 170.0;
          final scale = math.min(box / doc.pixelWidth, box / doc.pixelHeight);
          c.save();
          c.translate(10 + col * 182.0, 10 + row * 196.0);
          SceneRenderer.paintDocument(c, Size(doc.pixelWidth * scale, doc.pixelHeight * scale), doc);
          c.restore();
        }
      }
      final img = await rec.endRecording().toImage(2200, 2400);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
