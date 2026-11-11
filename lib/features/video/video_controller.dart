import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../canvas/layer.dart';
import '../../core/history.dart';
import '../../core/project_store.dart';
import 'video_project.dart';

/// Timeline editing operations, selection and undo history for a video project.
class VideoController extends ChangeNotifier {
  VideoController(this.project) : _history = History(jsonEncode(project.toJson()));

  VideoProject project;
  final History _history;
  String? selectedClipId;
  String? selectedOverlayId;
  String? selectedAudioId;
  Timer? _saveTimer;
  bool _dirty = false;

  /// Runs after any edit that can change timing, so playback can re-sync.
  VoidCallback? onTimelineChanged;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  VideoClip? get selectedClip => _find(project.clips, (c) => c.id == selectedClipId);
  CanvasLayer? get selectedOverlay => _find(project.overlays, (o) => o.id == selectedOverlayId);
  AudioTrack? get selectedAudio => _find(project.audio, (a) => a.id == selectedAudioId);

  T? _find<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }

  void selectClip(String? id) {
    selectedClipId = id;
    selectedOverlayId = null;
    selectedAudioId = null;
    notifyListeners();
  }

  void selectOverlay(String? id) {
    selectedOverlayId = id;
    selectedClipId = null;
    selectedAudioId = null;
    notifyListeners();
  }

  void selectAudio(String? id) {
    selectedAudioId = id;
    selectedClipId = null;
    selectedOverlayId = null;
    notifyListeners();
  }

  void touch() {
    notifyListeners();
    onTimelineChanged?.call();
  }

  void commit() {
    _history.push(jsonEncode(project.toJson()));
    touch();
    _scheduleSave();
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), save);
  }

  void undo() => _restore(_history.undo());
  void redo() => _restore(_history.redo());

  void _restore(String? snapshot) {
    if (snapshot == null) return;
    project = VideoProject.fromJson(jsonDecode(snapshot) as Map<String, dynamic>);
    if (selectedClip == null) selectedClipId = null;
    if (selectedOverlay == null) selectedOverlayId = null;
    if (selectedAudio == null) selectedAudioId = null;
    touch();
    _scheduleSave();
  }

  void addClips(List<VideoClip> clips) {
    project.clips.addAll(clips);
    commit();
  }

  void addOverlay(CanvasLayer layer, int positionMs) {
    final end = project.durationMs;
    layer
      ..startMs = positionMs.clamp(0, end)
      ..endMs = (positionMs + 3000).clamp(0, end > 0 ? end : 3000);
    if (layer.endMs! <= layer.startMs!) {
      layer
        ..startMs = 0
        ..endMs = end;
    }
    project.overlays.add(layer);
    selectOverlay(layer.id);
    commit();
  }

  void addAudio(AudioTrack track) {
    project.audio.add(track);
    selectAudio(track.id);
    commit();
  }

  /// Splits the clip under [timeMs] in two. Returns false if the time sits too
  /// close to either end of the clip to leave two usable parts.
  bool splitAt(int timeMs) {
    final second = _cut(timeMs);
    if (second == null) return false;
    selectClip(second.id);
    commit();
    return true;
  }

  /// Cuts the clip under [timeMs] in two without recording history, returning
  /// the second part, or null when the time is too near either end.
  VideoClip? _cut(int timeMs) {
    if (project.clips.isEmpty) return null;
    final index = project.clipIndexAt(timeMs);
    final clip = project.clips[index];
    final offset = timeMs - project.startOf(index);
    const minimum = 100;
    if (offset < minimum || clip.durationMs - offset < minimum) return null;
    final sourcePoint = clip.inMs + (offset * clip.speed).round();
    final second = clip.copy(newIdentity: true)..inMs = sourcePoint;
    clip
      ..outMs = sourcePoint
      ..transition = TransitionType.none;
    project.clips.insert(index + 1, second);
    return second;
  }

  /// Index of the clip before the cut nearest [timeMs], when one is within
  /// [toleranceMs].
  int? cutNear(int timeMs, {int toleranceMs = 250}) {
    for (var i = 0; i < project.clips.length - 1; i++) {
      if ((project.startOf(i + 1) - timeMs).abs() <= toleranceMs) return i;
    }
    return null;
  }

  /// Puts a transition at [timeMs]: on the cut already there, or on a new cut
  /// made there. Returns false when the time is at the very start or end.
  bool addTransitionAt(int timeMs, void Function(VideoClip before) apply) {
    var index = cutNear(timeMs);
    if (index == null) {
      if (_cut(timeMs) == null) return false;
      index = project.clipIndexAt(timeMs) - 1;
      if (index < 0) return false;
    }
    apply(project.clips[index]);
    commit();
    return true;
  }

  /// Gives the stretch of the timeline from [startMs] to [endMs] the effect
  /// [effectId] (null removes effects), cutting clips at both ends as needed.
  /// Returns the clips it changed.
  List<VideoClip> applyEffectRange(String? effectId, int startMs, int endMs) {
    final total = project.durationMs;
    final start = startMs.clamp(0, total), end = endMs.clamp(0, total);
    if (end - start < 100) return const [];
    _cut(end);
    _cut(start);
    final changed = <VideoClip>[];
    for (var i = 0; i < project.clips.length; i++) {
      final from = project.startOf(i), to = from + project.clips[i].durationMs;
      // A clip counts when most of it sits inside the stretch.
      final overlap = (to < end ? to : end) - (from > start ? from : start);
      if (overlap > project.clips[i].durationMs / 2) {
        project.clips[i].effect = effectId;
        changed.add(project.clips[i]);
      }
    }
    commit();
    return changed;
  }

  void deleteClip(VideoClip clip) {
    final i = project.clips.indexOf(clip);
    if (i < 0) return;
    project.clips.removeAt(i);
    if (selectedClipId == clip.id) selectedClipId = null;
    commit();
  }

  void duplicateClip(VideoClip clip) {
    final i = project.clips.indexOf(clip);
    final copy = clip.copy(newIdentity: true);
    project.clips.insert(i + 1, copy);
    selectClip(copy.id);
    commit();
  }

  void moveClip(VideoClip clip, int delta) {
    final from = project.clips.indexOf(clip);
    final to = (from + delta).clamp(0, project.clips.length - 1);
    if (to == from) return;
    project.clips
      ..removeAt(from)
      ..insert(to, clip);
    commit();
  }

  void trimStart(VideoClip clip, int timelineDeltaMs) {
    final next = clip.inMs + (timelineDeltaMs * clip.speed).round();
    clip.inMs = next.clamp(0, clip.outMs - 200);
    touch();
  }

  void trimEnd(VideoClip clip, int timelineDeltaMs) {
    final next = clip.outMs + (timelineDeltaMs * clip.speed).round();
    clip.outMs = next.clamp(clip.inMs + 200, clip.sourceMs);
    touch();
  }

  /// Points a clip at a processed copy of its video, such as a reversed one.
  /// It gets a new identity so playback opens the new file. The old file stays
  /// until clean-up finds no project using it, so undo keeps working.
  void replaceSource(VideoClip clip, {required String path, required int sourceMs, required bool hasAudio, bool resetTrim = true}) {
    final index = project.clips.indexOf(clip);
    if (index < 0) return;
    final json = clip.copy(newIdentity: true).toJson()
      ..['path'] = path
      ..['sourceMs'] = sourceMs
      ..['hasAudio'] = hasAudio;
    if (resetTrim) {
      json['inMs'] = 0;
      json['outMs'] = sourceMs;
    }
    final next = VideoClip.fromJson(json);
    project.clips[index] = next;
    selectClip(next.id);
    commit();
  }

  /// Moves a clip's sound to its own track, leaving the clip silent.
  void detachAudio(VideoClip clip, AudioTrack track) {
    clip.volume = 0;
    project.audio.add(track);
    commit();
  }

  void setFormat(int width, int height) {
    project
      ..width = width
      ..height = height;
    commit();
  }

  void deleteOverlay(CanvasLayer layer) {
    project.overlays.remove(layer);
    if (selectedOverlayId == layer.id) selectedOverlayId = null;
    commit();
  }

  /// Cuts [track] in two at timeline time [timeMs]. Returns false when the time
  /// is outside the track or too near an end to leave two usable parts.
  bool splitAudioAt(AudioTrack track, int timeMs) {
    final offset = timeMs - track.startMs;
    const minimum = 100;
    if (offset < minimum || track.durationMs - offset < minimum) return false;
    final second = track.duplicate()
      ..startMs = timeMs
      ..inMs = track.inMs + offset
      ..durationMs = track.durationMs - offset
      ..fadeInMs = 0;
    track
      ..durationMs = offset
      ..fadeOutMs = 0;
    project.audio.insert(project.audio.indexOf(track) + 1, second);
    selectAudio(second.id);
    commit();
    return true;
  }

  /// Trims the start of [track], keeping the rest where it was on the timeline.
  void trimAudioStart(AudioTrack track, int timelineDeltaMs) {
    final delta = timelineDeltaMs.clamp(-track.inMs, track.durationMs - 200);
    track
      ..inMs += delta
      ..startMs += delta
      ..durationMs -= delta;
    if (track.startMs < 0) {
      track
        ..inMs -= track.startMs
        ..durationMs += track.startMs
        ..startMs = 0;
    }
    touch();
  }

  void duplicateAudio(AudioTrack track) {
    final copy = track.duplicate()..startMs = track.startMs + track.durationMs;
    project.audio.insert(project.audio.indexOf(track) + 1, copy);
    selectAudio(copy.id);
    commit();
  }

  void deleteAudio(AudioTrack track) {
    project.audio.remove(track);
    if (selectedAudioId == track.id) selectedAudioId = null;
    commit();
  }

  /// Saves pending edits. An untouched project is not saved.
  Future<void> flush() async {
    if (_dirty) await save();
  }

  Future<void> save() {
    _dirty = false;
    return ProjectStore.instance.save(
      ProjectEntry(id: project.id, name: project.name, type: ProjectType.video, updatedAt: DateTime.now(), data: project.toJson()),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
