import 'package:flutter/material.dart';

import '../../app/art_image.dart';
import '../../app/theme.dart';
import '../../core/artwork.dart';
import '../shared/library_sheet.dart';
import 'effect_library.dart';
import 'effect_preview.dart';
import 'transition_library.dart';

/// Loops 0 to 1 for animated previews, holding briefly at each end.
class _Loop extends StatefulWidget {
  const _Loop({required this.builder, this.period = const Duration(milliseconds: 2400)});
  final Widget Function(BuildContext, double) builder;
  final Duration period;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.value));
}

const _gradients = [
  LinearGradient(colors: [Color(0xFFFF8A5C), Color(0xFFFF3D8B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  LinearGradient(colors: [Color(0xFF33D6E6), Color(0xFF7C5CFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
];

/// Browses every transition. Picking "None" reports null.
class TransitionBrowser extends StatefulWidget {
  const TransitionBrowser({super.key, required this.current, required this.onPick, this.cutCount = 1});
  final TransitionPreset? current;

  /// Gets the pick and whether it should go on every cut.
  final void Function(TransitionPreset? preset, bool everyCut) onPick;
  final int cutCount;

  @override
  State<TransitionBrowser> createState() => _TransitionBrowserState();
}

class _TransitionBrowserState extends State<TransitionBrowser> {
  final _lib = TransitionLibrary.instance;
  String? _category;
  String _text = '';
  bool _all = false;
  late List<TransitionPreset> _items = _lib.all;

  void _update() => setState(() => _items = _lib.search(category: _category, text: _text));

  @override
  Widget build(BuildContext context) {
    return _Loop(
      builder: (context, t) {
        // Hold on each clip for a moment, then run the transition.
        final progress = ((t - .2) / .6).clamp(0.0, 1.0);
        return LibrarySheet(
          title: 'Transitions',
          count: _lib.length,
          noun: 'transitions',
          onSearch: (v) {
            _text = v;
            _update();
          },
          searchHint: 'Search: circle, spiral, blinds, wave…',
          columns: 3,
          aspect: .82,
          filters: [
            if (widget.cutCount > 1) ApplyAllSwitch(label: 'Apply to all ${widget.cutCount} cuts', value: _all, onChanged: (v) => setState(() => _all = v)),
            FilterChips<String>(
              values: TransitionLibrary.categories,
              selected: _category,
              label: (c) => c,
              onSelected: (c) {
                _category = c;
                _update();
              },
            ),
          ],
          itemCount: _items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return LibraryTile(
                key: const ValueKey('transition-none'),
                caption: 'None (cut)',
                selected: widget.current == null,
                onTap: () => widget.onPick(null, _all),
                child: const Icon(Icons.block_rounded, color: AppColors.muted),
              );
            }
            final p = _items[i - 1];
            return LibraryTile(
              key: ValueKey('transition-${p.id}'),
              caption: p.name,
              selected: widget.current?.id == p.id,
              onTap: () => widget.onPick(p, _all),
              child: CustomPaint(
                painter: TransitionThumbPainter(p, progress, from: _gradients[0], to: _gradients[1]),
              ),
            );
          },
        );
      },
    );
  }
}

/// How much of the video a picked effect covers.
enum EffectReach {
  seconds1('1 s', 1000),
  seconds2('2 s', 2000),
  seconds3('3 s', 3000),
  seconds5('5 s', 5000),
  seconds10('10 s', 10000),
  clip('This clip', null),
  everyClip('Whole video', null);

  const EffectReach(this.label, this.ms);
  final String label;

  /// Length from the playhead, or null for whole clips.
  final int? ms;
}

/// Browses every clip effect.
class EffectBrowser extends StatefulWidget {
  const EffectBrowser({super.key, required this.current, required this.onPick, this.reaches = EffectReach.values, this.initialReach = EffectReach.seconds3});
  final ClipEffect? current;

  /// Gets the pick and how much of the video it should cover.
  final void Function(ClipEffect? effect, EffectReach reach) onPick;
  final List<EffectReach> reaches;
  final EffectReach initialReach;

  @override
  State<EffectBrowser> createState() => _EffectBrowserState();
}

class _EffectBrowserState extends State<EffectBrowser> {
  final _lib = EffectLibrary.instance;
  String? _group;
  String _text = '';
  late EffectReach _reach = widget.initialReach;
  late List<ClipEffect> _items = _lib.all;

  void _update() => setState(() => _items = _lib.search(group: _group, text: _text));

  @override
  Widget build(BuildContext context) {
    const loopMs = 3000;
    return _Loop(
      period: const Duration(milliseconds: loopMs),
      builder: (context, t) {
        final timeMs = (t * loopMs).round();
        return LibrarySheet(
          title: 'Effects',
          count: _lib.length,
          noun: 'effects',
          onSearch: (v) {
            _text = v;
            _update();
          },
          searchHint: 'Search: zoom, shake, grain, flash…',
          columns: 3,
          aspect: .7,
          filters: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
              child: Text(
                _reach.ms == null ? 'Covers ${_reach.label.toLowerCase()}' : 'Covers ${_reach.label} from the playhead',
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ),
            FilterChips<EffectReach>(
              key: const ValueKey('effect-reach'),
              values: widget.reaches,
              selected: _reach,
              label: (r) => r.label,
              showAll: false,
              onSelected: (r) {
                if (r != null) setState(() => _reach = r);
              },
            ),
            FilterChips<String>(
              values: EffectLibrary.groups,
              selected: _group,
              label: (c) => c,
              onSelected: (g) {
                _group = g;
                _update();
              },
            ),
          ],
          itemCount: _items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return LibraryTile(
                key: const ValueKey('effect-none'),
                caption: 'No effect',
                selected: widget.current == null,
                onTap: () => widget.onPick(null, _reach),
                child: const Icon(Icons.block_rounded, color: AppColors.muted),
              );
            }
            final e = _items[i - 1];
            final scene = artScenes[i % artScenes.length];
            return LibraryTile(
              key: ValueKey('effect-${e.id}'),
              caption: e.name,
              selected: widget.current?.id == e.id,
              onTap: () => widget.onPick(e, _reach),
              child: EffectView(effect: e, timeMs: timeMs, durationMs: loopMs, child: ArtImage(scene)),
            );
          },
        );
      },
    );
  }
}

/// A row of moving transition previews for quick picks in the editor panel.
class TransitionStrip extends StatelessWidget {
  const TransitionStrip({super.key, required this.current, required this.onPick});
  final TransitionPreset? current;
  final ValueChanged<TransitionPreset> onPick;

  static const featured = [
    'crossfade',
    'fadeBlack',
    'slideLeft',
    'circle-centre-open-m',
    'wipe-45-f',
    'spiral-2-in-m',
    'blinds-0-8-s',
    'clock-1-0-cw-m',
    'cells-16-random-s',
    'sine-0-10-4-m',
    'rings-5-out-m',
    'checker-6-45-s',
    'diamond-centre-open-f',
    'comb-90-12-s',
    'zigzag-45-10-8-m',
  ];

  @override
  Widget build(BuildContext context) {
    final lib = TransitionLibrary.instance;
    final presets = [for (final id in featured) ?lib.byId(id)];
    return SizedBox(
      height: 86,
      child: _Loop(
        builder: (context, t) {
          final progress = ((t - .2) / .6).clamp(0.0, 1.0);
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = presets[i];
              return SizedBox(
                width: 62,
                child: LibraryTile(
                  key: ValueKey('quick-${p.id}'),
                  caption: p.name.split(' · ').first,
                  selected: current?.id == p.id,
                  onTap: () => onPick(p),
                  child: CustomPaint(
                    painter: TransitionThumbPainter(p, progress, from: _gradients[0], to: _gradients[1]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
