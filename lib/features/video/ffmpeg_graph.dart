import '../../core/color/grade.dart';
import 'effect_library.dart';
import 'transition_library.dart';
import 'video_project.dart';

/// The video encoder arguments. Encoding is isolated here because the choice has
/// licensing consequences: libx264 is GPL, and an LGPL build of FFmpeg would use
/// the phone's hardware encoder instead.
class VideoEncoder {
  const VideoEncoder(this.args);
  final List<String> args;

  static const x264 = VideoEncoder(['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20']);
  static VideoEncoder hardwareAndroid(int bitrateMbps) => VideoEncoder(['-c:v', 'h264_mediacodec', '-b:v', '${bitrateMbps}M']);
}

class ExportSettings {
  const ExportSettings({required this.width, required this.height, this.fps = 30, this.encoder = VideoEncoder.x264});
  final int width;
  final int height;
  final int fps;
  final VideoEncoder encoder;
}

String _s(int ms) => (ms / 1000).toStringAsFixed(3);
String _n(double v) => v.toStringAsFixed(4);

/// Expresses a colour matrix as a colorchannelmixer filter. Colours run 0 to 1
/// there, and the filter has no constant term, so offsets go in the alpha column:
/// the frame is converted to RGBA first, where alpha is always 1.
String colorMixerFilter(ColorMatrix m) {
  double c(double v) => v.clamp(-2.0, 2.0);
  return 'colorchannelmixer='
      'rr=${_n(c(m[0]))}:rg=${_n(c(m[1]))}:rb=${_n(c(m[2]))}:ra=${_n(c(m[4] / 255))}:'
      'gr=${_n(c(m[5]))}:gg=${_n(c(m[6]))}:gb=${_n(c(m[7]))}:ga=${_n(c(m[9] / 255))}:'
      'br=${_n(c(m[10]))}:bg=${_n(c(m[11]))}:bb=${_n(c(m[12]))}:ba=${_n(c(m[14] / 255))}';
}

/// atempo accepts 0.5 to 2 per instance, so other speeds need a chain.
String atempoChain(double speed) {
  final parts = <String>[];
  var s = speed;
  while (s > 2) {
    parts.add('atempo=2');
    s /= 2;
  }
  while (s < .5) {
    parts.add('atempo=0.5');
    s /= .5;
  }
  if ((s - 1).abs() > 1e-4) parts.add('atempo=${_n(s)}');
  return parts.join(',');
}

/// Builds the FFmpeg argument list for a whole project.
///
/// [overlayPngs] holds one full-frame transparent PNG per visible overlay layer,
/// keyed by layer id, drawn by the app's renderer so text looks the same as in
/// the preview. [vignettePngs] is keyed by clip id.
List<String> buildExportArgs({
  required VideoProject project,
  required ExportSettings settings,
  required String outputPath,
  Map<String, String> overlayPngs = const {},
  Map<String, String> vignettePngs = const {},
}) {
  if (project.clips.isEmpty) {
    throw ArgumentError('Cannot export a project with no clips');
  }
  final w = settings.width, h = settings.height, fps = settings.fps;
  final args = <String>['-y', '-hide_banner'];
  final graph = <String>[];
  var inputCount = 0;

  int addInput(List<String> inputArgs) {
    args.addAll(inputArgs);
    return inputCount++;
  }

  final clipInputs = <int>[];
  for (final clip in project.clips) {
    final sourceSeconds = _s(clip.outMs - clip.inMs);
    clipInputs.add(
      addInput(
        clip.kind == ClipKind.video
            ? ['-ss', _s(clip.inMs), '-t', sourceSeconds, '-i', clip.path]
            : ['-loop', '1', '-framerate', '$fps', '-t', sourceSeconds, '-i', clip.path],
      ),
    );
  }

  // Normalise every clip to the same size, rate, time base and format.
  for (var i = 0; i < project.clips.length; i++) {
    final clip = project.clips[i];
    final input = clipInputs[i];
    final filters = <String>['setpts=PTS-STARTPTS'];
    if (clip.speed != 1) filters.add('setpts=PTS/${_n(clip.speed)}');
    filters.add('fps=$fps');
    if (clip.fit == ClipFit.fit) {
      filters
        ..add('scale=$w:$h:force_original_aspect_ratio=decrease')
        ..add('pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black');
    } else {
      filters
        ..add('scale=$w:$h:force_original_aspect_ratio=increase')
        ..add('crop=$w:$h');
    }
    filters.add('setsar=1');
    if (clip.flipH) filters.add('hflip');
    if (!clip.grade.isNeutral) {
      filters
        ..add('format=rgba')
        ..add(colorMixerFilter(clip.grade.matrix));
    }
    final effect = EffectLibrary.instance.byId(clip.effect);
    if (effect != null) filters.addAll(effectFilters(effect, width: w, height: h, fps: fps, durationMs: clip.durationMs));
    final vignette = vignettePngs[clip.id];
    if (vignette != null) {
      final vigInput = addInput(['-i', vignette]);
      graph.add('[$input:v]${filters.join(',')}[vbase$i]');
      graph.add('[vbase$i][$vigInput:v]overlay=0:0,format=yuv420p,settb=AVTB[v$i]');
    } else {
      graph.add('[$input:v]${filters.join(',')},format=yuv420p,settb=AVTB[v$i]');
    }

    final seconds = _s(clip.durationMs);
    if (clip.kind == ClipKind.video && clip.hasAudio && clip.volume > 0) {
      final audio = <String>['asetpts=PTS-STARTPTS'];
      final tempo = atempoChain(clip.speed);
      if (tempo.isNotEmpty) audio.add(tempo);
      audio
        ..add('volume=${_n(clip.volume)}')
        ..add('aformat=sample_rates=48000:channel_layouts=stereo')
        ..add('apad')
        ..add('atrim=duration=$seconds');
      graph.add('[$input:a]${audio.join(',')}[a$i]');
    } else {
      graph.add('anullsrc=r=48000:cl=stereo,atrim=duration=$seconds[a$i]');
    }
  }

  // Join clips one at a time, using concat for cuts and xfade for transitions.
  var videoLabel = 'v0';
  var audioLabel = 'a0';
  var timelineMs = project.clips.first.durationMs;
  for (var i = 1; i < project.clips.length; i++) {
    final overlap = project.transitionMsAfter(i - 1);
    final preset = TransitionLibrary.instance.forClip(project.clips[i - 1]);
    final vOut = 'vj$i', aOut = 'aj$i';
    if (overlap > 0) {
      final offset = _s(timelineMs - overlap);
      graph.add('[$videoLabel][v$i]xfade=transition=${preset!.xfadeTransition}:duration=${_s(overlap)}:offset=$offset,settb=AVTB[$vOut]');
      graph.add('[$audioLabel][a$i]acrossfade=d=${_s(overlap)}[$aOut]');
    } else {
      graph.add('[$videoLabel][v$i]concat=n=2:v=1:a=0,settb=AVTB[$vOut]');
      graph.add('[$audioLabel][a$i]concat=n=2:v=0:a=1[$aOut]');
    }
    videoLabel = vOut;
    audioLabel = aOut;
    timelineMs += project.clips[i].durationMs - overlap;
  }

  // Overlays are full-frame PNGs composited during their time range.
  var overlayIndex = 0;
  for (final layer in project.overlays) {
    final png = overlayPngs[layer.id];
    if (png == null) continue;
    final input = addInput(['-i', png]);
    final start = layer.startMs ?? 0;
    final end = layer.endMs ?? timelineMs;
    final out = 'vo$overlayIndex';
    graph.add("[$videoLabel][$input:v]overlay=0:0:enable='between(t,${_s(start)},${_s(end)})'[$out]");
    videoLabel = out;
    overlayIndex++;
  }
  graph.add('[$videoLabel]format=yuv420p[vout]');

  // Added audio is trimmed, faded and delayed, then mixed over the clip audio.
  final mixInputs = <String>['[$audioLabel]'];
  for (var i = 0; i < project.audio.length; i++) {
    final track = project.audio[i];
    if (track.startMs >= timelineMs) continue;
    final input = addInput(['-i', track.path]);
    final length = track.durationMs < timelineMs - track.startMs ? track.durationMs : timelineMs - track.startMs;
    final filters = <String>[
      'atrim=start=${_s(track.inMs)}:duration=${_s(length)}',
      'asetpts=PTS-STARTPTS',
      'volume=${_n(track.volume)}',
      'aformat=sample_rates=48000:channel_layouts=stereo',
    ];
    if (track.fadeInMs > 0) filters.add('afade=t=in:st=0:d=${_s(track.fadeInMs)}');
    if (track.fadeOutMs > 0) {
      filters.add('afade=t=out:st=${_s(length - track.fadeOutMs)}:d=${_s(track.fadeOutMs)}');
    }
    if (track.startMs > 0) filters.add('adelay=${track.startMs}|${track.startMs}');
    graph.add('[$input:a]${filters.join(',')}[m$i]');
    mixInputs.add('[m$i]');
  }
  var audioOut = audioLabel;
  if (mixInputs.length > 1) {
    graph.add('${mixInputs.join()}amix=inputs=${mixInputs.length}:duration=first:normalize=0[aout]');
    audioOut = 'aout';
  }

  args
    ..addAll(['-filter_complex', graph.join(';')])
    ..addAll(['-map', '[vout]', '-map', '[$audioOut]'])
    ..addAll(settings.encoder.args)
    ..addAll(['-pix_fmt', 'yuv420p', '-r', '$fps'])
    ..addAll(['-c:a', 'aac', '-b:a', '192k'])
    ..addAll(['-t', _s(timelineMs), '-movflags', '+faststart', outputPath]);
  return args;
}
