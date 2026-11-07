import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../canvas/document.dart';
import '../../canvas/layer.dart';
import '../../canvas/renderer.dart';
import '../../canvas/templates.dart';
import '../../core/media.dart';
import '../../core/project_store.dart';
import '../editor/editor_screen.dart';
import '../video/video_editor_screen.dart';
import '../video/video_project.dart';

const samplePhotoPath = 'sample://photo';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  late Future<List<ProjectEntry>> _projects = ProjectStore.instance.list();

  @override
  void initState() {
    super.initState();
    ProjectStore.instance.revision.addListener(_reload);
  }

  @override
  void dispose() {
    ProjectStore.instance.revision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _projects = ProjectStore.instance.list();
    });
  }

  Future<void> _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  CanvasDocument _photoDocument(String path, String name, int width, int height) {
    final base = CanvasLayer.image(path, width, height, width: 1)
      ..name = 'Photo'
      ..isBase = true
      ..locked = true;
    return CanvasDocument(
      name: name,
      isPhoto: true,
      pixelWidth: width,
      pixelHeight: height,
      background: CanvasBackground(0xFF000000),
      layers: [base],
    );
  }

  Future<void> _editPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final path = await MediaLibrary.import(file);
    final image = await ImageBank.instance.load(path);
    await _open(EditorScreen(document: _photoDocument(path, 'Photo edit', image.width, image.height)));
  }

  /// A generated picture, so filters can be tried without picking from a gallery.
  Future<void> _trySample() async {
    final image = await _sampleImage();
    await _open(EditorScreen(document: _photoDocument(samplePhotoPath, 'Sample photo', image.width, image.height)));
  }

  /// The sample has no file behind it, so it is redrawn after each app launch.
  Future<ui.Image> _sampleImage() async {
    final existing = ImageBank.instance.peek(samplePhotoPath);
    if (existing != null) return existing;
    final image = await SceneRenderer.rasterize(1080, 1350, _paintSample);
    ImageBank.instance.put(samplePhotoPath, image);
    return image;
  }

  static void _paintSample(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height * .72), const [
          Color(0xFF28407A),
          Color(0xFFE76F51),
          Color(0xFFF4C27A),
        ], [0, .62, 1]),
    );
    c.drawCircle(Offset(s.width * .68, s.height * .5), s.width * .13, Paint()..color = const Color(0xFFFFE9B0));
    final far = Path()
      ..moveTo(0, s.height * .68)
      ..lineTo(s.width * .28, s.height * .5)
      ..lineTo(s.width * .55, s.height * .68)
      ..lineTo(s.width * .8, s.height * .56)
      ..lineTo(s.width, s.height * .66)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(far, Paint()..color = const Color(0xFF3D4F7C));
    c.drawRect(Rect.fromLTWH(0, s.height * .74, s.width, s.height * .26), Paint()..color = const Color(0xFF2A9D8F));
    c.drawRect(Rect.fromLTWH(0, s.height * .9, s.width, s.height * .1), Paint()..color = const Color(0xFF16302B));
  }

  void _newVideo() => _open(VideoEditorScreen(project: VideoProject()));

  void _newDesign() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Choose a size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              for (final p in canvasSizePresets)
                ListTile(
                  title: Text(p.name),
                  trailing: Text('${p.width} × ${p.height}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _open(EditorScreen(document: CanvasDocument(name: p.name, pixelWidth: p.width, pixelHeight: p.height)));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEntry(ProjectEntry entry) async {
    switch (entry.type) {
      case ProjectType.video:
        await _open(VideoEditorScreen(project: VideoProject.fromJson(entry.data)));
      case ProjectType.design:
      case ProjectType.photo:
        final doc = CanvasDocument.fromJson(entry.data);
        if (doc.layers.any((l) => l.path == samplePhotoPath)) await _sampleImage();
        if (mounted) await _open(EditorScreen(document: doc));
    }
  }

  Future<void> _confirmDelete(ProjectEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${entry.name}"?'),
        content: const Text('This project will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes ?? false) await ProjectStore.instance.delete(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -.5),
                    children: [
                      TextSpan(text: 'Canvo'),
                      TextSpan(text: ' Edit', style: TextStyle(color: AppColors.coral)),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _ActionCard(icon: Icons.movie_creation_outlined, label: 'Video', color: AppColors.coral, onTap: _newVideo)),
                    const SizedBox(width: 10),
                    Expanded(child: _ActionCard(icon: Icons.photo_filter_outlined, label: 'Photo', color: AppColors.violet, onTap: _editPhoto)),
                    const SizedBox(width: 10),
                    Expanded(child: _ActionCard(icon: Icons.dashboard_customize_outlined, label: 'Design', color: const Color(0xFF14B8A6), onTap: _newDesign)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('sample-photo'),
                  onPressed: _trySample,
                  child: const Text('No photo handy? Try a sample'),
                ),
              ),
            ),
            const _SectionTitle('Start from a template'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: designTemplates.length,
                  itemBuilder: (context, i) {
                    final t = designTemplates[i];
                    return _TemplateTile(template: t, onTap: () => _open(EditorScreen(document: t.build())));
                  },
                ),
              ),
            ),
            const _SectionTitle('Your projects'),
            FutureBuilder<List<ProjectEntry>>(
              future: _projects,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <ProjectEntry>[];
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 40),
                      child: Text('Projects save automatically and will show up here.', style: TextStyle(color: AppColors.muted)),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .95,
                    children: [
                      for (final e in items)
                        _ProjectTile(entry: e, onTap: () => _openEntry(e), onDelete: () => _confirmDelete(e)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatefulWidget {
  const _TemplateTile({required this.template, required this.onTap});
  final DesignTemplate template;
  final VoidCallback onTap;

  @override
  State<_TemplateTile> createState() => _TemplateTileState();
}

class _TemplateTileState extends State<_TemplateTile> {
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 118,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _doc.aspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(painter: _DocPainter(_doc)),
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

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.entry, required this.onTap, required this.onDelete});
  final ProjectEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: entry.thumbnail != null
                  ? Image.memory(entry.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true)
                  : const ColoredBox(color: AppColors.surfaceHigh, child: Icon(Icons.movie_outlined, color: AppColors.muted, size: 34)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Row(
                children: [
                  Expanded(child: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
