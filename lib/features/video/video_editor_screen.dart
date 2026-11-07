import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../canvas/canvas_view.dart';
import '../../canvas/layer.dart';
import '../../core/media.dart';
import '../shared/grade_panels.dart';
import '../shared/layer_panels.dart';
import 'export_engine.dart';
import 'playback_engine.dart';
import 'timeline_view.dart';
import 'video_controller.dart';
import 'video_export_sheet.dart';
import 'video_preview.dart';
import 'video_project.dart';

enum _Panel { filters, adjust, speed, volume, transition, stickers, format, textStyle, audio }

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key, required this.project});
  final VideoProject project;

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late final VideoController _c = VideoController(widget.project);
  late final PlaybackEngine _engine = PlaybackEngine(() => _c.project);
  final _picker = ImagePicker();
  _Panel? _panel;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _c.onTimelineChanged = _engine.refresh;
    ImageBank.instance.addListener(_engine.refresh);
    _engine.refresh();
    for (final c in _c.project.clips) {
      if (c.kind == ClipKind.image) ImageBank.instance.load(c.path).ignore();
    }
  }

  @override
  void dispose() {
    ImageBank.instance.removeListener(_engine.refresh);
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
    final files = await _picker.pickMultipleMedia();
    await _importFiles(files);
  }

  Future<void> _record() async {
    final file = await _picker.pickVideo(source: ImageSource.camera);
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
    return VideoClip(
      path: path,
      kind: ClipKind.video,
      sourceMs: duration,
      hasAudio: probe.hasAudio,
      thumbnail: await ExportEngine.extractThumbnail(path, 0),
    );
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
    final result = await FilePicker.pickFiles(type: FileType.audio);
    if (result.isEmpty) return;
    final picked = result.first;
    if (picked.path == null) return;
    final path = await MediaLibrary.import(XFile(picked.path!, name: picked.name));
    final probe = await ExportEngine.probe(path);
    final duration = probe.durationMs ?? await _playerDuration(path);
    _c.addAudio(AudioTrack(path: path, name: picked.name, sourceMs: duration, startMs: _engine.positionMs));
    setState(() => _panel = _Panel.audio);
  }

  Future<void> _addText() async {
    final text = await showTextDialog(context, 'Your text');
    if (text == null || text.trim().isEmpty) return;
    _c.addOverlay(CanvasLayer.text(text)..shadow = true, _engine.positionMs);
    setState(() => _panel = _Panel.textStyle);
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
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => VideoExportSheet(project: _c.project),
    );
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
          appBar: AppBar(
            title: Text(project.name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(tooltip: 'Undo', onPressed: _c.canUndo ? _c.undo : null, icon: const Icon(Icons.undo)),
              IconButton(tooltip: 'Redo', onPressed: _c.canRedo ? _c.redo : null, icon: const Icon(Icons.redo)),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(onPressed: _export, child: const Text('Export')),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _preview(project)),
                _transport(project),
                SizedBox(
                  height: 150,
                  child: project.clips.isEmpty
                      ? _emptyTimeline()
                      : TimelineView(controller: _c, engine: _engine),
                ),
                if (_panel != null) _panelView(_panel!),
                _rail(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _preview(VideoProject project) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: AspectRatio(
          aspectRatio: project.aspectRatio,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _transport(VideoProject project) {
    return ListenableBuilder(
      listenable: _engine,
      builder: (context, _) => SizedBox(
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(
              '${_time(_engine.positionMs)} / ${_time(project.durationMs)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const Spacer(),
            IconButton(
              tooltip: _engine.playing ? 'Pause' : 'Play',
              iconSize: 30,
              icon: Icon(_engine.playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
              onPressed: project.clips.isEmpty ? null : _engine.togglePlay,
            ),
            const Spacer(),
            if (_importing) const Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            if (!_importing) const SizedBox(width: 90),
          ],
        ),
      ),
    );
  }

  Widget _emptyTimeline() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            key: const ValueKey('add-first-media'),
            onPressed: _addMedia,
            icon: const Icon(Icons.add),
            label: const Text('Add videos or photos'),
          ),
          const SizedBox(height: 6),
          const Text('Your timeline will appear here', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _rail() {
    final clip = _c.selectedClip;
    final overlay = _c.selectedOverlay;
    final audio = _c.selectedAudio;
    final List<Widget> tools;
    if (clip != null) {
      final isVideo = clip.kind == ClipKind.video;
      tools = [
        ToolButton(icon: Icons.content_cut, label: 'Split', onTap: _split),
        if (isVideo) ToolButton(icon: Icons.speed, label: 'Speed', active: _panel == _Panel.speed, onTap: () => _togglePanel(_Panel.speed)),
        if (isVideo) ToolButton(icon: Icons.volume_up_outlined, label: 'Volume', active: _panel == _Panel.volume, onTap: () => _togglePanel(_Panel.volume)),
        ToolButton(icon: Icons.auto_awesome, label: 'Filters', active: _panel == _Panel.filters, onTap: () => _togglePanel(_Panel.filters)),
        ToolButton(icon: Icons.tune, label: 'Adjust', active: _panel == _Panel.adjust, onTap: () => _togglePanel(_Panel.adjust)),
        ToolButton(icon: Icons.swap_horiz, label: 'Transition', active: _panel == _Panel.transition, onTap: () => _togglePanel(_Panel.transition)),
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
        ToolButton(icon: Icons.arrow_back, label: 'Move left', onTap: () => _c.moveClip(clip, -1)),
        ToolButton(icon: Icons.arrow_forward, label: 'Move right', onTap: () => _c.moveClip(clip, 1)),
        ToolButton(icon: Icons.copy, label: 'Duplicate', onTap: () => _c.duplicateClip(clip)),
        ToolButton(icon: Icons.delete_outline, label: 'Delete', onTap: () => _c.deleteClip(clip)),
      ];
    } else if (overlay != null) {
      tools = [
        if (overlay.kind == LayerKind.text) ToolButton(icon: Icons.edit, label: 'Edit', onTap: () => _editText(overlay)),
        if (overlay.kind == LayerKind.text)
          ToolButton(icon: Icons.format_color_text, label: 'Style', active: _panel == _Panel.textStyle, onTap: () => _togglePanel(_Panel.textStyle)),
        ToolButton(icon: Icons.delete_outline, label: 'Delete', onTap: () => _c.deleteOverlay(overlay)),
      ];
    } else if (audio != null) {
      tools = [
        ToolButton(icon: Icons.tune, label: 'Audio', active: _panel == _Panel.audio, onTap: () => _togglePanel(_Panel.audio)),
        ToolButton(icon: Icons.delete_outline, label: 'Delete', onTap: () => _c.deleteAudio(audio)),
      ];
    } else {
      tools = [
        ToolButton(icon: Icons.video_library_outlined, label: 'Add media', onTap: _addMedia),
        ToolButton(icon: Icons.videocam_outlined, label: 'Record', onTap: _record),
        ToolButton(icon: Icons.content_cut, label: 'Split', onTap: _c.project.clips.isEmpty ? null : _split),
        ToolButton(icon: Icons.title, label: 'Text', onTap: _addText),
        ToolButton(icon: Icons.emoji_emotions_outlined, label: 'Stickers', active: _panel == _Panel.stickers, onTap: () => _togglePanel(_Panel.stickers)),
        ToolButton(icon: Icons.music_note_outlined, label: 'Music', onTap: _addMusic),
        ToolButton(icon: Icons.aspect_ratio, label: 'Format', active: _panel == _Panel.format, onTap: () => _togglePanel(_Panel.format)),
      ];
    }
    return Container(
      height: 66,
      color: AppColors.surface,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6), children: tools),
    );
  }

  Widget _panelView(_Panel panel) {
    final clip = _c.selectedClip;
    switch (panel) {
      case _Panel.filters:
        if (clip == null) return const _SelectHint('Tap a clip on the timeline first.');
        return FilterStrip(grade: clip.grade, thumbnail: _clipThumb(clip), onChanged: _c.touch, onCommit: _c.commit);
      case _Panel.adjust:
        if (clip == null) return const _SelectHint('Tap a clip on the timeline first.');
        return AdjustPanel(grade: clip.grade, onChanged: _c.touch, onCommit: _c.commit, height: 160);
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
        if (clip == null) return const _SelectHint('Tap a clip on the timeline first.');
        return _transitionPanel(clip);
      case _Panel.stickers:
        return StickerGrid(onPick: (s) {
          _c.addOverlay(CanvasLayer.sticker(s), _engine.positionMs);
          setState(() => _panel = null);
        });
      case _Panel.format:
        return _formatPanel();
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFE8A87C), Color(0xFF41B3A3), Color(0xFF2E4057)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
    );
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
          SizedBox(width: 48, child: Text(readout, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
        ],
      ),
    );
  }

  Widget _transitionPanel(VideoClip clip) {
    final isLast = _c.project.clips.last == clip;
    if (isLast) return const _SelectHint('Transitions go between clips. Select an earlier clip.');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final t in TransitionType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t.label, style: const TextStyle(fontSize: 12)),
                    selected: clip.transition == t,
                    onSelected: (_) {
                      clip.transition = t;
                      _c.commit();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (clip.transition != TransitionType.none)
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
