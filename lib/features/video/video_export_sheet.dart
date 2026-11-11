import 'dart:io' show File;
import 'dart:ui' as ui;
import '../shared/editor_chrome.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme.dart';
import '../../canvas/renderer.dart';
import '../../core/media.dart';
import '../../core/output.dart';
import 'export_engine.dart';
import 'ffmpeg_graph.dart';
import 'video_project.dart';

/// Scales a project's frame so its short edge matches [shortEdge]. H.264 needs
/// even dimensions, so both sides are rounded to even numbers.
({int width, int height}) exportSize(int width, int height, int shortEdge) {
  final scale = shortEdge / (width < height ? width : height);
  int even(double v) => (v / 2).round() * 2;
  return (width: even(width * scale), height: even(height * scale));
}

/// How many files this project needs that are no longer on the device.
int missingMediaCount(VideoProject p) {
  if (kIsWeb) return 0;
  final paths = {...p.clips.map((c) => c.path), ...p.audio.map((a) => a.path)};
  return paths.where((path) => !File(path).existsSync()).length;
}

class VideoExportSheet extends StatefulWidget {
  const VideoExportSheet({super.key, required this.project});
  final VideoProject project;

  @override
  State<VideoExportSheet> createState() => _VideoExportSheetState();
}

enum _Stage { setup, running, done }

class _VideoExportSheetState extends State<VideoExportSheet> {
  int _shortEdge = 1080;
  int _fps = 30;
  _Stage _stage = _Stage.setup;
  double _progress = 0;
  String? _error;
  String? _status;
  String? _output;
  bool _cancelled = false;
  late final _name = TextEditingController(text: widget.project.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<String> _writePng(ui.Image image, String path) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    return path;
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.running;
      _progress = 0;
      _error = null;
      _cancelled = false;
    });
    await WakelockPlus.enable();
    try {
      final p = widget.project;
      final missing = missingMediaCount(p);
      if (missing > 0) {
        throw StateError('$missing media file${missing == 1 ? ' is' : 's are'} missing from this project. Remove or replace them, then try again.');
      }
      final size = exportSize(p.width, p.height, _shortEdge);
      final dir = await MediaLibrary.workDir('export-${newId()}');
      await SceneRenderer.prepare(p.overlays);

      // Overlays are drawn by the app's renderer, so they match the preview.
      final overlays = <String, String>{};
      for (final layer in p.overlays) {
        if (!layer.visible) continue;
        final image = await SceneRenderer.rasterize(size.width, size.height, (c, s) => SceneRenderer.paintLayer(c, s, layer));
        overlays[layer.id] = await _writePng(image, '${dir.path}/overlay-${layer.id}.png');
      }
      final vignettes = <String, String>{};
      for (final clip in p.clips) {
        final amount = clip.grade.vignette;
        if (amount <= 0) continue;
        final image = await SceneRenderer.rasterize(size.width, size.height, (c, s) => SceneRenderer.paintVignette(c, Offset.zero & s, amount));
        vignettes[clip.id] = await _writePng(image, '${dir.path}/vignette-${clip.id}.png');
      }

      final output = '${dir.path}/${fileSafeName(p.name)}.mp4';
      final args = buildExportArgs(
        project: p,
        settings: ExportSettings(width: size.width, height: size.height, fps: _fps),
        outputPath: output,
        overlayPngs: overlays,
        vignettePngs: vignettes,
      );
      final error = await ExportEngine.run(
        args,
        durationMs: p.durationMs,
        onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        },
      );
      if (!mounted) return;
      if (_cancelled) {
        setState(() => _stage = _Stage.setup);
      } else if (error != null) {
        setState(() {
          _stage = _Stage.setup;
          _error = error;
        });
      } else {
        setState(() {
          _output = output;
          _stage = _Stage.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.setup;
          _error = e is StateError ? e.message : '$e';
        });
      }
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<void> _cancel() async {
    _cancelled = true;
    await ExportEngine.cancel();
  }

  Future<void> _saveToGallery() async {
    try {
      await Output.saveVideo(_output!);
      if (mounted) setState(() => _status = 'Saved to your gallery');
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage != _Stage.running,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: switch (_stage) {
            _Stage.setup => _setup(),
            _Stage.running => _running(),
            _Stage.done => _done(),
          },
        ),
      ),
    );
  }

  Widget _setup() {
    final size = exportSize(widget.project.width, widget.project.height, _shortEdge);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Save your video', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          NameField(
            controller: _name,
            hint: 'Video name',
            onChanged: (v) {
              if (v.trim().isNotEmpty) widget.project.name = v.trim();
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 720, label: Text('720p')),
              ButtonSegment(value: 1080, label: Text('1080p')),
              ButtonSegment(value: 2160, label: Text('4K')),
            ],
            selected: {_shortEdge},
            onSelectionChanged: (s) => setState(() => _shortEdge = s.first),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 24, label: Text('24 fps')),
              ButtonSegment(value: 30, label: Text('30 fps')),
              ButtonSegment(value: 60, label: Text('60 fps')),
            ],
            selected: {_fps},
            onSelectionChanged: (s) => setState(() => _fps = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            '${size.width} × ${size.height}, H.264 MP4',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          if (_shortEdge == 2160)
            const Text(
              '4K takes much longer and needs plenty of free storage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: ExportEngine.isSupported ? _start : null,
            child: Text(ExportEngine.isSupported ? 'Start export' : 'Export needs the mobile app'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (_error != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: SelectableText(_error!, style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _running() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Exporting…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: _progress == 0 ? null : _progress),
        const SizedBox(height: 8),
        Text('${(_progress * 100).round()}%', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Keep the app open until this finishes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
      ],
    );
  }

  Widget _done() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Your video is ready', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: _saveToGallery, icon: const Icon(Icons.download), label: const Text('Save to gallery')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => Output.shareFile(_output!), icon: const Icon(Icons.share), label: const Text('Share')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        if (_status != null) Text(_status!, textAlign: TextAlign.center),
      ],
    );
  }
}
