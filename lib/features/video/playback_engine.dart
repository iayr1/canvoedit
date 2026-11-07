import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'video_project.dart';

VideoPlayerController createPlayer(String path) => kIsWeb
    ? VideoPlayerController.networkUrl(Uri.parse(path))
    : VideoPlayerController.file(File(path));

/// Plays the timeline by driving one native player per on-screen clip from a
/// master clock, correcting any player that drifts away from it.
class PlaybackEngine extends ChangeNotifier {
  PlaybackEngine(this._project);

  final VideoProject Function() _project;
  final Map<String, VideoPlayerController> _players = {};
  final Set<String> _initializing = {};
  final Map<String, VideoPlayerController> _audioPlayers = {};
  final Set<String> _seeking = {};

  static const _tick = Duration(milliseconds: 33);
  static const _driftLimitMs = 280;

  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _anchorMs = 0;
  int positionMs = 0;
  bool playing = false;
  bool _disposed = false;

  VideoProject get project => _project();
  TimelineFrame? get frame => project.frameAt(positionMs);

  /// The ready player for a clip, if it has one yet.
  VideoPlayerController? playerFor(VideoClip clip) {
    final p = _players[clip.id];
    return p != null && p.value.isInitialized ? p : null;
  }

  void togglePlay() => playing ? pause() : play();

  void play() {
    if (project.clips.isEmpty) return;
    if (positionMs >= project.durationMs) positionMs = 0;
    playing = true;
    _anchorMs = positionMs;
    _clock
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) => _onTick());
    _sync(forceSeek: true);
    notifyListeners();
  }

  void pause() {
    playing = false;
    _timer?.cancel();
    _clock.stop();
    for (final p in _players.values) {
      if (p.value.isInitialized) p.pause();
    }
    for (final p in _audioPlayers.values) {
      if (p.value.isInitialized) p.pause();
    }
    notifyListeners();
  }

  void seek(int ms) {
    positionMs = ms.clamp(0, project.durationMs);
    if (playing) {
      _anchorMs = positionMs;
      _clock
        ..reset()
        ..start();
    }
    _sync(forceSeek: true);
    notifyListeners();
  }

  /// Call after an edit, since clips and timing may have changed.
  void refresh() {
    positionMs = positionMs.clamp(0, project.durationMs);
    _sync(forceSeek: true);
    notifyListeners();
  }

  void _onTick() {
    final next = _anchorMs + _clock.elapsedMilliseconds;
    if (next >= project.durationMs) {
      positionMs = project.durationMs;
      pause();
      return;
    }
    positionMs = next;
    _sync();
    notifyListeners();
  }

  void _sync({bool forceSeek = false}) {
    final f = frame;
    if (f == null) return;
    final index = project.clips.indexOf(f.clip);
    final wanted = <VideoClip>[f.clip, ?f.next];

    // Warm up the following clip so cuts do not stall on decoder start-up.
    final keep = <String>{for (final c in wanted) c.id};
    final after = index + (f.next == null ? 1 : 2);
    if (after < project.clips.length && project.clips[after].kind == ClipKind.video) {
      keep.add(project.clips[after].id);
      _ensure(project.clips[after]);
    }
    for (final id in _players.keys.toList()) {
      if (!keep.contains(id)) {
        _players.remove(id)!.dispose();
      }
    }

    _driveClip(f.clip, f.clipTimeMs, forceSeek);
    if (f.next != null) _driveClip(f.next!, f.nextTimeMs, forceSeek);
    _syncAudio(forceSeek);
  }

  void _ensure(VideoClip clip) {
    if (clip.kind != ClipKind.video) return;
    if (_players.containsKey(clip.id) || _initializing.contains(clip.id)) return;
    _initializing.add(clip.id);
    final player = createPlayer(clip.path);
    player.initialize().then((_) {
      _initializing.remove(clip.id);
      if (_disposed) {
        player.dispose();
        return;
      }
      _players[clip.id] = player;
      _sync(forceSeek: true);
      notifyListeners();
    }).catchError((Object e) {
      _initializing.remove(clip.id);
      debugPrint('Could not open clip ${clip.path}: $e');
    });
  }

  void _driveClip(VideoClip clip, int sourceMs, bool forceSeek) {
    _ensure(clip);
    final player = playerFor(clip);
    if (player == null) return;
    if (player.value.volume != clip.volume) player.setVolume(clip.volume.clamp(0.0, 1.0));
    if (player.value.playbackSpeed != clip.speed) player.setPlaybackSpeed(clip.speed);
    _align(clip.id, player, sourceMs, forceSeek);
    if (playing && !player.value.isPlaying) player.play();
    if (!playing && player.value.isPlaying) player.pause();
  }

  void _align(String key, VideoPlayerController player, int targetMs, bool forceSeek) {
    final drift = (player.value.position.inMilliseconds - targetMs).abs();
    final needed = forceSeek ? drift > 30 : (!playing && drift > 30) || drift > _driftLimitMs;
    if (!needed || _seeking.contains(key)) return;
    _seeking.add(key);
    player.seekTo(Duration(milliseconds: targetMs)).whenComplete(() => _seeking.remove(key));
  }

  void _syncAudio(bool forceSeek) {
    final tracks = project.audio;
    final ids = tracks.map((t) => t.id).toSet();
    for (final id in _audioPlayers.keys.toList()) {
      if (!ids.contains(id)) _audioPlayers.remove(id)!.dispose();
    }
    for (final track in tracks) {
      var player = _audioPlayers[track.id];
      if (player == null) {
        player = createPlayer(track.path);
        _audioPlayers[track.id] = player;
        player.initialize().catchError((Object e) {
          debugPrint('Could not open audio ${track.path}: $e');
        });
        continue;
      }
      if (!player.value.isInitialized) continue;
      final active = positionMs >= track.startMs && positionMs < track.startMs + track.durationMs;
      if (player.value.volume != track.volume) player.setVolume(track.volume.clamp(0.0, 1.0));
      if (!active || !playing) {
        if (player.value.isPlaying) player.pause();
        continue;
      }
      _align('audio-${track.id}', player, track.inMs + positionMs - track.startMs, forceSeek);
      if (!player.value.isPlaying) player.play();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final p in [..._players.values, ..._audioPlayers.values]) {
      p.dispose();
    }
    super.dispose();
  }
}
