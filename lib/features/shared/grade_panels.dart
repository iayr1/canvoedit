import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/color/filter_presets.dart';
import '../../core/color/grade.dart';

/// Horizontal filter browser with categories and a strength slider. Used by the
/// photo, design and video editors.
class FilterStrip extends StatefulWidget {
  const FilterStrip({
    super.key,
    required this.grade,
    required this.thumbnail,
    required this.onChanged,
    required this.onCommit,
  });

  final Grade grade;

  /// Source picture for the preview tiles, shown through each filter.
  final Widget thumbnail;
  final VoidCallback onChanged;
  final VoidCallback onCommit;

  @override
  State<FilterStrip> createState() => _FilterStripState();
}

class _FilterStripState extends State<FilterStrip> {
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final grade = widget.grade;
    final items = _category == 'All'
        ? filterPresets
        : [filterPresets.first, ...filterPresets.where((p) => p.category == _category)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (grade.filterId != 'original')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Strength', style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
                  child: Text('${(grade.strength * 100).round()}', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final c in filterCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final preset = items[i];
              final selected = preset.id == grade.filterId;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    grade.filterId = preset.id;
                    grade.strength = 1;
                  });
                  widget.onChanged();
                  widget.onCommit();
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selected ? AppColors.coral : Colors.transparent, width: 2),
                        ),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(preset.matrix),
                          child: widget.thumbnail,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 64,
                        child: Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: selected ? AppColors.coral : Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Manual colour controls, grouped into Light, Color, Effects and Grade.
class AdjustPanel extends StatefulWidget {
  const AdjustPanel({
    super.key,
    required this.grade,
    required this.onChanged,
    required this.onCommit,
    this.height = 190,
  });

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
                          p.key == 'hue'
                              ? '${(values[p.key] ?? 0).round()}'
                              : '${((values[p.key] ?? 0) * 100).round()}',
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
  0xFFFFFFFF, 0xFF000000, 0xFF6B7280, 0xFFFF5C39, 0xFFEF4444, 0xFFF97316, 0xFFFACC15,
  0xFF22C55E, 0xFF14B8A6, 0xFF0EA5E9, 0xFF3B82F6, 0xFF7C5CFF, 0xFFD946EF, 0xFFEC4899,
  0xFFF7F1E3, 0xFF14342B, 0xFF1F2937, 0xFF7C1D6F,
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
          if (allowNone)
            IconButton(
              tooltip: 'None',
              icon: const Icon(Icons.block, size: 20),
              onPressed: () => onPick(null),
            ),
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

/// A square icon-and-label button for the bottom tool rails.
class ToolButton extends StatelessWidget {
  const ToolButton({super.key, required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.line : (active ? AppColors.coral : Colors.white);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
