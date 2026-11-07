import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/core/color/filter_presets.dart';
import 'package:canvo_edit/core/color/grade.dart';
import 'package:canvo_edit/core/history.dart';
import 'package:canvo_edit/features/editor/crop_screen.dart';
import 'package:canvo_edit/features/video/ffmpeg_graph.dart';
import 'package:canvo_edit/features/video/video_controller.dart';
import 'package:canvo_edit/features/video/video_export_sheet.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:flutter_test/flutter_test.dart';

VideoClip _video(int ms, {bool audio = true, String path = '/in/a.mp4'}) =>
    VideoClip(path: path, kind: ClipKind.video, sourceMs: ms, hasAudio: audio);

/// Applies a colour matrix to an RGB colour on a 0-255 scale.
List<double> _apply(ColorMatrix m, double r, double g, double b) => [
  m[0] * r + m[1] * g + m[2] * b + m[3] * 255 + m[4],
  m[5] * r + m[6] * g + m[7] * b + m[8] * 255 + m[9],
  m[10] * r + m[11] * g + m[12] * b + m[13] * 255 + m[14],
];

void main() {
  group('colour', () {
    test('neutral sliders produce the identity matrix', () {
      final m = matrixFromValues(const {});
      for (var i = 0; i < 20; i++) {
        expect(m[i], closeTo(identityMatrix[i], 1e-9));
      }
    });

    test('one stop of exposure doubles values', () {
      final out = _apply(matrixFromValues(const {'exposure': 1}), 50, 60, 70);
      expect(out, [closeTo(100, 1e-6), closeTo(120, 1e-6), closeTo(140, 1e-6)]);
    });

    test('full desaturation gives equal channels', () {
      final out = _apply(matrixFromValues(const {'saturation': -1}), 200, 40, 90);
      expect(out[0], closeTo(out[1], 1e-6));
      expect(out[1], closeTo(out[2], 1e-6));
    });

    test('contrast pivots around mid grey', () {
      final out = _apply(matrixFromValues(const {'contrast': .5}), 127.5, 127.5, 127.5);
      expect(out[0], closeTo(127.5, 1e-6));
    });

    test('multiply applies the right-hand matrix first', () {
      final brighten = matrixFromValues(const {'brightness': .5});
      final expose = matrixFromValues(const {'exposure': 1});
      final out = _apply(multiplyMatrix(expose, brighten), 10, 10, 10);
      expect(out[0], closeTo((10 + 32) * 2, 1e-6));
    });

    test('presets are plentiful, uniquely identified, and all valid', () {
      expect(filterPresets.length, greaterThanOrEqualTo(50));
      expect(filterPresets.map((p) => p.id).toSet().length, filterPresets.length);
      for (final p in filterPresets) {
        expect(p.matrix.length, 20, reason: p.name);
        expect(p.matrix.every((v) => v.isFinite), isTrue, reason: p.name);
        for (final key in p.values.keys) {
          expect(adjustParams.any((a) => a.key == key), isTrue, reason: '${p.name}: $key');
        }
      }
    });

    test('filter strength of zero leaves the image untouched', () {
      final grade = Grade(filterId: 'pop', strength: 0);
      for (var i = 0; i < 20; i++) {
        expect(grade.matrix[i], closeTo(identityMatrix[i], 1e-9));
      }
    });

    test('grade survives a JSON round trip', () {
      final grade = Grade(filterId: 'ink', strength: .4, values: {'hue': 12});
      final copy = Grade.fromJson(grade.toJson());
      expect(copy.matrix, grade.matrix);
      expect(copy.vignette, grade.vignette);
    });
  });

  group('history', () {
    test('undo, redo, and new edits clearing the redo path', () {
      final h = History('a')
        ..push('b')
        ..push('c');
      expect(h.undo(), 'b');
      expect(h.redo(), 'c');
      expect(h.undo(), 'b');
      h.push('d');
      expect(h.canRedo, isFalse);
      expect(h.undo(), 'b');
      expect(h.undo(), 'a');
      expect(h.canUndo, isFalse);
    });

    test('an unchanged snapshot does not add a step', () {
      final h = History('a')..push('a');
      expect(h.canUndo, isFalse);
    });
  });

  group('crop mapping', () {
    test('source and display mapping are inverses for every orientation', () {
      const p = Offset(.2, -.35);
      for (var turns = 0; turns < 4; turns++) {
        for (final flipH in [false, true]) {
          for (final flipV in [false, true]) {
            final back = displayToSource(sourceToDisplay(p, turns, flipH, flipV), turns, flipH, flipV);
            expect(back.dx, closeTo(p.dx, 1e-9));
            expect(back.dy, closeTo(p.dy, 1e-9));
          }
        }
      }
    });

    test('a quarter turn matches how the renderer rotates', () {
      final d = sourceToDisplay(const Offset(.5, 0), 1, false, false);
      expect(d.dx, closeTo(0, 1e-9));
      expect(d.dy, closeTo(.5, 1e-9));
    });
  });

  group('documents', () {
    test('photo canvas follows crop and rotation of the base layer', () {
      final base = CanvasLayer.image('x', 4000, 3000, width: 1)
        ..isBase = true
        ..cropR = .5;
      final doc = CanvasDocument(pixelWidth: 4000, pixelHeight: 3000, isPhoto: true, layers: [base])..fitToBase();
      expect([doc.pixelWidth, doc.pixelHeight], [2000, 3000]);
      base.quarterTurns = 1;
      doc.fitToBase();
      expect([doc.pixelWidth, doc.pixelHeight], [3000, 2000]);
    });

    test('a document with every layer kind survives a JSON round trip', () {
      final doc = CanvasDocument(
        pixelWidth: 100,
        pixelHeight: 200,
        background: CanvasBackground(0xFF112233, color2: 0xFF445566, angle: 30),
        layers: [
          CanvasLayer.text('Hi')..bold = true,
          CanvasLayer.sticker('🔥'),
          CanvasLayer.shape(ShapeKind.star),
          CanvasLayer.image('p', 10, 20)..grade.filterId = 'ink',
          CanvasLayer.stroke([.1, .2, .3, .4], 0xFF000000, .01),
        ],
      );
      expect(CanvasDocument.fromJson(doc.toJson()).toJson(), doc.toJson());
    });
  });

  group('timeline', () {
    test('duration subtracts transition overlaps', () {
      final p = VideoProject(clips: [_video(4000)..transition = TransitionType.crossfade..transitionMs = 1000, _video(3000)]);
      expect(p.durationMs, 6000);
      expect(p.startOf(1), 3000);
    });

    test('speed changes how long a clip lasts', () {
      expect((_video(4000)..speed = 2).durationMs, 2000);
      expect((_video(4000)..speed = .5).durationMs, 8000);
    });

    test('transitions cannot use more than half of a neighbouring clip', () {
      final p = VideoProject(clips: [_video(4000)..transition = TransitionType.crossfade..transitionMs = 2000, _video(1000)]);
      expect(p.transitionMsAfter(0), 500);
    });

    test('frameAt reports both clips and progress during a transition', () {
      final a = _video(4000)..transition = TransitionType.crossfade..transitionMs = 1000;
      final b = _video(3000);
      final p = VideoProject(clips: [a, b]);

      expect(p.frameAt(1000)!.clip, a);
      expect(p.frameAt(1000)!.next, isNull);

      final mid = p.frameAt(3500)!;
      expect(mid.clip, a);
      expect(mid.next, b);
      expect(mid.progress, closeTo(.5, 1e-9));
      expect(mid.clipTimeMs, 3500);
      expect(mid.nextTimeMs, 500);

      expect(p.frameAt(5000)!.clip, b);
      expect(p.frameAt(5000)!.clipTimeMs, 2000);
    });

    test('frameAt accounts for trim and speed', () {
      final clip = _video(10000)
        ..inMs = 2000
        ..speed = 2;
      expect(VideoProject(clips: [clip]).frameAt(1000)!.clipTimeMs, 4000);
    });

    test('frameAt lands on the next clip exactly at a hard cut', () {
      final a = _video(1000), b = _video(1000);
      final f = VideoProject(clips: [a, b]).frameAt(1000)!;
      expect(f.clip, b);
      expect(f.clipTimeMs, 0);
    });

    test('an empty project is safe', () {
      final p = VideoProject();
      expect(p.durationMs, 0);
      expect(p.frameAt(0), isNull);
    });

    test('project survives a JSON round trip', () {
      final p = VideoProject(
        clips: [_video(1000)..grade.filterId = 'pop'],
        audio: [AudioTrack(path: 'm', name: 'song', sourceMs: 9000)],
        overlays: [CanvasLayer.text('x')..startMs = 100..endMs = 200],
      );
      expect(VideoProject.fromJson(p.toJson()).toJson(), p.toJson());
    });
  });

  group('editing', () {
    test('split divides source time and keeps total duration', () {
      final clip = _video(10000)..transition = TransitionType.crossfade;
      final c = VideoController(VideoProject(clips: [clip, _video(5000)]));
      final before = c.project.clips[0].durationMs;
      expect(c.splitAt(4000), isTrue);
      final first = c.project.clips[0], second = c.project.clips[1];
      expect(first.outMs, 4000);
      expect(second.inMs, 4000);
      expect(second.outMs, 10000);
      expect(first.durationMs + second.durationMs, before);
      // The outgoing transition belongs to the part next to the following clip.
      expect(first.transition, TransitionType.none);
      expect(second.transition, TransitionType.crossfade);
      expect(first.id, isNot(second.id));
      c.dispose();
    });

    test('split respects speed when finding the source point', () {
      final c = VideoController(VideoProject(clips: [_video(10000)..speed = 2]));
      expect(c.splitAt(1000), isTrue);
      expect(c.project.clips[0].outMs, 2000);
      c.dispose();
    });

    test('split refuses a point at the very edge of a clip', () {
      final c = VideoController(VideoProject(clips: [_video(5000)]));
      expect(c.splitAt(0), isFalse);
      expect(c.splitAt(5000), isFalse);
      expect(c.project.clips, hasLength(1));
      c.dispose();
    });

    test('undo restores the timeline after a split', () {
      final c = VideoController(VideoProject(clips: [_video(5000)]));
      c.splitAt(2000);
      expect(c.project.clips, hasLength(2));
      c.undo();
      expect(c.project.clips, hasLength(1));
      expect(c.project.clips.first.outMs, 5000);
      c.redo();
      expect(c.project.clips, hasLength(2));
      c.dispose();
    });

    test('trim is held inside the source and a minimum length', () {
      final clip = _video(5000);
      final c = VideoController(VideoProject(clips: [clip]));
      c.trimStart(clip, 99999);
      expect(clip.inMs, 4800);
      c.trimStart(clip, -99999);
      expect(clip.inMs, 0);
      c.trimEnd(clip, 99999);
      expect(clip.outMs, 5000);
      c.dispose();
    });
  });

  group('export arguments', () {
    const settings = ExportSettings(width: 1080, height: 1920);

    String graphOf(List<String> args) => args[args.indexOf('-filter_complex') + 1];

    test('refuses an empty project', () {
      expect(
        () => buildExportArgs(project: VideoProject(), settings: settings, outputPath: 'o.mp4'),
        throwsArgumentError,
      );
    });

    test('a single clip seeks, scales to the frame and maps its output', () {
      final args = buildExportArgs(
        project: VideoProject(clips: [_video(5000)..inMs = 1000..outMs = 3000]),
        settings: settings,
        outputPath: 'o.mp4',
      );
      final g = graphOf(args);
      expect(args.sublist(2, 8), ['-ss', '1.000', '-t', '2.000', '-i', '/in/a.mp4']);
      expect(g, contains('scale=1080:1920:force_original_aspect_ratio=decrease'));
      expect(g, contains('pad=1080:1920'));
      expect(g, contains('[0:a]'));
      expect(args.last, 'o.mp4');
      expect(args, containsAllInOrder(['-map', '[vout]', '-map', '[a0]']));
    });

    test('a clip with no audio stream gets silence and never references [n:a]', () {
      final g = graphOf(buildExportArgs(
        project: VideoProject(clips: [_video(1000, audio: false)]),
        settings: settings,
        outputPath: 'o.mp4',
      ));
      expect(g, contains('anullsrc'));
      expect(g, isNot(contains('[0:a]')));
    });

    test('a photo clip loops for its length', () {
      final args = buildExportArgs(
        project: VideoProject(clips: [VideoClip(path: 'p.jpg', kind: ClipKind.image, sourceMs: 600000, outMs: 3000)]),
        settings: settings,
        outputPath: 'o.mp4',
      );
      expect(args, containsAllInOrder(['-loop', '1', '-framerate', '30', '-t', '3.000', '-i', 'p.jpg']));
    });

    test('hard cuts use concat and transitions use xfade at the right offset', () {
      final g = graphOf(buildExportArgs(
        project: VideoProject(clips: [
          _video(4000),
          _video(4000)..transition = TransitionType.wipeLeft..transitionMs = 1000,
          _video(4000),
        ]),
        settings: settings,
        outputPath: 'o.mp4',
      ));
      expect(g, contains('[v0][v1]concat=n=2:v=1:a=0'));
      expect(g, contains('[vj1][v2]xfade=transition=wipeleft:duration=1.000:offset=7.000'));
      expect(g, contains('acrossfade=d=1.000'));
    });

    test('the output length agrees with the project timeline', () {
      final p = VideoProject(clips: [
        _video(4000)..transition = TransitionType.crossfade..transitionMs = 1000,
        _video(4000),
      ]);
      final args = buildExportArgs(project: p, settings: settings, outputPath: 'o.mp4');
      expect(args[args.indexOf('-t', args.indexOf('-filter_complex')) + 1], (p.durationMs / 1000).toStringAsFixed(3));
    });

    test('speed changes both video timing and audio tempo', () {
      final g = graphOf(buildExportArgs(
        project: VideoProject(clips: [_video(4000)..speed = 4]),
        settings: settings,
        outputPath: 'o.mp4',
      ));
      expect(g, contains('setpts=PTS/4.0000'));
      expect(g, contains('atempo=2,atempo=2'));
    });

    test('atempo chains stay inside the range the filter accepts', () {
      expect(atempoChain(1), '');
      expect(atempoChain(1.5), 'atempo=1.5000');
      expect(atempoChain(.25), 'atempo=0.5,atempo=0.5000');
      expect(atempoChain(3), 'atempo=2,atempo=1.5000');
    });

    test('neutral clips skip the colour stage, graded clips include it', () {
      final neutral = graphOf(buildExportArgs(project: VideoProject(clips: [_video(1000)]), settings: settings, outputPath: 'o.mp4'));
      expect(neutral, isNot(contains('colorchannelmixer')));
      final graded = graphOf(buildExportArgs(project: VideoProject(clips: [_video(1000)..grade.filterId = 'pop']), settings: settings, outputPath: 'o.mp4'));
      expect(graded, contains('format=rgba,colorchannelmixer='));
    });

    test('colour offsets are written as a fraction in the alpha column', () {
      final m = matrixFromValues(const {'brightness': 1});
      final mixer = colorMixerFilter(m);
      expect(mixer, contains('ra=${(64 / 255).toStringAsFixed(4)}'));
      expect(mixer, contains('rr=1.0000'));
    });

    test('overlays composite during their time range in stacking order', () {
      final a = CanvasLayer.text('a')..startMs = 500..endMs = 1500;
      final b = CanvasLayer.sticker('b');
      final args = buildExportArgs(
        project: VideoProject(clips: [_video(2000)], overlays: [a, b]),
        settings: settings,
        outputPath: 'o.mp4',
        overlayPngs: {a.id: 'a.png', b.id: 'b.png'},
      );
      final g = graphOf(args);
      expect(g, contains("[v0][1:v]overlay=0:0:enable='between(t,0.500,1.500)'[vo0]"));
      expect(g, contains("[vo0][2:v]overlay=0:0:enable='between(t,0.000,2.000)'[vo1]"));
      expect(g, contains('[vo1]format=yuv420p[vout]'));
    });

    test('music is trimmed to the timeline, delayed and mixed in', () {
      final args = buildExportArgs(
        project: VideoProject(
          clips: [_video(10000)],
          audio: [AudioTrack(path: 'm.mp3', name: 'm', sourceMs: 60000, startMs: 2000, inMs: 1000, fadeOutMs: 1000)],
        ),
        settings: settings,
        outputPath: 'o.mp4',
      );
      final g = graphOf(args);
      expect(g, contains('atrim=start=1.000:duration=8.000'));
      expect(g, contains('afade=t=out:st=7.000:d=1.000'));
      expect(g, contains('adelay=2000|2000'));
      expect(g, contains('[a0][m0]amix=inputs=2:duration=first:normalize=0[aout]'));
      expect(args, containsAllInOrder(['-map', '[aout]']));
    });

    test('music that starts after the end of the video is left out', () {
      final args = buildExportArgs(
        project: VideoProject(clips: [_video(1000)], audio: [AudioTrack(path: 'm.mp3', name: 'm', sourceMs: 5000, startMs: 2000)]),
        settings: settings,
        outputPath: 'o.mp4',
      );
      expect(args, isNot(contains('m.mp3')));
    });

    test('every filter input label refers to something defined earlier', () {
      final a = CanvasLayer.text('a');
      final args = buildExportArgs(
        project: VideoProject(
          clips: [
            _video(4000)..transition = TransitionType.crossfade,
            _video(4000, audio: false)..grade.filterId = 'ink',
            VideoClip(path: 'p.jpg', kind: ClipKind.image, sourceMs: 60000, outMs: 2000),
          ],
          overlays: [a],
          audio: [AudioTrack(path: 'm.mp3', name: 'm', sourceMs: 5000)],
        ),
        settings: settings,
        outputPath: 'o.mp4',
        overlayPngs: {a.id: 'a.png'},
      );
      final chains = graphOf(args).split(';');
      final inputCount = args.where((x) => x == '-i').length;
      final defined = <String>{};
      for (final chain in chains) {
        final head = RegExp(r'^((\[[^\]]+\])*)').firstMatch(chain)!.group(1)!;
        for (final m in RegExp(r'\[([^\]]+)\]').allMatches(head)) {
          final label = m.group(1)!;
          final stream = RegExp(r'^(\d+):[va]$').firstMatch(label);
          if (stream != null) {
            expect(int.parse(stream.group(1)!), lessThan(inputCount), reason: chain);
          } else {
            expect(defined, contains(label), reason: chain);
          }
        }
        defined.add(RegExp(r'\[([^\]]+)\]$').firstMatch(chain)!.group(1)!);
      }
      expect(defined, contains('vout'));
    });
  });

  group('export size', () {
    test('short edge sets the scale and both sides stay even', () {
      final s = exportSize(1080, 1920, 720);
      expect([s.width, s.height], [720, 1280]);
      final wide = exportSize(2520, 1080, 1080);
      expect([wide.width, wide.height], [2520, 1080]);
      final odd = exportSize(1080, 1350, 721);
      expect(odd.width.isEven && odd.height.isEven, isTrue);
    });
  });
}
