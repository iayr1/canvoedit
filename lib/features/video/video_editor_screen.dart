import 'dart:async';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/art_image.dart';
import '../../app/theme.dart';
import '../../canvas/canvas_view.dart';
import '../../canvas/layer.dart';
import '../../canvas/renderer.dart';
import '../../core/artwork.dart';
import '../../core/media.dart';
import '../../core/media_picker.dart';
import '../shared/color_wheels.dart';
import '../shared/editor_chrome.dart';
import '../shared/grade_panels.dart';
import '../shared/layer_panels.dart';
import '../shared/library_sheet.dart';
import 'clip_tools.dart';
import 'effect_library.dart';
import 'export_engine.dart';
import 'playback_engine.dart';
import 'timeline_view.dart';
import 'transition_library.dart';
import 'video_controller.dart';
import 'video_export_sheet.dart';
import 'video_library_sheets.dart';
import 'video_preview.dart';
import 'video_project.dart';

enum _Panel { filters, adjust, color, speed, volume, transition, format, textStyle, audio, voiceover }

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key, required this.project});
  final VideoProject project;

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late final VideoController _c = VideoController(widget.project);
  late final PlaybackEngine _engine = PlaybackEngine(() => _c.project);
  _Panel? _panel;
  bool _importing = false;
  final _recorder = AudioRecorder();
  Timer? _recorderTicker;
  final _recordClock = Stopwatch();
  String? _recordPath;
  int _recordStartMs = 0;

  @override
  void initState() {
    super.initState();
    _c.onTimelineChanged = _engine.refresh;
    ImageBank.instance.addListener(_engine.refresh);
    _engine.refresh();
    for (final c in _c.project.clips) {
      if (c.kind == ClipKind.image) ImageBank.instance.load(c.path).ignore();
    }
    final missing = missingMediaCount(_c.project);
    if (missing > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _snack('$missing media file${missing == 1 ? ' is' : 's are'} missing from this project');
      });
    }
  }

  @override
  void dispose() {
    ImageBank.instance.removeListener(_engine.refresh);
    _recorderTicker?.cancel();
    _recorder.dispose();
    _engine.dispose();
    _c.flush();
    _c.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addMedia() async {
    final files = await MediaPicker.media(onError: _snack);
    await _importFiles(files);
  }

  Future<void> _record() async {
    final file = await MediaPicker.recordVideo(onError: _snack);
    if (file != null) await _importFiles([file]);
  }

  Future<void> _importFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    setState(() => _importing = true);
    final clips = <VideoClip>[];
    var failed = 0;
    for (final file in files) {
      try {
        clips.add(await _clipFrom(file));
      } catch (e) {
        debugPrint('Import failed for ${file.name}: $e');
        failed++;
      }
    }
    if (clips.isNotEmpty) _c.addClips(clips);
    if (mounted) setState(() => _importing = false);
    if (failed > 0) _snack('$failed file${failed == 1 ? '' : 's'} could not be imported');
  }

  Future<VideoClip> _clipFrom(XFile file) async {
    final path = await MediaLibrary.import(file);
    if (looksLikeImage(file)) {
      await ImageBank.instance.load(path);
      // A photo has no natural length, so it can be trimmed out to ten minutes.
      return VideoClip(path: path, kind: ClipKind.image, sourceMs: 600000, outMs: 3000);
    }
    final probe = await ExportEngine.probe(path);
    final duration = probe.durationMs ?? await _playerDuration(path);
    return VideoClip(path: path, kind: ClipKind.video, sourceMs: duration, hasAudio: probe.hasAudio, thumbnail: await ExportEngine.extractThumbnail(path, 0));
  }

  Future<int> _playerDuration(String path) async {
    final player = createPlayer(path);
    try {
      await player.initialize();
      return player.value.duration.inMilliseconds;
    } finally {
      await player.dispose();
    }
  }

  Future<void> _addMusic() async {
    final result = await MediaPicker.guard(() => FilePicker.pickFiles(type: FileType.audio), onError: _snack);
    if (result == null || result.isEmpty) return;
    final picked = result.first;
    if (picked.path == null) return;
    final path = await MediaLibrary.import(XFile(picked.path!, name: picked.name));
    final probe = await ExportEngine.probe(path);
    final duration = probe.durationMs ?? await _playerDuration(path);
    _c.addAudio(AudioTrack(path: path, name: picked.name, sourceMs: duration, startMs: _engine.positionMs));
    setState(() => _panel = _Panel.audio);
  }

  Future<void> _addOverlayImage() async {
    final file = await MediaPicker.image(onError: _snack);
    if (file == null) return;
    final path = await MediaLibrary.import(file);
    final image = await ImageBank.instance.load(path);
    _c.addOverlay(CanvasLayer.image(path, image.width, image.height, width: .4), _engine.positionMs);
  }

  bool get _isRecording => _recordPath != null;

  Future<void> _startVoiceover() async {
    if (!await _recorder.hasPermission()) {
      _snack('Microphone access is needed to record a voiceover');
      return;
    }
    final dir = await ClipTools.outputDir();
    final path = '${dir.path}/voice-${newId()}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _recordStartMs = _engine.positionMs;
    _recordClock
      ..reset()
      ..start();
    _recorderTicker = Timer.periodic(const Duration(milliseconds: 200), (_) => setState(() {}));
    // The video plays silently, so you can watch it while you talk.
    _engine.muted = true;
    _engine.play();
    setState(() => _recordPath = path);
  }

  Future<void> _stopVoiceover() async {
    final started = _recordStartMs;
    final elapsed = _recordClock.elapsedMilliseconds;
    _recorderTicker?.cancel();
    _recordClock.stop();
    _engine
      ..pause()
      ..muted = false;
    final path = await _recorder.stop();
    setState(() => _recordPath = null);
    if (path == null) {
      _snack('The recording could not be saved');
      return;
    }
    final probe = await ExportEngine.probe(path);
    final length = probe.durationMs ?? elapsed;
    _c.addAudio(AudioTrack(path: path, name: 'Voiceover', sourceMs: length, startMs: started, volume: 1));
    _engine.seek(started);
  }

  /// Runs a processing job behind a progress dialog that can be cancelled.
  Future<void> _runTool(String title, Future<ClipToolResult> Function(ValueChanged<double> onProgress) job, void Function(ClipToolResult) apply) async {
    _engine.pause();
    final progress = ValueNotifier<double>(0);
    var cancelled = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, v, _) => LinearProgressIndicator(value: v == 0 ? null : v),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                ExportEngine.cancel();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    await WakelockPlus.enable();
    ClipToolResult? result;
    Object? failure;
    try {
      result = await job((v) => progress.value = v);
    } catch (e) {
      failure = e;
    } finally {
      await WakelockPlus.disable();
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    if (cancelled) return;
    if (result == null) {
      debugPrint('$title failed: $failure');
      _snack('$title did not finish. Please try again.');
      return;
    }
    apply(result);
  }

  void _reverse(VideoClip clip) {
    if (clip.outMs - clip.inMs > ClipTools.maxReverseMs) {
      _snack('Trim the clip to 1 minute or less to reverse it');
      return;
    }
    _runTool('Reversing clip', (p) => ClipTools.reverse(clip, p), (r) {
      _c.replaceSource(clip, path: r.path, sourceMs: r.durationMs, hasAudio: clip.hasAudio);
    });
  }

  void _denoise(VideoClip clip) {
    if (!clip.hasAudio) {
      _snack('This clip has no sound to clean up');
      return;
    }
    _runTool('Reducing background noise', (p) => ClipTools.denoise(clip, p), (r) {
      _c.replaceSource(clip, path: r.path, sourceMs: clip.sourceMs, hasAudio: true, resetTrim: false);
    });
  }

  void _detachAudio(VideoClip clip) {
    if (!clip.hasAudio || clip.volume == 0) {
      _snack('This clip has no sound to detach');
      return;
    }
    final start = _c.project.startOf(_c.project.clips.indexOf(clip));
    _runTool('Detaching audio', (p) => ClipTools.extractAudio(clip, p), (r) {
      _c.detachAudio(
        clip,
        AudioTrack(path: r.path, name: 'Clip audio', sourceMs: r.durationMs, startMs: start, volume: clip.volume.clamp(0.0, 1.0).toDouble()),
      );
    });
  }

  Future<void> _addText() async {
    final text = await showTextDialog(context, 'Your text');
    if (text == null || text.trim().isEmpty) return;
    _c.addOverlay(CanvasLayer.text(text)..shadow = true, _engine.positionMs);
    setState(() => _panel = _Panel.textStyle);
  }

  /// Adds an overlay at the playhead and repaints once its fonts arrive.
  void _addStyledOverlay(CanvasLayer layer) {
    _c.addOverlay(layer, _engine.positionMs);
    SceneRenderer.prepare([layer])
        .then((_) {
          if (mounted) _c.touch();
        })
        .catchError((Object _) {});
  }

  void _openWords() {
    showLibrarySheet<void>(
      context,
      (sheet) => WordBrowser(
        onPick: (word) {
          Navigator.pop(sheet);
          _addStyledOverlay(word.toLayer());
        },
      ),
    );
  }

  void _openLooks(CanvasLayer layer) {
    showLibrarySheet<void>(
      context,
      (sheet) => WordBrowser(
        restyleText: layer.text,
        onPick: (word) {
          Navigator.pop(sheet);
          word.style.applyTo(layer);
          _c.commit();
          SceneRenderer.prepare([layer])
              .then((_) {
                if (mounted) _c.touch();
              })
              .catchError((Object _) {});
        },
      ),
    );
  }

  void _openStickers() {
    showLibrarySheet<void>(
      context,
      (sheet) => StickerBrowser(
        onPick: (sticker) {
          Navigator.pop(sheet);
          _c.addOverlay(sticker.toLayer(), _engine.positionMs);
        },
      ),
    );
  }

  /// Effects for [clip], or with no clip, for the part of the video at the
  /// playhead. Timed choices cover that long from the playhead, cutting the
  /// video there automatically.
  void _openEffects([VideoClip? clip]) {
    if (_c.project.clips.isEmpty) {
      _snack('Add a video or photo first');
      return;
    }
    _engine.pause();
    final at = _engine.positionMs;
    showLibrarySheet<void>(
      context,
      (sheet) => EffectBrowser(
        current: EffectLibrary.instance.byId(clip?.effect),
        reaches: clip == null
            ? EffectReach.values.where((r) => r != EffectReach.clip).toList()
            : [
                EffectReach.clip,
                EffectReach.everyClip,
                for (final r in EffectReach.values)
                  if (r.ms != null) r,
              ],
        initialReach: clip == null ? EffectReach.seconds3 : EffectReach.clip,
        onPick: (effect, reach) {
          Navigator.pop(sheet);
          final id = effect?.id;
          switch (reach) {
            case EffectReach.everyClip:
              for (final c in _c.project.clips) {
                c.effect = id;
              }
              _c.commit();
              _snack(id == null ? 'Effects removed from the whole video' : 'Added to the whole video');
            case EffectReach.clip:
              clip!.effect = id;
              _c.commit();
            default:
              final changed = _c.applyEffectRange(id, at, at + reach.ms!);
              if (changed.isEmpty) _snack('Move the playhead inside the video first');
          }
        },
      ),
    );
  }

  /// Moves the playhead, for tests.
  @visibleForTesting
  void debugSeek(int ms) => _engine.seek(ms);

  /// Transitions at the playhead: on the cut there, or on a new cut made there.
  void _openTransitionAtPlayhead() {
    if (_c.project.clips.isEmpty) {
      _snack('Add a video or photo first');
      return;
    }
    _engine.pause();
    final at = _engine.positionMs;
    final near = _c.cutNear(at);
    showLibrarySheet<void>(
      context,
      (sheet) => TransitionBrowser(
        current: near == null ? null : TransitionLibrary.instance.forClip(_c.project.clips[near]),
        cutCount: _c.project.clips.length - 1,
        onPick: (preset, everyCut) {
          Navigator.pop(sheet);
          if (everyCut) {
            final clips = _c.project.clips;
            for (final c in clips.sublist(0, clips.length - 1)) {
              TransitionLibrary.apply(c, preset);
            }
            _c.commit();
            return;
          }
          if (!_c.addTransitionAt(at, (before) => TransitionLibrary.apply(before, preset))) {
            _snack('Move the playhead away from the very start or end');
          }
        },
      ),
    );
  }

  void _openTransitions(VideoClip clip) {
    showLibrarySheet<void>(
      context,
      (sheet) => TransitionBrowser(
        current: TransitionLibrary.instance.forClip(clip),
        cutCount: _c.project.clips.length - 1,
        onPick: (preset, everyCut) {
          Navigator.pop(sheet);
          final clips = _c.project.clips;
          for (final c in everyCut ? clips.sublist(0, clips.length - 1) : [clip]) {
            TransitionLibrary.apply(c, preset);
          }
          _c.commit();
          if (everyCut) _snack(preset == null ? 'Transitions removed from every cut' : 'Added to all ${clips.length - 1} cuts');
        },
      ),
    );
  }

  Future<void> _editText(CanvasLayer layer) async {
    final text = await showTextDialog(context, layer.text);
    if (text == null || text.trim().isEmpty) return;
    layer.text = text;
    _c.commit();
  }

  void _split() {
    if (!_c.splitAt(_engine.positionMs)) _snack('Move the playhead inside a clip to split it');
  }

  void _togglePanel(_Panel panel) => setState(() => _panel = _panel == panel ? null : panel);

  void _export() {
    _engine.pause();
    if (_c.project.clips.isEmpty) {
      _snack('Add a clip first');
      return;
    }
    final before = _c.project.name;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: VideoExportSheet(project: _c.project),
      ),
    ).then((_) {
      // The sheet may have renamed the video; keep that in the project.
      if (mounted && _c.project.name != before) _c.commit();
    });
  }

  String _time(int ms) {
    final s = ms ~/ 1000;
    final tenth = (ms % 1000) ~/ 100;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}.$tenth';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final project = _c.project;
        return Scaffold(
          backgroundColor: AppColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.backdrop),
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  if (useWideEditor(box.biggest)) {
                    // Landscape and big screens: tools beside the picture.
                    final side = (box.maxWidth * .32).clamp(280.0, 420.0);
                    return Column(
                      children: [
                        _topBar(project),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _preview(project)),
                              SizedBox(
                                width: side,
                                child: EditorSidePanel(
                                  header: _transport(project),
                                  panel: _panel == null ? null : _panelView(_panel!),
                                  panelTitle: _panel == null ? null : '${_panel!.name[0].toUpperCase()}${_panel!.name.substring(1)}',
                                  onClosePanel: () => setState(() => _panel = null),
                                  tools: _rail(vertical: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _timeline(project, project.clips.isEmpty ? 80 : (box.maxHeight * .3).clamp(124.0, 240.0)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _topBar(project),
                      Expanded(child: _preview(project)),
                      _transport(project),
                      _timeline(project, 184),
                      if (_panel != null) _panelView(_panel!),
                      _rail(),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glassIcon(IconData icon, String tooltip, VoidCallback? onTap) => Material(
    color: Colors.white.withValues(alpha: .07),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: onTap == null ? AppColors.line : Colors.white),
    ),
  );

  Widget _topBar(VideoProject project) => EditorTopBar(
    kind: 'Video',
    detail: project.clips.isEmpty ? null : '${_formatLabel(project)}  ·  ${_time(project.durationMs)}',
    name: project.name,
    onRename: _rename,
    canUndo: _c.canUndo,
    canRedo: _c.canRedo,
    onUndo: _c.undo,
    onRedo: _c.redo,
    onExport: _export,
  );

  Future<void> _rename() async {
    final name = await showNameDialog(context, title: 'Name your video', initial: _c.project.name, hint: 'Video name');
    if (name == null) return;
    _c.project.name = name;
    _c.commit();
  }

  String _formatLabel(VideoProject p) {
    final r = p.width / p.height;
    if ((r - 9 / 16).abs() < .01) return '9:16';
    if ((r - 1).abs() < .01) return '1:1';
    if ((r - 4 / 5).abs() < .01) return '4:5';
    if ((r - 16 / 9).abs() < .01) return '16:9';
    return '21:9';
  }

  Widget _formatPill(VideoProject project) => GestureDetector(
    onTap: () => _togglePanel(_Panel.format),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.aspect_ratio_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(_formatLabel(project), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );

  Widget _preview(VideoProject project) {
    if (project.clips.isEmpty) return _emptyStage(project);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: project.aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: .35), blurRadius: 40, spreadRadius: -6)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ListenableBuilder(
                listenable: _engine,
                builder: (context, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPreview(engine: _engine),
                    CanvasView(
                      aspectRatio: project.aspectRatio,
                      layers: project.overlays,
                      selectedId: _c.selectedOverlayId,
                      timeMs: _engine.positionMs,
                      onSelect: (id) {
                        _c.selectOverlay(id);
                        setState(() {
                          if (id == null) {
                            if (_panel == _Panel.textStyle) _panel = null;
                          } else if (_c.selectedOverlay?.kind == LayerKind.text) {
                            _panel = _Panel.textStyle;
                          }
                        });
                      },
                      onChanged: _c.touch,
                      onCommit: _c.commit,
                      onEditText: _editText,
                    ),
                    Positioned(top: 10, right: 10, child: _formatPill(project)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Before any clips: a welcoming stage instead of an empty black box.
  Widget _emptyStage(VideoProject project) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArtImage(artScenes[2], thumb: false),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x330B0A12), Color(0xCC0B0A12), Color(0xF20B0A12)],
                  stops: [0, .55, 1],
                ),
              ),
            ),
            Positioned(top: 14, right: 14, child: _formatPill(project)),
            Padding(
              padding: const EdgeInsets.all(24),
              // Short screens scale the welcome down rather than clipping it.
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.bottomCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(width: box.maxWidth, child: _welcome()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: .5), blurRadius: 28)],
          ),
          child: const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        const Text('Start your story', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.6)),
        const SizedBox(height: 6),
        const Text(
          'Add clips and photos, then trim, add music, text, filters and transitions.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, height: 1.35),
        ),
        const SizedBox(height: 20),
        GradientButton(key: const ValueKey('add-first-media'), label: 'Add videos or photos', icon: Icons.add_rounded, onPressed: _addMedia),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _record,
          icon: const Icon(Icons.fiber_manual_record_rounded, color: AppColors.coral, size: 16),
          label: const Text(
            'Record with camera',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _transport(VideoProject project) {
    return ListenableBuilder(
      listenable: _engine,
      builder: (context, _) {
        final empty = project.clips.isEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(12)),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _time(_engine.positionMs),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            TextSpan(
                              text: '  /  ${_time(project.durationMs)}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: _engine.playing ? 'Pause' : 'Play',
                  child: GestureDetector(
                    onTap: empty ? null : _engine.togglePlay,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: empty ? null : AppGradients.brand,
                        color: empty ? AppColors.surfaceHigh : null,
                        shape: BoxShape.circle,
                        boxShadow: empty
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.pink.withValues(alpha: _engine.playing ? .7 : .45),
                                  blurRadius: _engine.playing ? 26 : 16,
                                ),
                              ],
                      ),
                      child: Icon(_engine.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30, color: empty ? AppColors.line : Colors.white),
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_importing)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pink)),
                        ),
                      _glassIcon(Icons.content_cut_rounded, 'Split at playhead', empty ? null : _split),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyTimeline() {
    return InkWell(
      onTap: _addMedia,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: CustomPaint(
          painter: _DashedBorder(),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_timeline_rounded, color: AppColors.muted),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Clips you add will line up here',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rail({bool vertical = false}) {
    final clip = _c.selectedClip;
    final overlay = _c.selectedOverlay;
    final audio = _c.selectedAudio;
    final List<Widget> tools;
    if (clip != null) {
      final isVideo = clip.kind == ClipKind.video;
      tools = [
        ToolButton(icon: Icons.content_cut, label: 'Split', onTap: _split),
        ToolButton(icon: Icons.swap_horiz, label: 'Transition', active: _panel == _Panel.transition, onTap: () => _togglePanel(_Panel.transition)),
        ToolButton(icon: Icons.auto_fix_high, label: 'Effects', active: clip.effect != null, onTap: () => _openEffects(clip)),
        if (isVideo) ToolButton(icon: Icons.speed, label: 'Speed', active: _panel == _Panel.speed, onTap: () => _togglePanel(_Panel.speed)),
        if (isVideo) ToolButton(icon: Icons.volume_up_outlined, label: 'Volume', active: _panel == _Panel.volume, onTap: () => _togglePanel(_Panel.volume)),
        if (isVideo)
          ToolButton(
            icon: clip.volume == 0 ? Icons.volume_off_rounded : Icons.music_off_outlined,
            label: clip.volume == 0 ? 'Sound on' : 'Mute sound',
            active: clip.volume == 0,
            onTap: () {
              clip.volume = clip.volume == 0 ? 1 : 0;
              _c.commit();
            },
          ),
        ToolButton(icon: Icons.auto_awesome, label: 'Filters', active: _panel == _Panel.filters, onTap: () => _togglePanel(_Panel.filters)),
        ToolButton(icon: Icons.tune, label: 'Adjust', active: _panel == _Panel.adjust, onTap: () => _togglePanel(_Panel.adjust)),
        ToolButton(icon: Icons.palette_outlined, label: 'Color', active: _panel == _Panel.color, onTap: () => _togglePanel(_Panel.color)),
        ToolButton(
          icon: clip.fit == ClipFit.fit ? Icons.fit_screen : Icons.crop_free,
          label: clip.fit == ClipFit.fit ? 'Fit' : 'Fill',
          onTap: () {
            clip.fit = clip.fit == ClipFit.fit ? ClipFit.fill : ClipFit.fit;
            _c.commit();
          },
        ),
        ToolButton(
          icon: Icons.flip,
          label: 'Flip',
          active: clip.flipH,
          onTap: () {
            clip.flipH = !clip.flipH;
            _c.commit();
          },
        ),
        if (isVideo) ToolButton(icon: Icons.fast_rewind_outlined, label: 'Reverse', onTap: () => _reverse(clip)),
        if (isVideo) ToolButton(icon: Icons.graphic_eq, label: 'Denoise', onTap: () => _denoise(clip)),
        if (isVideo) ToolButton(icon: Icons.call_split, label: 'Detach audio', onTap: () => _detachAudio(clip)),
        ToolButton(icon: Icons.arrow_back, label: 'Move left', onTap: () => _c.moveClip(clip, -1)),
        ToolButton(icon: Icons.arrow_forward, label: 'Move right', onTap: () => _c.moveClip(clip, 1)),
        ToolButton(icon: Icons.copy, label: 'Duplicate', onTap: () => _c.duplicateClip(clip)),
        ToolButton(icon: Icons.delete_outline, label: 'Delete', onTap: () => _c.deleteClip(clip)),
      ];
    } else if (overlay != null) {
      tools = [
        if (overlay.kind == LayerKind.text) ToolButton(icon: Icons.edit, label: 'Edit', onTap: () => _editText(overlay)),
        if (overlay.kind == LayerKind.text) ToolButton(icon: Icons.auto_awesome, label: 'Looks', onTap: () => _openLooks(overlay)),
        if (overlay.kind == LayerKind.text)
          ToolButton(icon: Icons.format_color_text, label: 'Style', active: _panel == _Panel.textStyle, onTap: () => _togglePanel(_Panel.textStyle)),
        ToolButton(icon: Icons.delete_outline, label: 'Delete', onTap: () => _c.deleteOverlay(overlay)),
      ];
    } else if (audio != null) {
      tools = [
        ToolButton(
          icon: Icons.content_cut,
          label: 'Cut',
          onTap: () {
            if (!_c.splitAudioAt(audio, _engine.positionMs)) _snack('Move the playhead over this sound to cut it');
          },
        ),
        ToolButton(icon: Icons.tune, label: 'Volume & fade', active: _panel == _Panel.audio, onTap: () => _togglePanel(_Panel.audio)),
        ToolButton(
          icon: audio.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          label: audio.volume == 0 ? 'Unmute' : 'Mute',
          active: audio.volume == 0,
          onTap: () {
            audio.volume = audio.volume == 0 ? .8 : 0;
            _c.commit();
          },
        ),
        ToolButton(icon: Icons.copy, label: 'Duplicate', onTap: () => _c.duplicateAudio(audio)),
        ToolButton(icon: Icons.delete_outline, label: 'Delete', onTap: () => _c.deleteAudio(audio)),
      ];
    } else {
      tools = [
        ToolButton(icon: Icons.video_library_outlined, label: 'Add media', onTap: _addMedia),
        ToolButton(icon: Icons.swap_horiz, label: 'Transition', onTap: _openTransitionAtPlayhead),
        ToolButton(icon: Icons.auto_fix_high, label: 'Effects', onTap: _openEffects),
        ToolButton(icon: Icons.title, label: 'Text', onTap: _addText),
        ToolButton(icon: Icons.auto_awesome, label: 'Words', onTap: _openWords),
        ToolButton(icon: Icons.emoji_emotions_outlined, label: 'Stickers', onTap: _openStickers),
        ToolButton(icon: Icons.music_note_outlined, label: 'Music', onTap: _addMusic),
        ToolButton(icon: Icons.add_photo_alternate_outlined, label: 'Image', onTap: _addOverlayImage),
        ToolButton(icon: Icons.videocam_outlined, label: 'Record', onTap: _record),
        ToolButton(icon: Icons.content_cut, label: 'Split', onTap: _c.project.clips.isEmpty ? null : _split),
        ToolButton(
          icon: Icons.mic_none,
          label: 'Voiceover',
          active: _panel == _Panel.voiceover,
          onTap: _c.project.clips.isEmpty ? null : () => _togglePanel(_Panel.voiceover),
        ),
        ToolButton(icon: Icons.aspect_ratio, label: 'Format', active: _panel == _Panel.format, onTap: () => _togglePanel(_Panel.format)),
      ];
    }
    if (clip != null || overlay != null || audio != null) {
      // Always a way back to the main tools: add media, music, text and more.
      tools.insert(0, ToolButton(key: const ValueKey('all-tools'), icon: Icons.apps_rounded, label: 'All tools', onTap: _deselect));
    }
    return ToolDock(tools: tools, vertical: vertical);
  }

  void _deselect() {
    _c.selectClip(null);
    setState(() => _panel = null);
  }

  Widget _timeline(VideoProject project, double height) => Container(
    height: height,
    margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line.withValues(alpha: .6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: project.clips.isEmpty
        ? _emptyTimeline()
        : TimelineView(
            controller: _c,
            engine: _engine,
            onAddMedia: _addMedia,
            onBlankTap: _deselect,
            onCutTap: (i) {
              setState(() => _panel = _Panel.transition);
              _openTransitions(_c.project.clips[i]);
            },
          ),
  );

  Widget _panelView(_Panel panel) {
    final clip = _c.selectedClip;
    switch (panel) {
      case _Panel.filters:
        if (clip == null) return const _SelectHint('Tap a clip on the timeline first.');
        return FilterStrip(grade: clip.grade, thumbnail: _clipThumb(clip), onChanged: _c.touch, onCommit: _c.commit);
      case _Panel.adjust:
        if (clip == null) return const _SelectHint('Tap a clip on the timeline first.');
        return AdjustPanel(grade: clip.grade, onChanged: _c.touch, onCommit: _c.commit, height: 160);
      case _Panel.color:
        if (clip == null) return const _SelectHint('Tap a clip on the timeline first.');
        return ColorWheelsPanel(key: ValueKey('wheels-${clip.id}'), grade: clip.grade, onChanged: _c.touch, onCommit: _c.commit);
      case _Panel.speed:
        if (clip == null) return const _SelectHint('Tap a clip on the timeline first.');
        return _sliderRow('Speed', clip.speed, .25, 4, '${clip.speed.toStringAsFixed(2)}x', (v) {
          clip.speed = (v * 20).round() / 20;
          _c.touch();
        });
      case _Panel.volume:
        if (clip == null) return const _SelectHint('Tap a clip on the timeline first.');
        return _sliderRow('Volume', clip.volume, 0, 2, '${(clip.volume * 100).round()}%', (v) {
          clip.volume = v;
          _c.touch();
        });
      case _Panel.transition:
        final target = _transitionTarget();
        if (target == null) {
          return const _SelectHint('Move the playhead onto a cut, or tap a ＋ between clips on the timeline.');
        }
        return _transitionPanel(target);
      case _Panel.format:
        return _formatPanel();
      case _Panel.voiceover:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _isRecording ? _stopVoiceover : _startVoiceover,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Stop' : 'Record'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isRecording ? 'Recording ${_time(_recordClock.elapsedMilliseconds)}' : 'Records from the playhead while the video plays silently.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        );
      case _Panel.textStyle:
        final overlay = _c.selectedOverlay;
        if (overlay == null || overlay.kind != LayerKind.text) return const _SelectHint('Select a text layer first.');
        return TextStylePanel(
          layer: overlay,
          onCommit: _c.commit,
          onFontReady: () {
            if (mounted) _c.touch();
          },
          onFontFailed: () => _snack('Could not download that font'),
        );
      case _Panel.audio:
        final a = _c.selectedAudio;
        if (a == null) return const _SelectHint('Tap an audio track first.');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sliderRow('Volume', a.volume, 0, 1, '${(a.volume * 100).round()}%', (v) {
              a.volume = v;
              _c.touch();
            }),
            _sliderRow('Fade in', a.fadeInMs.toDouble(), 0, 5000, '${(a.fadeInMs / 1000).toStringAsFixed(1)}s', (v) {
              a.fadeInMs = v.round();
              _c.touch();
            }),
            _sliderRow('Fade out', a.fadeOutMs.toDouble(), 0, 5000, '${(a.fadeOutMs / 1000).toStringAsFixed(1)}s', (v) {
              a.fadeOutMs = v.round();
              _c.touch();
            }),
          ],
        );
    }
  }

  Widget _clipThumb(VideoClip clip) {
    if (clip.kind == ClipKind.image) {
      final image = ImageBank.instance.peek(clip.path);
      if (image != null) return RawImage(image: image, fit: BoxFit.cover);
    }
    // A frame from the clip itself, or a painted scene before one exists.
    final thumb = clip.thumbnail;
    if (thumb != null && !kIsWeb) {
      return Image.file(File(thumb), fit: BoxFit.cover, errorBuilder: (_, _, _) => ArtImage(artScenes.first));
    }
    return ArtImage(artScenes.first);
  }

  Widget _sliderRow(String label, double value, double min, double max, String readout, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged, onChangeEnd: (_) => _c.commit()),
          ),
          SizedBox(
            width: 48,
            child: Text(
              readout,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  /// The clip whose outgoing cut the Transition tool edits. A cut at the
  /// playhead comes first, which is where a split just happened; otherwise the
  /// cut at the end of the selected clip.
  VideoClip? _transitionTarget() {
    final clips = _c.project.clips;
    final near = _c.cutNear(_engine.positionMs, toleranceMs: 300);
    if (near != null) return clips[near];
    final clip = _c.selectedClip;
    if (clip != null && clip != clips.last) return clip;
    return null;
  }

  Widget _transitionPanel(VideoClip clip) {
    final clips = _c.project.clips;
    final index = clips.indexOf(clip);
    final cutAt = _c.project.startOf(index + 1);
    final preset = TransitionLibrary.instance.forClip(clip);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRANSITION · CUT ${index + 1} AT ${_time(cutAt)}',
                      key: const ValueKey('transition-cut-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: AppColors.pink),
                    ),
                    Text(
                      preset?.name ?? 'None (cut)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (preset != null)
                IconButton(
                  tooltip: 'Remove transition',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    TransitionLibrary.apply(clip, null);
                    _c.commit();
                  },
                ),
              GradientButton(
                key: const ValueKey('browse-transitions'),
                label: 'Browse ${formatLibraryCount(TransitionLibrary.instance.length)}',
                icon: Icons.grid_view_rounded,
                compact: true,
                onPressed: () => _openTransitions(clip),
              ),
            ],
          ),
        ),
        TransitionStrip(
          current: preset,
          onPick: (p) {
            TransitionLibrary.apply(clip, p);
            _c.commit();
          },
        ),
        if (preset != null)
          _sliderRow('Length', clip.transitionMs.toDouble(), 100, 2000, '${(clip.transitionMs / 1000).toStringAsFixed(1)}s', (v) {
            clip.transitionMs = v.round();
            _c.touch();
          }),
      ],
    );
  }

  Widget _formatPanel() {
    const formats = [
      ('9:16 Reel', 1080, 1920),
      ('1:1 Square', 1080, 1080),
      ('4:5 Portrait', 1080, 1350),
      ('16:9 Wide', 1920, 1080),
      ('21:9 Cinema', 2520, 1080),
    ];
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final f in formats)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(f.$1, style: const TextStyle(fontSize: 12)),
                selected: _c.project.width == f.$2 && _c.project.height == f.$3,
                onSelected: (_) => _c.setFormat(f.$2, f.$3),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectHint extends StatelessWidget {
  const _SelectHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(text, style: const TextStyle(color: AppColors.muted)),
  );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final paint = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
