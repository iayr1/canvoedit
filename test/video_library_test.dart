import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/canvas/sticker_library.dart';
import 'package:canvo_edit/canvas/word_library.dart';
import 'package:canvo_edit/core/expr.dart';
import 'package:canvo_edit/features/video/effect_library.dart';
import 'package:canvo_edit/features/video/ffmpeg_graph.dart';
import 'package:canvo_edit/features/video/transition_library.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:flutter_test/flutter_test.dart';

VideoClip _video(int ms) => VideoClip(path: '/v.mp4', kind: ClipKind.video, sourceMs: ms, hasAudio: true);

void main() {
  group('expressions', () {
    test('follow FFmpeg precedence and functions', () {
      double e(String s, [Map<String, double> v = const {}]) => Expr.parse(s).eval(v);
      expect(e('1+2*3'), 7);
      expect(e('2^3^2'), 64);
      expect(e('2*-3'), -6);
      expect(e('-2^2'), -4);
      expect(e('mod(-1,3)'), 2);
      expect(e('clip(5,0,1)'), 1);
      expect(e('if(gt(X,1),10,20)', {'X': 2}), 10);
      expect(e('hypot(3,4)'), 5);
      expect(() => Expr.parse('foo(1)'), throwsFormatException);
      expect(() => Expr.parse('1+'), throwsFormatException);
    });
  });

  group('transitions', () {
    final lib = TransitionLibrary.instance;

    test('there are well over a thousand, with unique ids', () {
      expect(lib.length, greaterThan(1000));
      expect(lib.all.map((p) => p.id).toSet().length, lib.length);
      for (final c in TransitionLibrary.categories) {
        expect(lib.search(category: c), isNotEmpty, reason: c);
      }
    });

    test('every pattern starts on clip A and ends on clip B', () {
      for (final p in lib.all.where((p) => p.isPattern)) {
        final expr = Expr.parse(p.exportExpr);
        for (final (w, h) in [(1080.0, 1920.0), (1920.0, 1080.0)]) {
          for (var i = 0; i <= 6; i++) {
            for (var j = 0; j <= 6; j++) {
              final vars = {'X': w * i / 6, 'Y': h * j / 6, 'W': w, 'H': h, 'A': 10.0, 'B': 200.0};
              expect(expr.eval({...vars, 'P': 1}), closeTo(10, 1e-6), reason: '${p.id} start');
              expect(expr.eval({...vars, 'P': 0}), closeTo(200, 1e-6), reason: '${p.id} end');
            }
          }
        }
      }
    });

    test('masks stay between 0 and 1', () {
      for (final p in lib.all.where((p) => p.isPattern)) {
        final values = p.sampleMask(9, 9, 1080, 1920);
        for (final v in values) {
          expect(v, inInclusiveRange(0, 1), reason: p.id);
        }
      }
    });

    test('search narrows by words', () {
      final results = lib.search(text: 'circle open centre');
      expect(results, isNotEmpty);
      expect(results.every((p) => p.name.toLowerCase().contains('circle')), isTrue);
    });

    test('a pattern clip exports a custom xfade and survives JSON', () {
      final a = _video(4000)..transitionMs = 1000;
      TransitionLibrary.apply(a, lib.byId('spiral-3-in-m'));
      final copy = VideoClip.fromJson(a.toJson());
      expect(copy.transition, TransitionType.pattern);
      expect(copy.transitionPattern, 'spiral-3-in-m');
      final args = buildExportArgs(
        project: VideoProject(clips: [a, _video(3000)]),
        settings: const ExportSettings(width: 720, height: 1280),
        outputPath: '/out.mp4',
      );
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains("xfade=transition=custom:expr='A+(B-A)*clip("));
    });
  });

  group('effects', () {
    final lib = EffectLibrary.instance;

    test('there are well over a thousand, with unique ids', () {
      expect(lib.length, greaterThan(1000));
      expect(lib.all.map((e) => e.id).toSet().length, lib.length);
      for (final g in EffectLibrary.groups) {
        expect(lib.search(group: g), isNotEmpty, reason: g);
      }
    });

    test('every motion expression parses and starts near the frame', () {
      for (final m in lib.motions.where((m) => m.moves)) {
        final f = effectFrameAt(ClipEffect(m, lib.textures.first, lib.lights.first), 0, 3000);
        expect(f.zoom, greaterThanOrEqualTo(1), reason: m.id);
        expect(f.centerX, inInclusiveRange(0, 1), reason: m.id);
        expect(f.centerY, inInclusiveRange(0, 1), reason: m.id);
        // The visible window must stay inside the frame.
        expect(f.centerX - .5 / f.zoom, greaterThanOrEqualTo(-1e-9), reason: m.id);
        expect(f.centerX + .5 / f.zoom, lessThanOrEqualTo(1 + 1e-9), reason: m.id);
      }
    });

    test('zoom in grows over the clip', () {
      final e = lib.byId('zin2.none.none')!;
      expect(effectFrameAt(e, 0, 4000).zoom, closeTo(1, 1e-9));
      expect(effectFrameAt(e, 4000, 4000).zoom, closeTo(1.22, 1e-9));
    });

    test('fades cover the frame at their start', () {
      final e = lib.byId('none.none.fib')!;
      final f = effectFrameAt(e, 0, 4000);
      expect(f.overlay, 0x000000);
      expect(f.overlayOpacity, 1);
      expect(effectFrameAt(e, 2000, 4000).overlayOpacity, 0);
    });

    test('effects export as filters on the clip', () {
      final clip = _video(4000)..effect = 'zin2.grain1.bars1';
      expect(VideoClip.fromJson(clip.toJson()).effect, 'zin2.grain1.bars1');
      final args = buildExportArgs(
        project: VideoProject(clips: [clip]),
        settings: const ExportSettings(width: 720, height: 1280),
        outputPath: '/out.mp4',
      );
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains("zoompan=z='1+0.22*min(on/120,1)'"));
      expect(graph, contains('noise=alls=12'));
      expect(graph, contains('drawbox'));
    });
  });

  group('designer words', () {
    test('tens of thousands of phrase and style combinations', () {
      expect(wordStyles.length, WordTreatment.values.length * wordPalettes.length * wordFonts.length);
      expect(WordResults.total, greaterThan(10000));
    });

    test('results visit every phrase in every style exactly once', () {
      final r = WordResults.search(category: 'Love', treatment: WordTreatment.neon);
      final seen = {for (var i = 0; i < r.length; i++) '${r[i].text}|${r[i].style.id}'};
      expect(seen.length, r.length);
      expect(r.length, 10 * wordPalettes.length * wordFonts.length);
    });

    test('labels only come in label looks', () {
      final r = WordResults.search(category: 'Labels');
      for (var i = 0; i < r.length; i += 7) {
        expect(r[i].style.treatment.isLabel, isTrue);
      }
    });

    test('typing unknown words shows them in every look', () {
      final r = WordResults.search(text: 'Priya turns 30');
      expect(r.length, wordStyles.length);
      expect(r[0].text, 'Priya turns 30');
    });

    test('styled text survives JSON and paints in every treatment', () async {
      SceneRenderer.useGoogleFonts = false;
      for (final t in WordTreatment.values) {
        final layer = DesignerWord('Hello', 'Social', WordStyle(t, wordPalettes[1], wordFonts.first)).toLayer();
        final copy = CanvasLayer.fromJson(layer.toJson());
        expect(copy.toJson(), layer.toJson(), reason: t.name);
        final image = await SceneRenderer.rasterize(200, 120, (c, s) => SceneRenderer.paintLayer(c, s, copy));
        expect(image.width, 200);
        image.dispose();
      }
    });
  });

  group('stickers', () {
    test('over a thousand, every category filled', () {
      final lib = StickerLibrary.instance;
      expect(lib.length, greaterThan(1000));
      expect(lib.all.where((s) => s.emoji != null).map((s) => s.emoji).toSet().length, lib.all.where((s) => s.emoji != null).length);
      for (final c in StickerLibrary.categories) {
        expect(lib.inCategory(c), isNotEmpty, reason: c);
      }
      expect(lib.all.last.toLayer().kind, LayerKind.shape);
    });
  });
}
