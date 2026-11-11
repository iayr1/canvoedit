import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../canvas/layer.dart';
import '../../canvas/renderer.dart';
import '../../canvas/sticker_library.dart';
import '../../canvas/word_library.dart';

String formatLibraryCount(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// The frame shared by every content browser: a tall dark sheet with a title,
/// a count, an optional search field, rows of filter chips and a lazy grid.
class LibrarySheet extends StatelessWidget {
  const LibrarySheet({
    super.key,
    required this.title,
    required this.count,
    required this.noun,
    required this.filters,
    required this.itemCount,
    required this.itemBuilder,
    this.onSearch,
    this.searchHint = 'Search',
    this.columns = 3,
    this.aspect = 1,
    this.controller,
  });

  final String title;
  final int count;
  final String noun;
  final List<Widget> filters;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<String>? onSearch;
  final String searchHint;
  final int columns;
  final double aspect;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.3)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${formatLibraryCount(count)} $noun',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        if (onSearch != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: onSearch,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: searchHint,
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
        ...filters,
        const SizedBox(height: 6),
        Expanded(
          child: itemCount == 0
              ? const Center(
                  child: Text('Nothing matches', style: TextStyle(color: AppColors.muted)),
                )
              : LayoutBuilder(
                  builder: (context, box) => GridView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      // [columns] fits a phone; wider screens get more tiles of the same size.
                      crossAxisCount: (box.maxWidth / (384 / columns)).floor().clamp(columns, columns * 4),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: aspect,
                    ),
                    itemCount: itemCount,
                    itemBuilder: itemBuilder,
                  ),
                ),
        ),
      ],
    );
  }
}

/// A switch row for applying a pick to every clip or cut at once.
class ApplyAllSwitch extends StatelessWidget {
  const ApplyAllSwitch({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 10, 0),
    child: Row(
      children: [
        const Icon(Icons.select_all_rounded, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Switch(key: const ValueKey('apply-all'), value: value, onChanged: onChanged, activeTrackColor: AppColors.pink),
      ],
    ),
  );
}

/// A horizontal row of single-choice chips, with "All" first.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.allLabel = 'All',
    this.showAll = true,
  });

  /// Whether to lead with an "All" chip.
  final bool showAll;

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onSelected;
  final String allLabel;

  Widget _chip(String text, bool on, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          gradient: on ? AppGradients.brand : null,
          color: on ? null : Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: Colors.white),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      children: [
        if (showAll) _chip(allLabel, selected == null, () => onSelected(null)),
        for (final v in values) _chip(label(v), v == selected, () => onSelected(v)),
      ],
    ),
  );
}

/// Opens a tall content browser sheet in the editor's dark theme.
Future<T?> showLibrarySheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    constraints: const BoxConstraints(maxWidth: 1000),
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      // Short landscape screens get nearly the full height.
      return SizedBox(height: size.height * (size.height < 500 ? .92 : .78), child: builder(context));
    },
  );
}

/// A rounded tile with a caption, used by every browser grid.
class LibraryTile extends StatelessWidget {
  const LibraryTile({super.key, required this.child, required this.onTap, this.caption, this.selected = false, this.background});

  final Widget child;
  final VoidCallback onTap;
  final String? caption;
  final bool selected;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.brand : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: selected ? [BoxShadow(color: AppColors.pink.withValues(alpha: .4), blurRadius: 12)] : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(selected ? 2.5 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(selected ? 13.5 : 16),
                  child: ColoredBox(
                    color: background ?? AppColors.surfaceHigh,
                    child: SizedBox.expand(child: child),
                  ),
                ),
              ),
            ),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints one layer scaled to fit its box, for previews of text and stickers.
class LayerPreviewPainter extends CustomPainter {
  LayerPreviewPainter(this.layer, {this.fill = .82, this.revision = 0});
  final CanvasLayer layer;
  final double fill;

  /// Bumped when fonts finish loading, so cached previews repaint.
  final int revision;

  static const _virtual = Size(600, 600);

  @override
  void paint(Canvas canvas, Size size) {
    layer
      ..cx = 0
      ..cy = 0;
    final s = SceneRenderer.layerSize(layer, _virtual);
    if (s.width <= 0 || s.height <= 0) return;
    final k = (size.width * fill / s.width).clamp(0.0, size.height * fill / s.height);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);
    SceneRenderer.paintLayer(canvas, _virtual, layer);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LayerPreviewPainter old) => old.layer != layer || old.revision != revision;
}

/// Browses designer words and labels. Picking one returns a text layer; with
/// [restyleText], every look shows that text instead and the pick restyles it.
class WordBrowser extends StatefulWidget {
  const WordBrowser({super.key, required this.onPick, this.restyleText});
  final ValueChanged<DesignerWord> onPick;
  final String? restyleText;

  @override
  State<WordBrowser> createState() => _WordBrowserState();
}

class _WordBrowserState extends State<WordBrowser> {
  String? _category;
  WordTreatment? _treatment;
  String _text = '';
  int _fontsReady = 0;
  late WordResults _results = _search();
  final _layers = <int, CanvasLayer>{};

  @override
  void initState() {
    super.initState();
    SceneRenderer.prepare([for (final f in wordFonts) CanvasLayer.text('a', font: f)])
        .then((_) {
          if (mounted) setState(() => _fontsReady++);
        })
        .catchError((Object _) {});
  }

  WordResults _search() {
    final restyle = widget.restyleText;
    if (restyle != null) {
      return WordResults.search(category: 'Custom', treatment: _treatment, text: restyle.isEmpty ? 'Text' : restyle);
    }
    return WordResults.search(category: _category, treatment: _treatment, text: _text);
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _results = _search();
      _layers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final restyling = widget.restyleText != null;
    return LibrarySheet(
      title: restyling ? 'Text looks' : 'Designer words',
      count: restyling ? _results.length : WordResults.total,
      noun: restyling ? 'looks' : 'words',
      onSearch: restyling ? null : (t) => _update(() => _text = t),
      searchHint: 'Search or type your own words',
      columns: 2,
      aspect: 1.5,
      filters: [
        if (!restyling)
          FilterChips<String>(values: wordCategories.keys.toList(), selected: _category, label: (c) => c, onSelected: (c) => _update(() => _category = c)),
        FilterChips<WordTreatment>(
          values: WordTreatment.values,
          selected: _treatment,
          label: (t) => t.label,
          allLabel: 'All looks',
          onSelected: (t) => _update(() => _treatment = t),
        ),
      ],
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final word = _results[i];
        final layer = _layers[i] ??= word.toLayer();
        return LibraryTile(
          key: ValueKey('word-$i'),
          background: const Color(0xFF221E33),
          caption: word.style.name,
          onTap: () => widget.onPick(word),
          child: CustomPaint(painter: LayerPreviewPainter(layer, revision: _fontsReady)),
        );
      },
    );
  }
}

/// Browses emoji and shape stickers.
class StickerBrowser extends StatefulWidget {
  const StickerBrowser({super.key, required this.onPick});
  final ValueChanged<StickerItem> onPick;

  @override
  State<StickerBrowser> createState() => _StickerBrowserState();
}

class _StickerBrowserState extends State<StickerBrowser> {
  String? _category;
  late List<StickerItem> _items = StickerLibrary.instance.inCategory(null);

  @override
  Widget build(BuildContext context) {
    return LibrarySheet(
      title: 'Stickers',
      count: StickerLibrary.instance.length,
      noun: 'stickers',
      columns: 6,
      filters: [
        FilterChips<String>(
          values: StickerLibrary.categories,
          selected: _category,
          label: (c) => c,
          onSelected: (c) => setState(() {
            _category = c;
            _items = StickerLibrary.instance.inCategory(c);
          }),
        ),
      ],
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final item = _items[i];
        return GestureDetector(
          key: ValueKey('sticker-$i'),
          onTap: () => widget.onPick(item),
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: item.emoji != null
                  ? FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(item.emoji!, style: const TextStyle(fontSize: 30)),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: CustomPaint(size: Size.infinite, painter: _ShapePainter(item)),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.item);
  final StickerItem item;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final kind = item.shape!;
    final s = kind == ShapeKind.line ? Size(side, side * .12) : Size(side, side);
    canvas.translate(size.width / 2, size.height / 2);
    final paint = Paint()..color = Color(item.color);
    if (kind == ShapeKind.line) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .1
        ..strokeCap = StrokeCap.round;
    }
    canvas.drawPath(SceneRenderer.shapePath(kind, s), paint);
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) => old.item != item;
}
