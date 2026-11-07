import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../canvas/layer.dart';
import 'playback_engine.dart';
import 'video_controller.dart';
import 'video_project.dart';

/// Scrolling multi-track timeline with a fixed centre playhead. Scrolling scrubs
/// the video and playback scrolls the tracks.
class TimelineView extends StatefulWidget {
  const TimelineView({super.key, required this.controller, required this.engine});
  final VideoController controller;
  final PlaybackEngine engine;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final _scroll = ScrollController();
  double _pxPerSecond = 60;
  double _zoomStart = 60;
  bool _userScrolling = false;

  static const _clipRow = 56.0;
  static const _thinRow = 26.0;

  VideoProject get _p => widget.controller.project;
  double _x(int ms) => ms / 1000 * _pxPerSecond;
  int _ms(double px) => (px / _pxPerSecond * 1000).round();

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_followPlayback);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.engine.removeListener(_followPlayback);
    _scroll.dispose();
    super.dispose();
  }

  void _followPlayback() {
    if (_userScrolling || !_scroll.hasClients) return;
    final target = _x(widget.engine.positionMs);
    if ((_scroll.offset - target).abs() > .5) _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
  }

  void _onScroll() {
    if (_userScrolling) widget.engine.seek(_ms(_scroll.offset));
  }

  bool _onNotification(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userScrolling = true;
      widget.engine.pause();
    } else if (n is ScrollEndNotification) {
      _userScrolling = false;
    }
    return false;
  }

  String _format(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final half = box.maxWidth / 2;
          final total = _x(_p.durationMs);
          return GestureDetector(
            onScaleStart: (_) => _zoomStart = _pxPerSecond,
            onScaleUpdate: (d) {
              if (d.pointerCount < 2) return;
              setState(() => _pxPerSecond = (_zoomStart * d.scale).clamp(8.0, 400.0));
              _followPlayback();
            },
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onNotification,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: half),
                      child: SizedBox(
                        width: total,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ruler(total),
                              _clipTrack(total),
                              for (final o in _p.overlays) _overlayRow(o, total),
                              for (final a in _p.audio) _audioRow(a, total),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: half - 1,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(child: Container(width: 2, color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ruler(double total) {
    final stepSeconds = _pxPerSecond >= 40 ? 1 : (_pxPerSecond >= 16 ? 5 : 15);
    final marks = (_p.durationMs ~/ 1000) ~/ stepSeconds;
    return SizedBox(
      width: total,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i <= marks; i += _pxPerSecond >= 40 && _pxPerSecond < 90 ? 2 : 1)
            Positioned(
              left: _x(i * stepSeconds * 1000),
              top: 3,
              child: Text(_format(i * stepSeconds * 1000), style: const TextStyle(fontSize: 9, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }

  Widget _clipTrack(double total) {
    final clips = _p.clips;
    return SizedBox(
      width: total,
      height: _clipRow,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < clips.length; i++) _clipBlock(clips[i], i),
          for (var i = 0; i < clips.length - 1; i++) _transitionMarker(i),
        ],
      ),
    );
  }

  Widget _clipBlock(VideoClip clip, int i) {
    final c = widget.controller;
    final selected = c.selectedClipId == clip.id;
    final width = _x(clip.durationMs);
    return Positioned(
      left: _x(_p.startOf(i)),
      top: 0,
      bottom: 0,
      width: width,
      child: GestureDetector(
        key: ValueKey('clip-${clip.id}'),
        onTap: () => c.selectClip(selected ? null : clip.id),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selected ? AppColors.coral : AppColors.line, width: selected ? 2 : 1),
              ),
              child: _thumbnail(clip),
            ),
            if (selected) ...[
              _trimHandle(left: true, onDrag: (dx) => c.trimStart(clip, _ms(dx)), onEnd: c.commit),
              _trimHandle(left: false, onDrag: (dx) => c.trimEnd(clip, _ms(dx)), onEnd: c.commit),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(VideoClip clip) {
    final path = clip.kind == ClipKind.image ? clip.path : clip.thumbnail;
    if (kIsWeb || path == null) {
      return Center(
        child: Icon(clip.kind == ClipKind.image ? Icons.image_outlined : Icons.movie_outlined, color: AppColors.muted, size: 18),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.none,
      repeat: ImageRepeat.repeatX,
      cacheHeight: 56,
      alignment: Alignment.centerLeft,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  Widget _trimHandle({required bool left, required ValueChanged<double> onDrag, required VoidCallback onEnd}) {
    return Positioned(
      left: left ? -10 : null,
      right: left ? null : -10,
      top: 0,
      bottom: 0,
      width: 20,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        child: Center(
          child: Container(
            width: 8,
            height: _clipRow - 14,
            decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(3)),
          ),
        ),
      ),
    );
  }

  Widget _transitionMarker(int i) {
    final clip = _p.clips[i];
    final has = clip.transition != TransitionType.none;
    return Positioned(
      left: _x(_p.startOf(i + 1)) - 12,
      top: _clipRow / 2 - 12,
      child: GestureDetector(
        onTap: () => widget.controller.selectClip(clip.id),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: has ? AppColors.violet : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
          ),
          child: Icon(has ? Icons.swap_horiz : Icons.add, size: 14),
        ),
      ),
    );
  }

  Widget _overlayRow(CanvasLayer o, double total) {
    final c = widget.controller;
    final selected = c.selectedOverlayId == o.id;
    final start = o.startMs ?? 0;
    final end = o.endMs ?? _p.durationMs;
    final label = o.isTextual && o.text.isNotEmpty ? o.text.replaceAll('\n', ' ') : o.name;
    return _thinTrack(
      total: total,
      left: _x(start),
      width: _x(end - start),
      color: selected ? AppColors.coral : const Color(0xFF8A3B2A),
      label: label,
      icon: Icons.title,
      onTap: () => c.selectOverlay(selected ? null : o.id),
      onMove: (dx) {
        final length = end - start;
        final next = (start + _ms(dx)).clamp(0, _p.durationMs - length > 0 ? _p.durationMs - length : 0);
        o
          ..startMs = next
          ..endMs = next + length;
        c.touch();
      },
      onResize: (dx) {
        o.endMs = (end + _ms(dx)).clamp(start + 200, _p.durationMs);
        c.touch();
      },
      onEnd: c.commit,
    );
  }

  Widget _audioRow(AudioTrack a, double total) {
    final c = widget.controller;
    final selected = c.selectedAudioId == a.id;
    return _thinTrack(
      total: total,
      left: _x(a.startMs),
      width: _x(a.durationMs).clamp(10, double.infinity),
      color: selected ? AppColors.violet : const Color(0xFF473A91),
      label: a.name,
      icon: Icons.music_note,
      onTap: () => c.selectAudio(selected ? null : a.id),
      onMove: (dx) {
        a.startMs = (a.startMs + _ms(dx)).clamp(0, _p.durationMs);
        c.touch();
      },
      onResize: (dx) {
        a.durationMs = (a.durationMs + _ms(dx)).clamp(200, a.sourceMs - a.inMs);
        c.touch();
      },
      onEnd: c.commit,
    );
  }

  Widget _thinTrack({
    required double total,
    required double left,
    required double width,
    required Color color,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required ValueChanged<double> onMove,
    required ValueChanged<double> onResize,
    required VoidCallback onEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: SizedBox(
        width: total,
        height: _thinRow,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              width: width,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: onTap,
                onHorizontalDragUpdate: (d) => onMove(d.delta.dx),
                onHorizontalDragEnd: (_) => onEnd(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                  child: Row(
                    children: [
                      Icon(icon, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: left + width - 8,
              width: 16,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => onResize(d.delta.dx),
                onHorizontalDragEnd: (_) => onEnd(),
                child: const Center(child: VerticalDivider(color: Colors.white70, thickness: 2, width: 2, indent: 6, endIndent: 6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
