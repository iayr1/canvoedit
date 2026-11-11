import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../canvas/layer.dart';
import '../../core/media.dart';
import 'playback_engine.dart';
import 'video_controller.dart';
import 'video_project.dart';

/// Scrolling multi-track timeline with a fixed centre playhead. Scrolling scrubs
/// the video and playback scrolls the tracks.
class TimelineView extends StatefulWidget {
  const TimelineView({super.key, required this.controller, required this.engine, this.onCutTap, this.onAddMedia, this.onBlankTap});

  /// Called with the index of the clip before a cut when its marker is tapped.
  final ValueChanged<int>? onCutTap;

  /// Adds more clips, from the button after the last clip.
  final VoidCallback? onAddMedia;

  /// Tapping the timeline away from any item.
  final VoidCallback? onBlankTap;
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
  static const _thinRow = 28.0;

  /// Zoom limits in pixels per second: a few hours across a phone screen at
  /// one end, single frames at the other.
  static const minZoom = .02;
  static const maxZoom = 600.0;
  double _viewWidth = 360;

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final half = box.maxWidth / 2;
          _viewWidth = box.maxWidth;
          final total = _x(_p.durationMs);
          return Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onScaleStart: (_) => _zoomStart = _pxPerSecond,
                  onScaleUpdate: (d) {
                    if (d.pointerCount < 2) return;
                    _setZoom(_zoomStart * d.scale);
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
                              width: total + 64,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _ruler(total, half),
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
                        child: IgnorePointer(
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: .6), blurRadius: 6)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: half - 7,
                        top: 2,
                        child: IgnorePointer(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: AppGradients.brand,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: .7), blurRadius: 10)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _zoomBar(),
            ],
          );
        },
      ),
    );
  }

  void _setZoom(double pxPerSecond) {
    setState(() => _pxPerSecond = pxPerSecond.clamp(minZoom, maxZoom));
    WidgetsBinding.instance.addPostFrameCallback((_) => _followPlayback());
  }

  /// Zoom that fits the whole video between the playhead and the screen edge,
  /// so from the start every clip is in view.
  double get _fitZoom {
    final seconds = _p.durationMs / 1000;
    if (seconds <= 0) return 60;
    return ((_viewWidth / 2 - 16) / seconds).clamp(minZoom, maxZoom);
  }

  // The slider runs on a log scale so every step feels the same size.
  double get _zoomPosition => math.log(_pxPerSecond / minZoom) / math.log(maxZoom / minZoom);
  double _zoomFromPosition(double v) => minZoom * math.pow(maxZoom / minZoom, v);

  Widget _zoomBar() {
    Widget button(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 30),
      icon: Icon(icon, size: 18, color: Colors.white),
      onPressed: onTap,
    );
    final step = labelStepMs(_pxPerSecond);
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          button(Icons.zoom_out_rounded, 'Zoom out', () => _setZoom(_pxPerSecond / 1.6)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(key: const ValueKey('timeline-zoom'), value: _zoomPosition.clamp(0.0, 1.0), onChanged: (v) => _setZoom(_zoomFromPosition(v))),
            ),
          ),
          button(Icons.zoom_in_rounded, 'Zoom in', () => _setZoom(_pxPerSecond * 1.6)),
          SizedBox(
            width: 40,
            child: Text(
              stepLabel(step),
              key: const ValueKey('timeline-step'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              key: const ValueKey('timeline-fit'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: .08),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.fit_screen_rounded, size: 15),
              label: const Text('Fit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              onPressed: () => _setZoom(_fitZoom),
            ),
          ),
        ],
      ),
    );
  }

  /// Short name for a ruler step, shown beside the zoom slider.
  static String stepLabel(int ms) {
    if (ms < 1000) return '${(ms / 1000).toStringAsFixed(ms % 100 == 0 ? 1 : 2)}s';
    if (ms < 60000) return '${ms ~/ 1000}s';
    if (ms < 3600000) return '${ms ~/ 60000}m';
    return '${ms ~/ 3600000}h';
  }

  /// Time between labelled ruler marks, chosen so labels never crowd.
  static int labelStepMs(double pxPerSecond) {
    const steps = [100, 250, 500, 1000, 2000, 5000, 10000, 15000, 30000, 60000, 120000, 300000, 600000, 900000, 1800000, 3600000];
    for (final s in steps) {
      if (s / 1000 * pxPerSecond >= 56) return s;
    }
    return steps.last;
  }

  Widget _ruler(double total, double half) {
    return SizedBox(
      width: total,
      height: 22,
      child: CustomPaint(
        painter: _RulerPainter(pxPerSecond: _pxPerSecond, durationMs: _p.durationMs, scroll: _scroll, half: half, labelStepMs: labelStepMs(_pxPerSecond)),
      ),
    );
  }

  Widget _clipTrack(double total) {
    final clips = _p.clips;
    return SizedBox(
      width: total + 64,
      height: _clipRow,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: widget.onBlankTap),
          ),
          for (var i = 0; i < clips.length; i++) _clipBlock(clips[i], i),
          for (var i = 0; i < clips.length - 1; i++) _transitionMarker(i),
          if (widget.onAddMedia != null)
            Positioned(
              left: total + 12,
              top: 6,
              bottom: 6,
              width: 44,
              child: Material(
                key: const ValueKey('timeline-add'),
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.onAddMedia,
                  child: const Tooltip(
                    message: 'Add videos or photos',
                    child: Icon(Icons.add_rounded, color: AppColors.ink),
                  ),
                ),
              ),
            ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: selected ? AppGradients.brand : null,
                  color: selected ? null : AppColors.line,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected ? [BoxShadow(color: AppColors.pink.withValues(alpha: .45), blurRadius: 12)] : null,
                ),
                child: Padding(
                  padding: EdgeInsets.all(selected ? 2 : 1),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(selected ? 9 : 10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const DecoratedBox(
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2B2140), Color(0xFF1C1828)])),
                        ),
                        _thumbnail(clip),
                        if (width > 46)
                          Positioned(
                            left: 5,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                '${(clip.durationMs / 1000).toStringAsFixed(1)}s',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                        if (clip.effect != null && width > 22)
                          Positioned(
                            left: 4,
                            top: 4,
                            child: Container(
                              key: ValueKey('effect-badge-${clip.id}'),
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(gradient: AppGradients.brand, shape: BoxShape.circle),
                              child: const Icon(Icons.auto_fix_high, size: 10, color: Colors.white),
                            ),
                          ),
                        if (clip.speed != 1 && width > 80)
                          Positioned(
                            right: 5,
                            top: 4,
                            child: Text(
                              '${clip.speed}x',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.gold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
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
      return Center(child: Icon(clip.kind == ClipKind.image ? Icons.image_outlined : Icons.movie_outlined, color: AppColors.muted, size: 18));
    }
    // One repeating shader, however long the clip, rather than a tile per frame.
    final image = ImageBank.instance.peek(path);
    if (image == null) {
      ImageBank.instance.load(path).then((_) {
        if (mounted) setState(() {});
      }).ignore();
      return const SizedBox.shrink();
    }
    return CustomPaint(painter: _FilmstripPainter(image));
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
            width: 10,
            height: _clipRow - 10,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
            ),
            child: Center(child: Container(width: 2, height: 14, color: AppColors.pink)),
          ),
        ),
      ),
    );
  }

  Widget _transitionMarker(int i) {
    final clip = _p.clips[i];
    final has = clip.transition != TransitionType.none;
    return Positioned(
      left: _x(_p.startOf(i + 1)) - 13,
      top: _clipRow / 2 - 13,
      child: GestureDetector(
        key: ValueKey('cut-$i'),
        onTap: () {
          widget.controller.selectClip(clip.id);
          widget.onCutTap?.call(i);
        },
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: has ? AppGradients.ocean : null,
            color: has ? null : Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
          ),
          child: Icon(has ? Icons.auto_awesome_rounded : Icons.add_rounded, size: 14, color: has ? Colors.white : AppColors.ink),
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
      gradient: selected ? AppGradients.sunrise : const LinearGradient(colors: [Color(0xFF7A2E4A), Color(0xFF6B2A3A)]),
      label: label,
      icon: o.isTextual ? Icons.title_rounded : Icons.layers_rounded,
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
      gradient: selected ? AppGradients.ocean : const LinearGradient(colors: [Color(0xFF2E3A7A), Color(0xFF3B2A72)]),
      label: a.name,
      icon: a.name == 'Voiceover' ? Icons.mic_rounded : Icons.music_note_rounded,
      waveSeed: a.id.hashCode,
      onTap: () => c.selectAudio(selected ? null : a.id),
      onMove: (dx) {
        a.startMs = (a.startMs + _ms(dx)).clamp(0, _p.durationMs);
        c.touch();
      },
      onResize: (dx) {
        a.durationMs = (a.durationMs + _ms(dx)).clamp(200, a.sourceMs - a.inMs);
        c.touch();
      },
      onResizeStart: (dx) => c.trimAudioStart(a, _ms(dx)),
      onEnd: c.commit,
    );
  }

  Widget _thinTrack({
    required double total,
    required double left,
    required double width,
    required Gradient gradient,
    required String label,
    required IconData icon,
    int? waveSeed,
    required VoidCallback onTap,
    required ValueChanged<double> onMove,
    required ValueChanged<double> onResize,
    ValueChanged<double>? onResizeStart,
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
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(8)),
                  child: Stack(
                    children: [
                      if (waveSeed != null) Positioned.fill(child: CustomPaint(painter: _WavePainter(waveSeed))),
                      Row(
                        children: [
                          Icon(icon, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onResizeStart != null)
              Positioned(
                left: left - 8,
                width: 16,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => onResizeStart(d.delta.dx),
                  onHorizontalDragEnd: (_) => onEnd(),
                  child: const Center(child: VerticalDivider(color: Colors.white70, thickness: 2, width: 2, indent: 6, endIndent: 6)),
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

/// A decorative waveform for audio bars.
class _WavePainter extends CustomPainter {
  _WavePainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // Long tracks space their bars out so painting stays cheap.
    final gap = math.max(4.0, size.width / 1500);
    for (var x = 2.0; x < size.width; x += gap) {
      final h = size.height * (.15 + r.nextDouble() * .6);
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.seed != seed;
}

/// Time marks along the top, painted only where the view can see.
class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.pxPerSecond, required this.durationMs, required this.scroll, required this.half, required this.labelStepMs})
    : super(repaint: scroll);

  final double pxPerSecond;
  final int durationMs;
  final ScrollController scroll;
  final double half;
  final int labelStepMs;

  String _label(int ms) {
    final s = ms ~/ 1000;
    final mm = ((s ~/ 60) % 60).toString().padLeft(2, '0'), ss = (s % 60).toString().padLeft(2, '0');
    final head = durationMs >= 3600000 ? '${s ~/ 3600}:$mm' : mm;
    final tail = labelStepMs < 1000 ? '.${(ms % 1000) ~/ 100}' : '';
    return '$head:$ss$tail';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    final from = math.max(0.0, offset - half - 80), to = math.min(size.width, offset + half + 80);
    final minor = labelStepMs ~/ (labelStepMs / 5 / 1000 * pxPerSecond >= 10 ? 5 : 2);
    final tick = Paint()
      ..color = AppColors.muted.withValues(alpha: .6)
      ..strokeWidth = 1;
    final first = (from / pxPerSecond * 1000 / minor).floor() * minor;
    for (var ms = first; ms <= durationMs; ms += minor) {
      final x = ms / 1000 * pxPerSecond;
      if (x > to) break;
      final major = ms % labelStepMs == 0;
      canvas.drawLine(Offset(x, major ? 2 : 6), Offset(x, 10), tick);
      if (major) {
        final tp = TextPainter(
          text: TextSpan(
            text: _label(ms),
            style: const TextStyle(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 4, 1));
        tp.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.pxPerSecond != pxPerSecond || old.durationMs != durationMs || old.half != half || old.labelStepMs != labelStepMs;
}

/// A clip's thumbnail repeated along its length.
class _FilmstripPainter extends CustomPainter {
  _FilmstripPainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / image.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.low
        ..shader = ImageShader(image, TileMode.repeated, TileMode.clamp, Matrix4.diagonal3Values(scale, scale, 1).storage),
    );
  }

  @override
  bool shouldRepaint(covariant _FilmstripPainter old) => old.image != image;
}
