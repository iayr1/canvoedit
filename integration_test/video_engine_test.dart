import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/core/color/grade.dart';
import 'package:canvo_edit/features/video/clip_tools.dart';
import 'package:canvo_edit/features/video/export_engine_native.dart';
import 'package:canvo_edit/features/video/ffmpeg_graph.dart';
import 'package:canvo_edit/features/video/playback_engine.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Runs the video engine on a real device against real FFmpeg and real players.
/// Every input is generated here, in the app's private temp folder.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String dir;
  late String clipAudio; // 4 s, 640x360, solid colour, has sound.
  late String clipSilent; // 3 s, 360x640, moving pattern, no sound.
  late String music; // 8 s tone.
  late String photo;
  var counter = 0;

  Future<void> ffmpeg(List<String> args) async {
    final session = await FFmpegKit.executeWithArguments(['-y', '-hide_banner', ...args]);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      fail('FFmpeg failed: ${args.join(' ')}\n${await session.getAllLogsAsString()}');
    }
  }

  Future<String> pngOf(int w, int h, void Function(Canvas, Size) paint) async {
    final image = await SceneRenderer.rasterize(w, h, paint);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = '$dir/png-${counter++}.png';
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    return path;
  }

  /// Exports and checks the file really has the promised length, size and tracks.
  Future<String> exportAndCheck(
    VideoProject project, {
    int width = 360,
    int height = 640,
    int fps = 30,
    Map<String, String> overlays = const {},
    Map<String, String> vignettes = const {},
  }) async {
    final out = '$dir/out-${counter++}.mp4';
    final args = buildExportArgs(
      project: project,
      settings: ExportSettings(width: width, height: height, fps: fps),
      outputPath: out,
      overlayPngs: overlays,
      vignettePngs: vignettes,
    );
    var lastProgress = 0.0;
    final error = await ExportEngine.run(args, durationMs: project.durationMs, onProgress: (p) => lastProgress = p);
    expect(error, isNull, reason: 'args: ${args.join(' ')}');
    expect(lastProgress, greaterThan(0), reason: 'progress was never reported');

    final info = (await FFprobeKit.getMediaInformation(out)).getMediaInformation()!;
    final seconds = double.parse(info.getDuration()!);
    expect(seconds, closeTo(project.durationMs / 1000, .3), reason: 'output length');
    final streams = info.getStreams();
    final video = streams.firstWhere((s) => s.getType() == 'video');
    expect(video.getWidth(), width);
    expect(video.getHeight(), height);
    expect(streams.any((s) => s.getType() == 'audio'), isTrue, reason: 'every export carries audio');
    return out;
  }

  /// Reads the pixel at a fractional position of the frame at [seconds].
  Future<List<int>> pixelAt(String video, double seconds, {double x = .5, double y = .5}) async {
    final png = '$dir/frame-${counter++}.png';
    await ffmpeg(['-ss', seconds.toStringAsFixed(3), '-i', video, '-frames:v', '1', png]);
    final codec = await ui.instantiateImageCodec(await File(png).readAsBytes());
    final image = (await codec.getNextFrame()).image;
    final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = ((y * (image.height - 1)).round() * image.width + (x * (image.width - 1)).round()) * 4;
    return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
  }

  VideoClip colorClip() => VideoClip(path: clipAudio, kind: ClipKind.video, sourceMs: 4000, hasAudio: true);
  VideoClip patternClip() => VideoClip(path: clipSilent, kind: ClipKind.video, sourceMs: 3000);

  setUpAll(() async {
    SceneRenderer.useGoogleFonts = false;
    final temp = await getTemporaryDirectory();
    final work = Directory('${temp.path}/engine-test');
    if (await work.exists()) await work.delete(recursive: true);
    await work.create(recursive: true);
    dir = work.path;
    clipAudio = '$dir/a.mp4';
    clipSilent = '$dir/b.mp4';
    music = '$dir/music.m4a';
    await ffmpeg([
      '-f', 'lavfi', '-i', 'color=c=0x804020:s=640x360:r=30:d=4',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=4',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-shortest', clipAudio,
    ]);
    await ffmpeg(['-f', 'lavfi', '-i', 'testsrc2=s=360x640:r=24:d=3', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', clipSilent]);
    await ffmpeg(['-f', 'lavfi', '-i', 'sine=frequency=880:duration=8', '-c:a', 'aac', music]);
    photo = await pngOf(800, 600, (c, s) => c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2060A0)));
  });

  testWidgets('probe reports length and whether there is sound', (tester) async {
    final a = await ExportEngine.probe(clipAudio);
    expect(a.durationMs, closeTo(4000, 150));
    expect(a.hasAudio, isTrue);
    final b = await ExportEngine.probe(clipSilent);
    expect(b.durationMs, closeTo(3000, 150));
    expect(b.hasAudio, isFalse);
  });

  testWidgets('thumbnails are extracted', (tester) async {
    final thumb = await ExportEngine.extractThumbnail(clipAudio, 500);
    expect(thumb, isNotNull);
    expect(await File(thumb!).length(), greaterThan(0));
  });

  testWidgets('single clip exports', (tester) async {
    await exportAndCheck(VideoProject(clips: [colorClip()]));
  });

  testWidgets('a clip with no sound still exports with a silent track', (tester) async {
    await exportAndCheck(VideoProject(clips: [patternClip()]));
  });

  testWidgets('a photo clip exports', (tester) async {
    await exportAndCheck(VideoProject(clips: [VideoClip(path: photo, kind: ClipKind.image, sourceMs: 600000, outMs: 2000)]));
  });

  testWidgets('trim and fill export', (tester) async {
    await exportAndCheck(VideoProject(clips: [
      colorClip()
        ..inMs = 1000
        ..outMs = 2500
        ..fit = ClipFit.fill
        ..flipH = true,
    ]));
  });

  for (final speed in [.25, .5, 2.0, 4.0]) {
    testWidgets('speed ${speed}x keeps the right length', (tester) async {
      await exportAndCheck(VideoProject(clips: [colorClip()..speed = speed]));
    });
  }

  testWidgets('hard cuts join clips of different sizes and rates', (tester) async {
    await exportAndCheck(VideoProject(clips: [colorClip(), patternClip(), VideoClip(path: photo, kind: ClipKind.image, sourceMs: 600000, outMs: 1000)]));
  });

  for (final type in TransitionType.values.where((t) => t != TransitionType.none)) {
    testWidgets('transition ${type.name} exports', (tester) async {
      await exportAndCheck(VideoProject(clips: [colorClip()..transition = type, patternClip()]));
    });
  }

  testWidgets('cut then transition then cut, mixing everything', (tester) async {
    final p = VideoProject(clips: [
      colorClip(),
      patternClip()..transition = TransitionType.crossfade,
      colorClip()
        ..grade.filterId = 'teal_amber'
        ..speed = 2
        ..transition = TransitionType.slideLeft,
      VideoClip(path: photo, kind: ClipKind.image, sourceMs: 600000, outMs: 2000),
      patternClip(),
    ], audio: [
      AudioTrack(path: music, name: 'm', sourceMs: 8000, startMs: 1000, inMs: 500, durationMs: 5000, fadeInMs: 500, fadeOutMs: 500),
    ]);
    await exportAndCheck(p);
  });

  testWidgets('landscape, 60 fps and music longer than the video', (tester) async {
    await exportAndCheck(
      VideoProject(width: 1920, height: 1080, clips: [colorClip()], audio: [AudioTrack(path: music, name: 'm', sourceMs: 8000)]),
      width: 640,
      height: 360,
      fps: 60,
    );
  });

  const looks = <String, Map<String, double>>{
    'brightness up': {'brightness': .5},
    'brightness down': {'brightness': -.4},
    'exposure down': {'exposure': -.5},
    'contrast': {'contrast': .4},
    'desaturate': {'saturation': -1},
    'warm': {'temperature': .6},
    'fade': {'fade': .6},
    'hue': {'hue': 40},
    'sepia': {'sepia': 1},
    'lift and gain': {'liftB': .5, 'gainR': .4},
  };

  // The whole point of one colour pipeline: exports must match what the matrix,
  // and so the on-screen preview, says they should be.
  group('exported colour matches the preview matrix', () {
    List<int>? source;

    Future<List<int>> sourcePixel() async => source ??= await pixelAt(
      await exportAndCheck(VideoProject(clips: [colorClip()])),
      1,
    );

    void check(List<int> base, List<int> actual, ColorMatrix m, String name) {
      final expected = <double>[
        for (var r = 0; r < 3; r++)
          (m[r * 5] * base[0] + m[r * 5 + 1] * base[1] + m[r * 5 + 2] * base[2] + m[r * 5 + 4]).clamp(0.0, 255.0),
      ];
      debugPrint('COLOUR $name base=$base expected=${expected.map((e) => e.round()).toList()} actual=$actual');
      for (var i = 0; i < 3; i++) {
        expect(actual[i], closeTo(expected[i], 10), reason: '$name channel $i: expected $expected, got $actual');
      }
    }

    looks.forEach((name, values) {
      testWidgets(name, (tester) async {
        final base = await sourcePixel();
        final grade = Grade(values: Map.of(values));
        final out = await exportAndCheck(VideoProject(clips: [colorClip()..grade = grade]));
        check(base, await pixelAt(out, 1), grade.matrix, name);
      });
    });

    for (final id in ['silver', 'teal_amber', 'neon', 'sepia_print']) {
      testWidgets('preset $id', (tester) async {
        final base = await sourcePixel();
        final grade = Grade(filterId: id);
        final out = await exportAndCheck(VideoProject(clips: [colorClip()..grade = grade]));
        check(base, await pixelAt(out, 1, x: .5, y: .5), grade.matrix, id);
      });
    }
  });

  testWidgets('a vignette PNG darkens corners but not the centre', (tester) async {
    final clip = colorClip();
    final vignette = await pngOf(360, 640, (c, s) => SceneRenderer.paintVignette(c, Offset.zero & s, 1));
    final out = await exportAndCheck(VideoProject(clips: [clip..fit = ClipFit.fill]), vignettes: {clip.id: vignette});
    final center = await pixelAt(out, 1);
    final corner = await pixelAt(out, 1, x: .01, y: .01);
    expect(center[0], greaterThan(corner[0] + 30), reason: 'center $center, corner $corner');
  });

  testWidgets('an overlay appears only during its time range', (tester) async {
    final layer = CanvasLayer.shape(ShapeKind.rectangle, fill: 0xFF00FF00, width: .5)
      ..startMs = 1000
      ..endMs = 2000;
    final png = await pngOf(360, 640, (c, s) => SceneRenderer.paintLayer(c, s, layer));
    final clip = colorClip()..fit = ClipFit.fill;
    final out = await exportAndCheck(VideoProject(clips: [clip], overlays: [layer]), overlays: {layer.id: png});
    final before = await pixelAt(out, .5);
    final during = await pixelAt(out, 1.5);
    final after = await pixelAt(out, 3);
    expect(during[1], greaterThan(200), reason: 'during $during');
    expect(before[1], lessThan(120), reason: 'before $before');
    expect(after[1], lessThan(120), reason: 'after $after');
  });

  testWidgets('reverse plays the clip backwards', (tester) async {
    ClipTools.directoryOverride = Directory(dir);
    // Brightness rises steadily, so a reversed copy must start bright and end dark.
    final ramp = '$dir/ramp.mp4';
    await ffmpeg(['-f', 'lavfi', '-i', "color=c=black:s=64x64:r=24:d=3,geq=lum='min(255,T*80)':cb=128:cr=128", '-c:v', 'libx264', '-pix_fmt', 'yuv420p', ramp]);
    final result = await ClipTools.reverse(VideoClip(path: ramp, kind: ClipKind.video, sourceMs: 3000), (_) {});
    expect(result.durationMs, closeTo(3000, 200));
    final first = (await pixelAt(result.path, .1))[0], last = (await pixelAt(result.path, 2.8))[0];
    final originalFirst = (await pixelAt(ramp, .1))[0], originalLast = (await pixelAt(ramp, 2.8))[0];
    debugPrint('REVERSE first=$first last=$last original first=$originalFirst last=$originalLast');
    expect(first, closeTo(originalLast, 12));
    expect(last, closeTo(originalFirst, 12));
    expect(first, greaterThan(last + 100));
    final withSound = await ClipTools.reverse(colorClip(), (_) {});
    expect((await ExportEngine.probe(withSound.path)).hasAudio, isTrue);
    await exportAndCheck(VideoProject(clips: [VideoClip(path: result.path, kind: ClipKind.video, sourceMs: result.durationMs)]));
  });

  testWidgets('denoise keeps the video and its trim points working', (tester) async {
    ClipTools.directoryOverride = Directory(dir);
    final clip = colorClip();
    final result = await ClipTools.denoise(clip, (_) {});
    final probe = await ExportEngine.probe(result.path);
    expect(probe.hasAudio, isTrue);
    expect(probe.durationMs, closeTo(4000, 200));
  });

  testWidgets('detached audio is a sound-only file that follows clip speed', (tester) async {
    ClipTools.directoryOverride = Directory(dir);
    final result = await ClipTools.extractAudio(colorClip()..speed = 2, (_) {});
    expect(result.durationMs, closeTo(2000, 200));
    final info = (await FFprobeKit.getMediaInformation(result.path)).getMediaInformation()!;
    expect(info.getStreams().every((s) => s.getType() == 'audio'), isTrue);
    await exportAndCheck(VideoProject(
      clips: [colorClip()..volume = 0],
      audio: [AudioTrack(path: result.path, name: 'a', sourceMs: result.durationMs)],
    ));
  });

  testWidgets('an image overlay exports where it was placed', (tester) async {
    final image = await pngOf(100, 100, (c, s) => c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF00FF00)));
    await SceneRenderer.prepare([CanvasLayer.image(image, 100, 100)]);
    final layer = CanvasLayer.image(image, 100, 100, width: .5);
    final png = await pngOf(360, 640, (c, s) => SceneRenderer.paintLayer(c, s, layer));
    final out = await exportAndCheck(VideoProject(clips: [colorClip()..fit = ClipFit.fill], overlays: [layer]), overlays: {layer.id: png});
    expect((await pixelAt(out, 1))[1], greaterThan(200));
    expect((await pixelAt(out, 1, x: .05, y: .05))[1], lessThan(120));
  });

  testWidgets('cancel stops an export and is not reported as an error', (tester) async {
    final out = '$dir/cancelled.mp4';
    final long = VideoProject(clips: [for (var i = 0; i < 6; i++) colorClip()]);
    final args = buildExportArgs(project: long, settings: const ExportSettings(width: 1080, height: 1920), outputPath: out);
    final run = ExportEngine.run(args, durationMs: long.durationMs, onProgress: (_) {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await ExportEngine.cancel();
    expect(await run.timeout(const Duration(seconds: 30)), isNull);
  });

  testWidgets('the player follows the timeline across a cut', (tester) async {
    final project = VideoProject(clips: [
      colorClip()
        ..inMs = 500
        ..outMs = 2500,
      patternClip(),
    ]);
    final engine = PlaybackEngine(() => project);
    addTearDown(engine.dispose);
    engine.refresh();
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(engine.playerFor(project.clips[0]), isNotNull, reason: 'first clip never opened');

    engine.play();
    final seeksAtStart = engine.seekCount;
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    final player = engine.playerFor(project.clips[0])!;
    debugPrint('PLAYBACK position=${engine.positionMs} player=${player.value.position.inMilliseconds} playing=${player.value.isPlaying}');
    // The clock holds while the player starts up, so it can trail wall time.
    expect(engine.positionMs, inInclusiveRange(500, 1500));
    expect(player.value.isPlaying, isTrue);
    // Source time is timeline time plus the 500 ms trim.
    expect(player.value.position.inMilliseconds, closeTo(engine.positionMs + 500, 500));

    await Future<void>.delayed(const Duration(milliseconds: 2000));
    expect(engine.frame!.clip, project.clips[1], reason: 'should have crossed the cut');
    final second = engine.playerFor(project.clips[1]);
    expect(second, isNotNull, reason: 'second clip was not ready after the cut');
    debugPrint('PLAYBACK position=${engine.positionMs} second=${second!.value.position.inMilliseconds} playing=${second.value.isPlaying}');
    expect(second.value.isPlaying, isTrue);
    expect(second.value.position.inMilliseconds, closeTo(engine.positionMs - 2000, 600));
    // Repeated seeks restart the decoder and leave the preview black.
    expect(engine.seekCount - seeksAtStart, lessThanOrEqualTo(3), reason: 'players were seeked constantly');

    engine.pause();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(second.value.isPlaying, isFalse);
  });

  testWidgets('two players run together during a transition', (tester) async {
    final project = VideoProject(clips: [
      colorClip()
        ..transition = TransitionType.crossfade
        ..transitionMs = 1500,
      patternClip(),
    ]);
    final engine = PlaybackEngine(() => project);
    addTearDown(engine.dispose);
    engine.refresh();
    await Future<void>.delayed(const Duration(seconds: 1));
    engine.seek(2200);
    engine.play();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final f = engine.frame!;
    expect(f.next, project.clips[1], reason: 'should be inside the transition at ${engine.positionMs}');
    expect(engine.playerFor(project.clips[0])?.value.isPlaying, isTrue);
    expect(engine.playerFor(project.clips[1])?.value.isPlaying, isTrue);
  });

  testWidgets('scrubbing while paused moves the picture', (tester) async {
    final project = VideoProject(clips: [colorClip()]);
    final engine = PlaybackEngine(() => project);
    addTearDown(engine.dispose);
    engine.refresh();
    await Future<void>.delayed(const Duration(seconds: 1));
    engine.seek(3000);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(engine.playerFor(project.clips[0])!.value.position.inMilliseconds, closeTo(3000, 150));
  });
}
