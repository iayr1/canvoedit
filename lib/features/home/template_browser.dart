import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../app/theme.dart';
import '../../canvas/document.dart';
import '../../canvas/renderer.dart';
import '../../canvas/template_engine.dart';
import '../../canvas/template_library.dart';
import '../../canvas/templates.dart';
import '../editor/editor_screen.dart';

String formatCount(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// Searchable, filterable gallery over the whole template catalogue.
class TemplateBrowser extends StatefulWidget {
  const TemplateBrowser({super.key, this.initial = const TemplateQuery(), this.title, this.embedded = false, this.autofocus = false});

  final TemplateQuery initial;
  final String? title;

  /// True when shown as a tab, which has no back button.
  final bool embedded;
  final bool autofocus;

  @override
  State<TemplateBrowser> createState() => _TemplateBrowserState();
}

class _TemplateBrowserState extends State<TemplateBrowser> {
  late TemplateQuery _query = widget.initial;
  late TemplateResults _results = TemplateCatalog.search(_query);
  late final _search = TextEditingController(text: widget.initial.text);
  String? _group;

  void _set(TemplateQuery q) {
    setState(() {
      _query = q;
      _results = TemplateCatalog.search(q);
    });
  }

  void _setGroup(String? group) {
    _group = group;
    _set(_query.copyWith(formats: () => group == null ? null : TemplateCatalog.formatsInGroup(group)));
  }

  int get _activeFilters => [_query.formats, _query.topics, _query.styles, _query.colors].where((s) => s != null).length + (_query.photos == null ? 0 : 1);

  Future<void> _openFilters() async {
    final q = await showModalBottomSheet<TemplateQuery>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(query: _query),
    );
    if (q != null) {
      _group = null;
      _set(q);
    }
  }

  void _open(TemplateSpec spec) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EditorScreen(document: spec.build())));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Theme(
      data: buildLightTheme(),
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: !widget.embedded, title: Text(widget.title ?? 'Templates')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('template-search'),
                      controller: _search,
                      autofocus: widget.autofocus,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => _set(_query.copyWith(text: v)),
                      style: const TextStyle(color: LightColors.text),
                      decoration: InputDecoration(
                        hintText: 'Try "linkedin banner" or "birthday story"',
                        hintStyle: const TextStyle(color: LightColors.muted),
                        prefixIcon: const Icon(Icons.search_rounded, color: LightColors.muted),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded, color: LightColors.muted),
                                onPressed: () {
                                  _search.clear();
                                  _set(_query.copyWith(text: ''));
                                },
                              ),
                        filled: true,
                        fillColor: LightColors.card,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: LightColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: LightColors.line),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Badge(
                    isLabelVisible: _activeFilters > 0,
                    label: Text('$_activeFilters'),
                    backgroundColor: AppColors.pink,
                    child: Material(
                      color: LightColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: LightColors.line),
                      ),
                      child: IconButton(
                        tooltip: 'Filters',
                        icon: const Icon(Icons.tune_rounded, color: LightColors.text),
                        onPressed: _openFilters,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _LightChip(label: 'All', selected: _group == null && _query.formats == null, onTap: () => _setGroup(null)),
                  for (final g in templateFormatGroups) _LightChip(label: g, selected: _group == g, onTap: () => _setGroup(g)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
              child: Row(
                children: [
                  Text(
                    '${formatCount(results.length)} templates',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: LightColors.text),
                  ),
                  const Spacer(),
                  if (!_query.isEmpty)
                    TextButton(
                      onPressed: () {
                        _search.clear();
                        _group = null;
                        _set(const TemplateQuery());
                      },
                      child: const Text('Clear all'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: results.length == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _activeFilters > 0
                                  ? 'No templates match your search with the filters you picked.'
                                  : 'Nothing matches that yet. Try a platform like "Instagram", a topic like "wedding", or a colour like "mint".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: LightColors.muted),
                            ),
                            if (_activeFilters > 0) ...[
                              const SizedBox(height: 14),
                              GradientButton(
                                label: 'Clear filters',
                                compact: true,
                                onPressed: () {
                                  _group = null;
                                  _set(TemplateQuery(text: _query.text));
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : MasonryGridView.extent(
                      key: ValueKey(results.length),
                      // Two columns on phones, more as the screen widens.
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final spec = results[i];
                        return TemplateCard(key: ValueKey(spec.id), spec: spec, onTap: () => _open(spec));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  const _LightChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.brand : null,
          color: selected ? null : LightColors.chip,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : LightColors.text),
        ),
      ),
    ),
  );
}

/// A template preview, drawn live by the editor's own renderer.
class TemplateCard extends StatefulWidget {
  const TemplateCard({super.key, required this.spec, required this.onTap, this.showLabel = true});
  final TemplateSpec spec;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  late final CanvasDocument _doc = widget.spec.build();

  @override
  void initState() {
    super.initState();
    SceneRenderer.prepare(_doc.layers)
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object e) {
          debugPrint('Template preview incomplete: $e');
        });
  }

  @override
  Widget build(BuildContext context) {
    final format = widget.spec.formatInfo;
    return Semantics(
      button: true,
      label: '${widget.spec.name} template',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x1F2A1A5E), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  // Extreme banners are shown a little taller so they stay legible.
                  aspectRatio: _doc.aspectRatio.clamp(.35, 3.2),
                  child: RepaintBoundary(child: CustomPaint(painter: DocumentPainter(_doc))),
                ),
              ),
            ),
            if (widget.showLabel) ...[
              const SizedBox(height: 6),
              Text(
                widget.spec.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LightColors.text),
              ),
              Text(
                format.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: LightColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Paints a document scaled to fit, centred.
class DocumentPainter extends CustomPainter {
  DocumentPainter(this.doc);
  final CanvasDocument doc;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / doc.pixelWidth < size.height / doc.pixelHeight ? size.width / doc.pixelWidth : size.height / doc.pixelHeight;
    final drawn = Size(doc.pixelWidth * scale, doc.pixelHeight * scale);
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(doc.background.color));
    canvas.translate((size.width - drawn.width) / 2, (size.height - drawn.height) / 2);
    SceneRenderer.paintDocument(canvas, drawn, doc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Legacy tile used for the hand-made featured templates.
class TemplateTile extends StatefulWidget {
  const TemplateTile({super.key, required this.template, required this.onTap});
  final DesignTemplate template;
  final VoidCallback onTap;

  @override
  State<TemplateTile> createState() => _TemplateTileState();
}

class _TemplateTileState extends State<TemplateTile> {
  late final CanvasDocument _doc = widget.template.build();

  @override
  void initState() {
    super.initState();
    SceneRenderer.prepare(_doc.layers)
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object e) {
          debugPrint('Template fonts unavailable: $e');
        });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _doc.aspectRatio,
        child: CustomPaint(painter: DocumentPainter(_doc)),
      ),
    ),
  );
}

/// Every filter, grouped. Changes apply when the sheet closes with Show.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.query});
  final TemplateQuery query;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<int> _formats = {...?widget.query.formats};
  late Set<int> _topics = {...?widget.query.topics};
  late Set<int> _styles = {...?widget.query.styles};
  late Set<int> _colors = {...?widget.query.colors};
  late int? _photos = widget.query.photos;

  TemplateQuery get _query => TemplateQuery(
    formats: _formats.isEmpty ? null : _formats,
    topics: _topics.isEmpty ? null : _topics,
    styles: _styles.isEmpty ? null : _styles,
    colors: _colors.isEmpty ? null : _colors,
    photos: _photos,
    text: widget.query.text,
  );

  void _toggle(Set<int> set, int i) => setState(() => set.contains(i) ? set.remove(i) : set.add(i));

  Widget _section(String title, List<Widget> chips) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LightColors.text),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    ),
  );

  Widget _chip(String label, bool on, VoidCallback onTap, {Widget? leading}) => FilterChip(
    label: Text(label),
    avatar: leading,
    selected: on,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? Colors.white : LightColors.text),
    selectedColor: AppColors.violet,
    backgroundColor: LightColors.chip,
    side: BorderSide.none,
    shape: const StadiumBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final count = TemplateCatalog.search(_query).length;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filters',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LightColors.text),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _formats = {};
                      _topics = {};
                      _styles = {};
                      _colors = {};
                      _photos = null;
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  for (final group in templateFormatGroups)
                    _section(group, [
                      for (var i = 0; i < templateFormats.length; i++)
                        if (templateFormats[i].group == group) _chip(templateFormats[i].name, _formats.contains(i), () => _toggle(_formats, i)),
                    ]),
                  _section('Topic', [
                    for (var i = 0; i < templateTopicNames.length; i++) _chip(templateTopicNames[i], _topics.contains(i), () => _toggle(_topics, i)),
                  ]),
                  _section('Style', [
                    for (var i = 0; i < templateStyles.length; i++) _chip(templateStyles[i].name, _styles.contains(i), () => _toggle(_styles, i)),
                  ]),
                  _section('Colour', [
                    for (var i = 0; i < templateColorNames.length; i++)
                      _chip(
                        templateColorNames[i],
                        _colors.contains(i),
                        () => _toggle(_colors, i),
                        leading: CircleAvatar(
                          backgroundColor: Color(templatePalettes[i].accent),
                          child: CircleAvatar(radius: 5, backgroundColor: Color(templatePalettes[i].bg)),
                        ),
                      ),
                  ]),
                  _section('Photos', [
                    for (final n in const [0, 1, 2, 3, 4])
                      _chip(n == 0 ? 'No photos' : '$n photo${n == 1 ? '' : 's'}', _photos == n, () => setState(() => _photos = _photos == n ? null : n)),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: GradientButton(label: 'Show ${formatCount(count)} templates', onPressed: count == 0 ? null : () => Navigator.pop(context, _query)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
