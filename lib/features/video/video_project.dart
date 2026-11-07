import 'dart:math' as math;

import '../../canvas/layer.dart';
import '../../core/color/grade.dart';
import '../../core/media.dart';

enum ClipKind { video, image }

enum ClipFit { fit, fill }

/// A transition into the next clip. [xfade] is the FFmpeg filter's name for it.
enum TransitionType {
  none('None', ''),
  crossfade('Crossfade', 'fade'),
  fadeBlack('Dip to black', 'fadeblack'),
  fadeWhite('Dip to white', 'fadewhite'),
  wipeLeft('Wipe left', 'wipeleft'),
  wipeRight('Wipe right', 'wiperight'),
  slideLeft('Slide left', 'slideleft'),
  slideRight('Slide right', 'slideright'),
  circleOpen('Circle open', 'circleopen');

  const TransitionType(this.label, this.xfade);
  final String label;
  final String xfade;
}

class VideoClip {
  VideoClip({
    String? id,
    required this.path,
    required this.kind,
    required this.sourceMs,
    this.inMs = 0,
    int? outMs,
    this.speed = 1,
    this.volume = 1,
    this.hasAudio = false,
    this.fit = ClipFit.fit,
    this.flipH = false,
    Grade? grade,
    this.transition = TransitionType.none,
    this.transitionMs = 500,
    this.thumbnail,
  }) : id = id ?? newId(),
       outMs = outMs ?? sourceMs,
       grade = grade ?? Grade();

  factory VideoClip.fromJson(Map<String, dynamic> j) => VideoClip(
    id: j['id'] as String,
    path: j['path'] as String,
    kind: ClipKind.values.byName(j['kind'] as String),
    sourceMs: j['sourceMs'] as int,
    inMs: j['inMs'] as int,
    outMs: j['outMs'] as int,
    speed: (j['speed'] as num).toDouble(),
    volume: (j['volume'] as num).toDouble(),
    hasAudio: j['hasAudio'] as bool? ?? false,
    fit: ClipFit.values.byName(j['fit'] as String? ?? 'fit'),
    flipH: j['flipH'] as bool? ?? false,
    grade: Grade.fromJson((j['grade'] as Map?)?.cast<String, dynamic>()),
    transition: TransitionType.values.byName(j['transition'] as String? ?? 'none'),
    transitionMs: j['transitionMs'] as int? ?? 500,
    thumbnail: j['thumbnail'] as String?,
  );

  final String id;
  final String path;
  final ClipKind kind;

  /// Length of the source file. Image clips can be any length.
  final int sourceMs;
  int inMs;
  int outMs;
  double speed;
  double volume;
  bool hasAudio;
  ClipFit fit;
  bool flipH;
  Grade grade;

  /// Transition into the following clip.
  TransitionType transition;
  int transitionMs;
  String? thumbnail;

  /// Length this clip occupies on the timeline.
  int get durationMs => ((outMs - inMs) / speed).round();

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'kind': kind.name,
    'sourceMs': sourceMs,
    'inMs': inMs,
    'outMs': outMs,
    'speed': speed,
    'volume': volume,
    'hasAudio': hasAudio,
    'fit': fit.name,
    'flipH': flipH,
    'grade': grade.toJson(),
    'transition': transition.name,
    'transitionMs': transitionMs,
    'thumbnail': thumbnail,
  };

  VideoClip copy({bool newIdentity = false}) {
    final json = toJson();
    if (newIdentity) json['id'] = newId();
    return VideoClip.fromJson(json);
  }
}

class AudioTrack {
  AudioTrack({
    String? id,
    required this.path,
    required this.name,
    required this.sourceMs,
    this.startMs = 0,
    this.inMs = 0,
    int? durationMs,
    this.volume = .8,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
  }) : id = id ?? newId(),
       durationMs = durationMs ?? sourceMs;

  factory AudioTrack.fromJson(Map<String, dynamic> j) => AudioTrack(
    id: j['id'] as String,
    path: j['path'] as String,
    name: j['name'] as String,
    sourceMs: j['sourceMs'] as int,
    startMs: j['startMs'] as int,
    inMs: j['inMs'] as int,
    durationMs: j['durationMs'] as int,
    volume: (j['volume'] as num).toDouble(),
    fadeInMs: j['fadeInMs'] as int? ?? 0,
    fadeOutMs: j['fadeOutMs'] as int? ?? 0,
  );

  final String id;
  final String path;
  final String name;
  final int sourceMs;
  int startMs;
  int inMs;
  int durationMs;
  double volume;
  int fadeInMs;
  int fadeOutMs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'sourceMs': sourceMs,
    'startMs': startMs,
    'inMs': inMs,
    'durationMs': durationMs,
    'volume': volume,
    'fadeInMs': fadeInMs,
    'fadeOutMs': fadeOutMs,
  };
}

/// What is on screen at a moment in time: one clip, or two during a transition.
class TimelineFrame {
  const TimelineFrame(this.clip, this.clipTimeMs, {this.next, this.nextTimeMs = 0, this.progress = 0});
  final VideoClip clip;

  /// Position in the clip's source file.
  final int clipTimeMs;
  final VideoClip? next;
  final int nextTimeMs;

  /// Transition progress from 0 to 1.
  final double progress;
}

class VideoProject {
  VideoProject({
    String? id,
    this.name = 'Untitled video',
    this.width = 1080,
    this.height = 1920,
    this.fps = 30,
    List<VideoClip>? clips,
    List<AudioTrack>? audio,
    List<CanvasLayer>? overlays,
  }) : id = id ?? newId(),
       clips = clips ?? [],
       audio = audio ?? [],
       overlays = overlays ?? [];

  factory VideoProject.fromJson(Map<String, dynamic> j) => VideoProject(
    id: j['id'] as String,
    name: j['name'] as String,
    width: j['width'] as int,
    height: j['height'] as int,
    fps: j['fps'] as int? ?? 30,
    clips: (j['clips'] as List).map((e) => VideoClip.fromJson((e as Map).cast())).toList(),
    audio: (j['audio'] as List).map((e) => AudioTrack.fromJson((e as Map).cast())).toList(),
    overlays: (j['overlays'] as List).map((e) => CanvasLayer.fromJson((e as Map).cast())).toList(),
  );

  final String id;
  String name;
  int width;
  int height;
  int fps;
  List<VideoClip> clips;
  List<AudioTrack> audio;
  List<CanvasLayer> overlays;

  double get aspectRatio => width / height;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'width': width,
    'height': height,
    'fps': fps,
    'clips': clips.map((c) => c.toJson()).toList(),
    'audio': audio.map((a) => a.toJson()).toList(),
    'overlays': overlays.map((o) => o.toJson()).toList(),
  };

  /// Length of the transition out of clip [i], limited so a transition can never
  /// use more than half of either clip it touches. Preview and export both read
  /// this, so they agree on timing.
  int transitionMsAfter(int i) {
    if (i < 0 || i >= clips.length - 1) return 0;
    final clip = clips[i];
    if (clip.transition == TransitionType.none) return 0;
    final limit = math.min(clip.durationMs, clips[i + 1].durationMs) ~/ 2;
    return math.min(clip.transitionMs, limit);
  }

  int startOf(int index) {
    var t = 0;
    for (var i = 0; i < index; i++) {
      t += clips[i].durationMs - transitionMsAfter(i);
    }
    return t;
  }

  int get durationMs {
    if (clips.isEmpty) return 0;
    return startOf(clips.length - 1) + clips.last.durationMs;
  }

  int _sourceTime(VideoClip clip, int offsetMs) => clip.inMs + (offsetMs * clip.speed).round();

  /// Resolves a timeline time to what should be showing, or null when empty.
  TimelineFrame? frameAt(int timeMs) {
    if (clips.isEmpty) return null;
    final t = timeMs.clamp(0, durationMs);
    for (var i = 0; i < clips.length; i++) {
      final start = startOf(i);
      final clip = clips[i];
      final end = start + clip.durationMs;
      if (t > end) continue;
      if (i == clips.length - 1) return TimelineFrame(clip, _sourceTime(clip, t - start));
      final overlap = transitionMsAfter(i);
      final nextStart = end - overlap;
      if (t < nextStart) return TimelineFrame(clip, _sourceTime(clip, t - start));
      if (overlap == 0) continue;
      final next = clips[i + 1];
      return TimelineFrame(
        clip,
        _sourceTime(clip, t - start),
        next: next,
        nextTimeMs: _sourceTime(next, t - nextStart),
        progress: (t - nextStart) / overlap,
      );
    }
    final last = clips.last;
    return TimelineFrame(last, last.outMs);
  }

  int clipIndexAt(int timeMs) {
    for (var i = clips.length - 1; i >= 0; i--) {
      if (timeMs >= startOf(i)) return i;
    }
    return 0;
  }
}
