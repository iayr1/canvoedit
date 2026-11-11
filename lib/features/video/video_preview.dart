import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../canvas/renderer.dart';
import '../../core/media.dart';
import 'effect_library.dart';
import 'effect_preview.dart';
import 'playback_engine.dart';
import 'transition_library.dart';
import 'video_project.dart';

/// Shows the current clip, or two clips composited during a transition.
class VideoPreview extends StatelessWidget {
  const VideoPreview({super.key, required this.engine});
  final PlaybackEngine engine;

  @override
  Widget build(BuildContext context) {
    final f = engine.frame;
    if (f == null) return const ColoredBox(color: Colors.black);
    final current = _ClipView(clip: f.clip, player: engine.playerFor(f.clip), sourceMs: f.clipTimeMs);
    final next = f.next;
    final project = engine.project;
    final preset = TransitionLibrary.instance.forClip(f.clip);
    final incoming = next == null ? null : _ClipView(clip: next, player: engine.playerFor(next), sourceMs: f.nextTimeMs);
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: incoming == null || preset == null
            ? current
            : preset.isPattern
            ? PatternTransitionView(
                preset: preset,
                progress: f.progress,
                outgoing: current,
                incoming: incoming,
                frameWidth: project.width,
                frameHeight: project.height,
              )
            : _Transition(type: preset.classic!, progress: f.progress, outgoing: current, incoming: incoming),
      ),
    );
  }
}

class _ClipView extends StatelessWidget {
  const _ClipView({required this.clip, required this.player, required this.sourceMs});
  final VideoClip clip;
  final VideoPlayerController? player;

  /// Position in the source file, used to time effects.
  final int sourceMs;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (clip.kind == ClipKind.image) {
      final image = ImageBank.instance.peek(clip.path);
      if (image == null) {
        ImageBank.instance.load(clip.path).ignore();
        return const SizedBox.expand();
      }
      content = SizedBox(
        width: image.width.toDouble(),
        height: image.height.toDouble(),
        child: RawImage(image: image),
      );
    } else {
      final p = player;
      if (p == null) return const SizedBox.expand();
      content = SizedBox(width: p.value.size.width, height: p.value.size.height, child: VideoPlayer(p));
    }
    Widget view = SizedBox.expand(
      child: FittedBox(fit: clip.fit == ClipFit.fit ? BoxFit.contain : BoxFit.cover, clipBehavior: Clip.hardEdge, child: content),
    );
    if (clip.flipH) view = Transform.flip(flipX: true, child: view);
    if (!clip.grade.isNeutral) {
      view = ColorFiltered(colorFilter: ColorFilter.matrix(clip.grade.matrix), child: view);
    }
    if (clip.grade.vignette > 0) {
      view = CustomPaint(foregroundPainter: _VignettePainter(clip.grade.vignette), child: view);
    }
    final effect = EffectLibrary.instance.byId(clip.effect);
    if (effect != null) {
      final local = ((sourceMs - clip.inMs) / clip.speed).round().clamp(0, clip.durationMs);
      view = EffectView(effect: effect, timeMs: local, durationMs: clip.durationMs, child: view);
    }
    return view;
  }
}

class _VignettePainter extends CustomPainter {
  _VignettePainter(this.amount);
  final double amount;

  @override
  void paint(Canvas canvas, Size size) => SceneRenderer.paintVignette(canvas, Offset.zero & size, amount);

  @override
  bool shouldRepaint(covariant _VignettePainter old) => old.amount != amount;
}

class _Transition extends StatelessWidget {
  const _Transition({required this.type, required this.progress, required this.outgoing, required this.incoming});
  final TransitionType type;
  final double progress;
  final Widget outgoing;
  final Widget incoming;

  Widget _dip(Color color) {
    final first = progress < .5;
    final amount = first ? progress * 2 : (1 - progress) * 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        first ? outgoing : incoming,
        ColoredBox(color: color.withValues(alpha: amount)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = progress;
    switch (type) {
      case TransitionType.none || TransitionType.pattern:
        return outgoing;
      case TransitionType.crossfade:
        return Stack(
          fit: StackFit.expand,
          children: [
            outgoing,
            Opacity(opacity: p, child: incoming),
          ],
        );
      case TransitionType.fadeBlack:
        return _dip(Colors.black);
      case TransitionType.fadeWhite:
        return _dip(Colors.white);
      case TransitionType.wipeLeft:
        return Stack(
          fit: StackFit.expand,
          children: [
            outgoing,
            ClipRect(clipper: _WipeClipper(1 - p, 1), child: incoming),
          ],
        );
      case TransitionType.wipeRight:
        return Stack(
          fit: StackFit.expand,
          children: [
            outgoing,
            ClipRect(clipper: _WipeClipper(0, p), child: incoming),
          ],
        );
      case TransitionType.slideLeft:
        return Stack(
          fit: StackFit.expand,
          children: [
            FractionalTranslation(translation: Offset(-p, 0), child: outgoing),
            FractionalTranslation(translation: Offset(1 - p, 0), child: incoming),
          ],
        );
      case TransitionType.slideRight:
        return Stack(
          fit: StackFit.expand,
          children: [
            FractionalTranslation(translation: Offset(p, 0), child: outgoing),
            FractionalTranslation(translation: Offset(p - 1, 0), child: incoming),
          ],
        );
      case TransitionType.circleOpen:
        return Stack(
          fit: StackFit.expand,
          children: [
            outgoing,
            ClipPath(clipper: _CircleClipper(p), child: incoming),
          ],
        );
    }
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  _WipeClipper(this.from, this.to);
  final double from;
  final double to;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(size.width * from, 0, size.width * to, size.height);

  @override
  bool shouldReclip(covariant _WipeClipper old) => old.from != from || old.to != to;
}

class _CircleClipper extends CustomClipper<Path> {
  _CircleClipper(this.progress);
  final double progress;

  @override
  Path getClip(Size size) {
    final radius = math.sqrt(size.width * size.width + size.height * size.height) / 2 * progress;
    return Path()..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleClipper old) => old.progress != progress;
}
