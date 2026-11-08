import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../canvas/document.dart';
import '../../canvas/renderer.dart';
import '../../canvas/template_library.dart';
import '../../canvas/templates.dart';
import '../editor/editor_screen.dart';

/// Searchable grid of every template. Tiles build lazily as they scroll in.
class TemplateBrowser extends StatefulWidget {
  const TemplateBrowser({super.key});

  @override
  State<TemplateBrowser> createState() => _TemplateBrowserState();
}

class _TemplateBrowserState extends State<TemplateBrowser> {
  String _query = '';
  String? _topic;

  @override
  Widget build(BuildContext context) {
    final results = searchTemplates(_query, topic: _topic);
    return Scaffold(
      appBar: AppBar(title: Text('Templates (${allTemplates.length})')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                key: const ValueKey('template-search'),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search: wedding, sale, story…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _chip('All', _topic == null, () => setState(() => _topic = null)),
                  for (final t in templateTopics) _chip(t, _topic == t, () => setState(() => _topic = t)),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No templates match that search.', style: TextStyle(color: AppColors.muted)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: .62,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final t = results[i];
                        return TemplateTile(
                          key: ValueKey(t.name),
                          template: t,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => EditorScreen(document: t.build())),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

/// A live miniature of a template, drawn by the same renderer as the editor.
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
    SceneRenderer.prepare(_doc.layers).then((_) {
      if (mounted) setState(() {});
    }).catchError((Object e) {
      debugPrint('Template fonts unavailable: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.template.name} template',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _doc.aspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: RepaintBoundary(child: CustomPaint(painter: _DocPainter(_doc))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.template.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _DocPainter extends CustomPainter {
  _DocPainter(this.doc);
  final CanvasDocument doc;

  @override
  void paint(Canvas canvas, Size size) => SceneRenderer.paintDocument(canvas, size, doc);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
