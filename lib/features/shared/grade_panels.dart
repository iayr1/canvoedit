import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/color/filter_presets.dart';
import '../../core/color/grade.dart';

/// Filters as round lenses on a swipeable carousel. The lens in the centre is
/// applied live, so swiping through looks shows each one on the picture. Used by
/// the photo, design and video editors.
class FilterStrip extends StatefulWidget {
  const FilterStrip({super.key, required this.grade, required this.thumbnail, required this.onChanged, required this.onCommit});

  final Grade grade;

  /// Source picture shown inside each lens, through that lens's filter.
  final Widget thumbnail;
  final VoidCallback onChanged;
  final VoidCallback onCommit;

  @override
  State<FilterStrip> createState() => _FilterStripState();
}

class _FilterStripState extends State<FilterStrip> {
  static const _lens = 62.0;
  static const _viewport = .2;

  String _category = 'All';
  late List<FilterPreset> _items = _presetsFor(_category);
  late PageController _pages = PageController(viewportFraction: _viewport, initialPage: _indexOfCurrent());

  List<FilterPreset> _presetsFor(String category) =>
      category == 'All' ? filterPresets : [filterPresets.first, ...filterPresets.where((p) => p.category == category)];

  int _indexOfCurrent() => _items.indexWhere((p) => p.id == widget.grade.filterId).clamp(0, _items.length - 1);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _setCategory(String category) {
    final old = _pages;
    final items = _presetsFor(category);
    // Opening a category jumps to its first look, unless the current one is in it.
    final keep = items.any((p) => p.id == widget.grade.filterId);
    setState(() {
      _category = category;
      _items = items;
      if (!keep && items.length > 1) {
        widget.grade.filterId = items[1].id;
        widget.grade.strength = 1;
      }
      _pages = PageController(viewportFraction: _viewport, initialPage: _indexOfCurrent());
    });
    if (!keep && items.length > 1) {
      widget.onChanged();
      widget.onCommit();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _apply(int index) {
    final preset = _items[index];
    if (preset.id == widget.grade.filterId) return;
    setState(() {
      widget.grade.filterId = preset.id;
      widget.grade.strength = 1;
    });
    widget.onChanged();
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    final grade = widget.grade;
    final current = filterById(grade.filterId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in filterCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _CategoryPill(label: c, selected: _category == c, onTap: () => _setCategory(c)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            current.name,
            key: ValueKey(current.id),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ),
        SizedBox(
          height: _lens + 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The fixed ring marks the lens being applied, like a camera shutter.
              IgnorePointer(
                child: Container(
                  width: _lens + 14,
                  height: _lens + 14,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.ring),
                ),
              ),
              ScrollConfiguration(
                // Mouse and trackpad drags swipe too, not only touch.
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                child: PageView.builder(
                  key: ValueKey(_category),
                  controller: _pages,
                  itemCount: _items.length,
                  onPageChanged: _apply,
                  itemBuilder: (context, i) => AnimatedBuilder(
                    animation: _pages,
                    builder: (context, child) {
                      final page = _pages.hasClients && _pages.position.haveDimensions ? (_pages.page ?? i.toDouble()) : _indexOfCurrent().toDouble();
                      final distance = (page - i).abs().clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: 1 - distance * .2,
                        child: Opacity(opacity: 1 - distance * .2, child: child),
                      );
                    },
                    child: GestureDetector(
                      onTap: () => _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic),
                      child: Center(
                        child: _Lens(size: _lens, matrix: _items[i].matrix, child: widget.thumbnail),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: grade.filterId == 'original'
              ? const SizedBox(height: 4, width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.opacity, size: 16, color: AppColors.muted),
                      Expanded(
                        child: Slider(
                          value: grade.strength,
                          onChanged: (v) {
                            setState(() => grade.strength = v);
                            widget.onChanged();
                          },
                          onChangeEnd: (_) => widget.onCommit(),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${(grade.strength * 100).round()}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Lens extends StatelessWidget {
  const _Lens({required this.size, required this.matrix, required this.child});
  final double size;
  final List<double> matrix;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: .9), width: 2),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: ClipOval(
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: SizedBox.expand(child: child),
      ),
    ),
  );
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: selected ? AppGradients.brand : null,
        color: selected ? null : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.muted),
      ),
    ),
  );
}

/// Manual colour controls, grouped into Light, Color, Effects and Grade.
class AdjustPanel extends StatefulWidget {
  const AdjustPanel({super.key, required this.grade, required this.onChanged, required this.onCommit, this.height = 190});

  final Grade grade;
  final VoidCallback onChanged;
  final VoidCallback onCommit;
  final double height;

  @override
  State<AdjustPanel> createState() => _AdjustPanelState();
}

class _AdjustPanelState extends State<AdjustPanel> {
  String _group = 'Light';

  @override
  Widget build(BuildContext context) {
    final values = widget.grade.values;
    final params = adjustParams.where((p) => p.group == _group).toList();
    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 10),
                    children: [
                      for (final g in const ['Light', 'Color', 'Effects', 'Grade'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(g, style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            selected: _group == g,
                            onSelected: (_) => setState(() => _group = g),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(values.clear);
                  widget.onChanged();
                  widget.onCommit();
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final p in params)
                  Row(
                    children: [
                      SizedBox(width: 104, child: Text(p.label, style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: Slider(
                          min: p.min,
                          max: p.max,
                          value: (values[p.key] ?? 0).clamp(p.min, p.max),
                          onChanged: (v) {
                            setState(() => values[p.key] = v);
                            widget.onChanged();
                          },
                          onChangeEnd: (_) => widget.onCommit(),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          p.key == 'hue' ? '${(values[p.key] ?? 0).round()}' : '${((values[p.key] ?? 0) * 100).round()}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const swatchColors = <int>[
  0xFFFFFFFF,
  0xFF000000,
  0xFF6B7280,
  0xFFFF5C39,
  0xFFEF4444,
  0xFFF97316,
  0xFFFACC15,
  0xFF22C55E,
  0xFF14B8A6,
  0xFF0EA5E9,
  0xFF3B82F6,
  0xFF7C5CFF,
  0xFFD946EF,
  0xFFEC4899,
  0xFFF7F1E3,
  0xFF14342B,
  0xFF1F2937,
  0xFF7C1D6F,
];

class SwatchRow extends StatelessWidget {
  const SwatchRow({super.key, required this.selected, required this.onPick, this.allowNone = false});

  final int? selected;
  final ValueChanged<int?> onPick;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (allowNone) IconButton(tooltip: 'None', icon: const Icon(Icons.block, size: 20), onPressed: () => onPick(null)),
          for (final c in swatchColors)
            GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: selected == c ? AppColors.coral : AppColors.line, width: selected == c ? 3 : 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An icon-and-label button for the bottom tool rails. The active tool's icon
/// sits on the brand gradient.
class ToolButton extends StatelessWidget {
  const ToolButton({super.key, required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 32,
              decoration: BoxDecoration(
                gradient: active ? AppGradients.brand : null,
                color: active ? null : AppColors.surfaceHigh.withValues(alpha: enabled ? 1 : .4),
                borderRadius: BorderRadius.circular(12),
                boxShadow: active ? [BoxShadow(color: AppColors.pink.withValues(alpha: .4), blurRadius: 12)] : null,
              ),
              child: Icon(icon, size: 19, color: enabled ? Colors.white : AppColors.line),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: active ? Colors.white : (enabled ? AppColors.muted : AppColors.line)),
            ),
          ],
        ),
      ),
    );
  }
}
