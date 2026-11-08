import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/image_export.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/canvas/template_library.dart';
import 'package:canvo_edit/core/color/filter_presets.dart';
import 'package:canvo_edit/core/color/grade.dart';
import 'package:canvo_edit/features/video/clip_tools.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _luminance(int argb) => Color(argb).computeLuminance();

double _contrast(int a, int b) {
  final x = _luminance(a), y = _luminance(b);
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  setUp(() => SceneRenderer.useGoogleFonts = false);

  group('filter library', () {
    test('has several hundred uniquely named filters', () {
      expect(filterPresets.length, greaterThanOrEqualTo(300));
      expect(filterPresets.map((p) => p.id).toSet().length, filterPresets.length);
      expect(filterPresets.map((p) => p.name).toSet().length, filterPresets.length);
    });

    test('no two filters look the same', () {
      double distance(ColorMatrix a, ColorMatrix b) {
        var sum = 0.0;
        for (var i = 0; i < 20; i++) {
          // Offsets use a 0-255 scale, so they're brought in line with the rest.
          final scale = i % 5 == 4 ? 1 / 255 : 1.0;
          sum += ((a[i] - b[i]) * scale).abs();
        }
        return sum;
      }

      // Vignette isn't in the matrix, so it counts towards telling looks apart.
      final clashes = <String>[];
      for (var i = 0; i < filterPresets.length; i++) {
        for (var j = i + 1; j < filterPresets.length; j++) {
          final a = filterPresets[i], b = filterPresets[j];
          final vignette = ((a.values['vignette'] ?? 0) - (b.values['vignette'] ?? 0)).abs();
          if (distance(a.matrix, b.matrix) + vignette < .03) clashes.add('${a.name} / ${b.name}');
        }
      }
      expect(clashes, isEmpty);
    });

    test('every value stays within its slider, so filters can be fine-tuned', () {
      for (final p in filterPresets) {
        p.values.forEach((key, v) {
          final param = adjustParams.firstWhere((a) => a.key == key);
          expect(v, inInclusiveRange(param.min, param.max), reason: '${p.name}: $key');
        });
      }
    });

    test('filters do not blow out a mid-grey image', () {
      for (final p in filterPresets) {
        final m = p.matrix;
        for (var row = 0; row < 3; row++) {
          final v = (m[row * 5] + m[row * 5 + 1] + m[row * 5 + 2]) * 128 + m[row * 5 + 4];
          expect(v, inInclusiveRange(10, 250), reason: '${p.name} channel $row gives $v');
        }
      }
    });
  });

  group('template library', () {
    test('has several hundred, uniquely named, across many topics', () {
      expect(allTemplates.length, greaterThanOrEqualTo(300));
      expect(allTemplates.map((t) => t.name).toSet().length, allTemplates.length);
      expect(templateTopics.length, greaterThanOrEqualTo(20));
    });

    test('generated palettes are readable', () {
      for (final p in templatePalettes) {
        for (final bg in [p.bg, ?p.bg2]) {
          expect(_contrast(p.ink, bg), greaterThanOrEqualTo(4.5), reason: 'ink on ${bg.toRadixString(16)}');
        }
        expect(_contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5), reason: 'onAccent on ${p.accent.toRadixString(16)}');
      }
    });

    test('every template builds, saves, reloads, and only uses known fonts', () {
      for (final t in allTemplates) {
        final doc = t.build();
        expect(doc.layers, isNotEmpty, reason: t.name);
        expect(CanvasDocument.fromJson(doc.toJson()).toJson(), doc.toJson(), reason: t.name);
        for (final l in doc.layers.where((l) => l.kind == LayerKind.text)) {
          expect(appFonts, contains(l.fontFamily), reason: t.name);
          expect(l.text.trim(), isNotEmpty, reason: t.name);
        }
      }
    });

    test('text centres sit on the canvas, and estimated widths fit', () {
      for (final t in allTemplates.where((t) => t.format.isNotEmpty)) {
        final doc = t.build();
        for (final l in doc.layers.where((l) => l.kind == LayerKind.text)) {
          expect(l.cy, inInclusiveRange(.03, .97), reason: '${t.name}: ${l.text}');
          final longest = l.text.split('\n').map((s) => s.length).reduce(math.max);
          final width = longest * l.fontSize * templateGlyphWidth + longest * l.letterSpacing;
          expect(width, lessThanOrEqualTo(.96), reason: '${t.name}: ${l.text}');
        }
      }
    });

    test('stacked text never overlaps and stays inside its region', () {
      for (final ratio in [630 / 1200, 720 / 1280, 1.0, 1350 / 1080, 1920 / 1080]) {
        final items = [
          CanvasLayer.text('KICKER', size: .03),
          CanvasLayer.text('Big\nHeadline', size: .24),
          CanvasLayer.text('A subtitle line', size: .04),
          CanvasLayer.text('Go', size: .036)..bgColor = 0xFF000000,
        ];
        stackText(items, ratio, .1, .9);
        var previousBottom = .1 - 1e-9;
        for (final l in items) {
          final h = templateTextHeight(l, ratio);
          expect(l.cy - h / 2, greaterThanOrEqualTo(previousBottom), reason: 'ratio $ratio: ${l.text}');
          previousBottom = l.cy + h / 2;
        }
        expect(previousBottom, lessThanOrEqualTo(.9 + 1e-9), reason: 'ratio $ratio');
      }
    });

    test('search finds by topic, format and name', () {
      expect(searchTemplates('wedding').every((t) => t.category == 'Wedding' || t.name.contains('Wedding')), isTrue);
      expect(searchTemplates('wedding'), isNotEmpty);
      expect(searchTemplates('STORY').any((t) => t.format == 'Story'), isTrue);
      expect(searchTemplates('', topic: 'Sale').every((t) => t.category == 'Sale'), isTrue);
      expect(searchTemplates('zzzz'), isEmpty);
    });
  });

  group('image export formats', () {
    final doc = CanvasDocument(pixelWidth: 40, pixelHeight: 20, background: CanvasBackground(0xFF2040A0));

    testWidgets('JPG is a real image of the right size and colour', (tester) async {
      await tester.runAsync(() async {
        final bytes = await exportDocument(doc, ImageExportFormat.jpeg);
        expect(bytes.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG header');
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        expect([image.width, image.height], [40, 20]);
        final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        expect(data.getUint8(0), closeTo(0x20, 6));
        expect(data.getUint8(1), closeTo(0x40, 6));
        expect(data.getUint8(2), closeTo(0xA0, 6));
      });
    });

    testWidgets('PDF is a real document', (tester) async {
      await tester.runAsync(() async {
        final bytes = await exportDocument(doc, ImageExportFormat.pdf);
        expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      });
    });
  });

  group('clip tool arguments', () {
    final clip = VideoClip(path: 'in.mp4', kind: ClipKind.video, sourceMs: 9000, inMs: 1000, outMs: 4000, hasAudio: true, speed: 2);

    test('reverse works in one-second chunks over just the trimmed part', () {
      expect(reverseChunkStarts(clip), [1000, 2000, 3000]);
      final odd = VideoClip(path: 'in.mp4', kind: ClipKind.video, sourceMs: 9000, inMs: 500, outMs: 2700);
      expect(reverseChunkStarts(odd), [500, 1500, 2500]);
      expect(reverseChunkArgs(odd, 2500, 'p.mp4'), containsAllInOrder(['-ss', '2.500', '-t', '0.200', '-i', 'in.mp4', '-vf', 'reverse', '-an']));
      expect(reverseAudioArgs(clip, 'a.m4a'), containsAllInOrder(['-ss', '1.000', '-t', '3.000', '-i', 'in.mp4', '-vn', '-af', 'areverse']));
      expect(reverseJoinArgs('l.txt', 'a.m4a', 'o.mp4'), containsAllInOrder(['-f', 'concat', '-i', 'l.txt', '-i', 'a.m4a', '-c', 'copy', 'o.mp4']));
      expect(reverseJoinArgs('l.txt', null, 'o.mp4'), isNot(contains('-map')));
    });

    test('denoise leaves the picture untouched', () {
      expect(denoiseArgs(clip, 'o.mp4'), containsAllInOrder(['-c:v', 'copy', '-af', 'afftdn=nf=-25']));
    });

    test('detached audio matches the clip speed', () {
      expect(extractAudioArgs(clip, 'o.m4a'), containsAllInOrder(['-vn', '-af', 'atempo=2.0000']));
    });
  });
}
