import 'package:flutter/material.dart';

import '../../app/art_image.dart';
import '../../app/logo.dart';
import '../../app/theme.dart';
import '../../canvas/document.dart';
import '../../canvas/layer.dart';
import '../../canvas/template_engine.dart';
import '../../core/artwork.dart';
import '../../core/color/filter_presets.dart';
import '../../core/media.dart';
import '../../core/media_picker.dart';
import '../../core/project_store.dart';
import '../editor/editor_screen.dart';
import '../settings/about_screen.dart';
import '../video/video_editor_screen.dart';
import '../video/video_project.dart';
import 'template_browser.dart';

/// The app's main screen: Home, Templates and Projects tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    MediaLibrary.cleanUp();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildLightTheme(),
      child: LayoutBuilder(
        builder: (context, box) {
          final pages = IndexedStack(
            index: _tab,
            children: [
              _HomeTab(onSeeProjects: () => setState(() => _tab = 2)),
              const TemplateBrowser(embedded: true),
              const _ProjectsTab(),
            ],
          );
          // Tablets, laptops and desktop browsers: navigation down the side.
          if (box.maxWidth >= 840) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    extended: box.maxWidth >= 1200,
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    leading: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: AppLogo(size: 40)),
                    labelType: box.maxWidth >= 1200 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Home')),
                      NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: Text('Templates')),
                      NavigationRailDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder_rounded), label: Text('Projects')),
                    ],
                  ),
                  const VerticalDivider(width: 1, color: LightColors.line),
                  Expanded(child: pages),
                ],
              ),
            );
          }
          return Scaffold(
            body: pages,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Templates'),
                NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder_rounded), label: 'Projects'),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Opens screens and creates projects. Shared by the tabs.
class _Actions {
  _Actions(this.context);
  final BuildContext context;

  Future<void> open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  static CanvasDocument photoDocument(String path, String name, int width, int height, {String filterId = 'original'}) {
    final base = CanvasLayer.image(path, width, height, width: 1)
      ..name = 'Photo'
      ..isBase = true
      ..locked = true;
    base.grade.filterId = filterId;
    return CanvasDocument(name: name, isPhoto: true, pixelWidth: width, pixelHeight: height, background: CanvasBackground(0xFF000000), layers: [base]);
  }

  Future<void> editPhoto() async {
    final file = await MediaPicker.image(onError: (m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))));
    if (file == null) return;
    final path = await MediaLibrary.import(file);
    final image = await ImageBank.instance.load(path);
    await open(EditorScreen(document: photoDocument(path, 'Photo edit', image.width, image.height)));
  }

  Future<void> openScene(ArtScene scene, {String filterId = 'original'}) async {
    final image = await ImageBank.instance.load(scene.path);
    if (!context.mounted) return;
    await open(EditorScreen(document: photoDocument(scene.path, scene.name, image.width, image.height, filterId: filterId)));
  }

  void newVideo() => open(VideoEditorScreen(project: VideoProject()));

  void browse(String title, TemplateQuery query) => open(TemplateBrowser(title: title, initial: query));

  void customSize() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .75),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Start a blank design',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LightColors.text),
                ),
              ),
              for (final f in templateFormats)
                ListTile(
                  leading: _SizeIcon(width: f.width, height: f.height),
                  title: Text(
                    f.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: LightColors.text),
                  ),
                  trailing: Text('${f.width} × ${f.height}', style: const TextStyle(color: LightColors.muted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheet);
                    open(
                      EditorScreen(
                        document: CanvasDocument(name: f.label, pixelWidth: f.width, pixelHeight: f.height),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void pickScene() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick a sample picture',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LightColors.text),
              ),
              const SizedBox(height: 4),
              const Text('Try every filter and tool on one of these.', style: TextStyle(color: LightColors.muted)),
              const SizedBox(height: 14),
              GridView.extent(
                maxCrossAxisExtent: 160,
                shrinkWrap: true,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final scene in artScenes)
                    _ArtCard(
                      scene: scene,
                      onTap: () {
                        Navigator.pop(sheet);
                        openScene(scene);
                      },
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            scene.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Template collections shown on Home, each a filter over the catalogue.
final _collections = <(String, TemplateQuery)>[
  ('Instagram posts', TemplateQuery(formats: {0, 1, 4})),
  ('Stories & reels', TemplateQuery(formats: {2, 3, 8, 19, 23, 24})),
  ('LinkedIn', TemplateQuery(formats: TemplateCatalog.formatsInGroup('LinkedIn'))),
  ('YouTube thumbnails', TemplateQuery(formats: {17})),
  ('Posters & flyers', TemplateQuery(formats: {35, 36, 37})),
  ('Invitations & cards', TemplateQuery(formats: {40, 41, 38})),
  ('Photo collages', const TemplateQuery(photos: 4)),
];

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onSeeProjects});
  final VoidCallback onSeeProjects;

  @override
  Widget build(BuildContext context) {
    final a = _Actions(context);
    final shortcuts = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.camera_alt_rounded,
        'Instagram',
        const Color(0xFFE1306C),
        () => a.browse('Instagram', TemplateQuery(formats: TemplateCatalog.formatsInGroup('Instagram'))),
      ),
      (Icons.videocam_rounded, 'Video', AppColors.coral, a.newVideo),
      (Icons.photo_filter_rounded, 'Photo', AppColors.violet, a.editPhoto),
      (Icons.work_rounded, 'LinkedIn', const Color(0xFF0A66C2), () => a.browse('LinkedIn', TemplateQuery(formats: TemplateCatalog.formatsInGroup('LinkedIn')))),
      (
        Icons.smart_display_rounded,
        'YouTube',
        const Color(0xFFFF0033),
        () => a.browse('YouTube', TemplateQuery(formats: TemplateCatalog.formatsInGroup('YouTube'))),
      ),
      (Icons.print_rounded, 'Print', const Color(0xFF0F9D8A), () => a.browse('Print', TemplateQuery(formats: TemplateCatalog.formatsInGroup('Print')))),
      (
        Icons.slideshow_rounded,
        'Slides',
        const Color(0xFFF59E0B),
        () => a.browse('Presentations', TemplateQuery(formats: TemplateCatalog.formatsInGroup('Presentation'))),
      ),
      (
        Icons.storefront_rounded,
        'Web & ads',
        const Color(0xFF6366F1),
        () => a.browse('Web & ads', TemplateQuery(formats: TemplateCatalog.formatsInGroup('Web'))),
      ),
      (Icons.add_rounded, 'Custom', LightColors.text, a.customSize),
    ];
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(onSearch: () => a.open(const TemplateBrowser(autofocus: true)), onAbout: () => a.open(const AboutScreen())),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
              children: [for (final (icon, label, color, onTap) in shortcuts) _Shortcut(icon: icon, label: label, color: color, onTap: onTap)],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    child: _ArtCard(
                      scene: artScenes[2],
                      onTap: a.newVideo,
                      child: const _CardLabel(icon: Icons.movie_creation_rounded, title: 'Edit a video', caption: 'Trim, filters, music, text'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ArtCard(
                      scene: artScenes[0],
                      onTap: a.editPhoto,
                      child: _CardLabel(icon: Icons.auto_fix_high_rounded, title: 'Edit a photo', caption: '${filterPresets.length - 1} filters & adjustments'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _Section(title: 'Try a look', action: 'Samples', onAction: a.pickScene),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 104,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _featuredLooks.length,
              itemBuilder: (context, i) {
                final (filterId, scene) = _featuredLooks[i];
                final preset = filterById(filterId);
                return _LookBubble(
                  scene: artScenes[scene],
                  name: preset.name,
                  matrix: preset.matrix,
                  onTap: () => a.openScene(artScenes[scene], filterId: filterId),
                );
              },
            ),
          ),
        ),
        for (final (title, query) in _collections) ...[
          _Section(title: title, action: 'See all', onAction: () => a.browse(title, query)),
          SliverToBoxAdapter(
            child: _CollectionRow(
              query: query,
              onOpen: (spec) => a.open(EditorScreen(document: spec.build())),
            ),
          ),
        ],
        _Section(title: 'Recent designs', action: 'All', onAction: onSeeProjects),
        const SliverToBoxAdapter(child: _RecentRow()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

const _featuredLooks = <(String, int)>[
  ('golden_hour', 0),
  ('teal_amber', 2),
  ('alpine', 1),
  ('vapor', 2),
  ('dune', 3),
  ('blush', 5),
  ('cyanotype', 4),
  ('silver', 1),
  ('neon', 2),
  ('stock_200', 0),
];

class _Header extends StatelessWidget {
  const _Header({required this.onSearch, required this.onAbout});
  final VoidCallback onSearch;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 12, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6D3CF5), Color(0xFFB13CF0), Color(0xFFFF5C8A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: const AppLogo(size: 34),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Canvo Edit',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.4),
                ),
              ),
              IconButton(
                tooltip: 'About Canvo Edit',
                icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
                onPressed: onAbout,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'What will you\ncreate today?',
            style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.8),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              elevation: 0,
              child: InkWell(
                key: const ValueKey('home-search'),
                borderRadius: BorderRadius.circular(18),
                onTap: onSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: LightColors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search ${formatCount(TemplateCatalog.total)} templates',
                          style: const TextStyle(color: LightColors.muted, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 74,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: LightColors.text),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightColors.text, letterSpacing: -.3),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action!,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.violet),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({required this.query, required this.onOpen});
  final TemplateQuery query;
  final ValueChanged<TemplateSpec> onOpen;

  @override
  Widget build(BuildContext context) {
    final results = TemplateCatalog.search(query);
    const height = 176.0;
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: results.length < 12 ? results.length : 12,
        itemBuilder: (context, i) {
          final spec = results[i];
          final ratio = (spec.formatInfo.width / spec.formatInfo.height).clamp(.5, 2.2);
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: height * ratio,
              child: Center(
                child: TemplateCard(spec: spec, showLabel: false, onTap: () => onOpen(spec)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentRow extends StatefulWidget {
  const _RecentRow();

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
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
    if (mounted) setState(() => _projects = ProjectStore.instance.list());
  }

  @override
  Widget build(BuildContext context) {
    final a = _Actions(context);
    return FutureBuilder<List<ProjectEntry>>(
      future: _projects,
      builder: (context, snap) {
        final items = snap.data ?? const <ProjectEntry>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: LightColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: LightColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.violet, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Your designs save automatically and show up here.', style: TextStyle(color: LightColors.muted)),
                  ),
                  GradientButton(key: const ValueKey('sample-photo'), label: 'Try one', compact: true, onPressed: a.pickScene),
                ],
              ),
            ),
          );
        }
        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(width: 120, child: _ProjectCard(entry: items[i], compact: true)),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectsTab extends StatefulWidget {
  const _ProjectsTab();

  @override
  State<_ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<_ProjectsTab> {
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
    if (mounted) setState(() => _projects = ProjectStore.instance.list());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Your projects')),
      body: FutureBuilder<List<ProjectEntry>>(
        future: _projects,
        builder: (context, snap) {
          final items = snap.data ?? const <ProjectEntry>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nothing here yet. Start from a template or edit a photo or video.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: LightColors.muted),
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: .82,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _ProjectCard(entry: items[i]),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.entry, this.compact = false});
  final ProjectEntry entry;
  final bool compact;

  Future<void> _openEntry(BuildContext context) async {
    final a = _Actions(context);
    switch (entry.type) {
      case ProjectType.video:
        await a.open(VideoEditorScreen(project: VideoProject.fromJson(entry.data)));
      case ProjectType.design:
      case ProjectType.photo:
        await a.open(EditorScreen(document: CanvasDocument.fromJson(entry.data)));
    }
  }

  Future<void> _duplicate() async {
    final data = Map<String, dynamic>.of(entry.data)..['id'] = newId();
    final name = '${entry.name} copy';
    data['name'] = name;
    await ProjectStore.instance.save(
      ProjectEntry(id: data['id'] as String, name: name, type: entry.type, updatedAt: DateTime.now(), data: data, thumbnail: entry.thumbnail),
    );
  }

  Future<void> _delete(BuildContext context) async {
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
    if (yes ?? false) {
      await ProjectStore.instance.delete(entry.id);
      await MediaLibrary.cleanUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (entry.type) {
      ProjectType.video => (Icons.videocam_rounded, 'Video'),
      ProjectType.photo => (Icons.photo_rounded, 'Photo'),
      ProjectType.design => (Icons.brush_rounded, 'Design'),
    };
    return Material(
      color: LightColors.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: () => _openEntry(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  entry.thumbnail != null ? Image.memory(entry.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true) : ArtImage(artScenes[2]),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, compact ? 6 : 2, 0, compact ? 6 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: LightColors.text),
                    ),
                  ),
                  if (!compact) ...[
                    IconButton(
                      tooltip: 'Duplicate',
                      icon: const Icon(Icons.copy_rounded, size: 16, color: LightColors.muted),
                      onPressed: _duplicate,
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: LightColors.muted),
                      onPressed: () => _delete(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtCard extends StatelessWidget {
  const _ArtCard({required this.scene, required this.onTap, required this.child});
  final ArtScene scene;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Color(0x332A1A5E), blurRadius: 18, offset: Offset(0, 8))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArtImage(scene),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC0B0618)],
                stops: [.35, 1],
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, child: child),
          ),
        ],
      ),
    ),
  );
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.icon, required this.title, required this.caption});
  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const Spacer(),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
        ),
      ],
    ),
  );
}

class _LookBubble extends StatelessWidget {
  const _LookBubble({required this.scene, required this.name, required this.matrix, required this.onTap});
  final ArtScene scene;
  final String name;
  final List<double> matrix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.ring),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: ClipOval(
                child: ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: ArtImage(scene)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 76,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LightColors.text),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SizeIcon extends StatelessWidget {
  const _SizeIcon({required this.width, required this.height});
  final int width;
  final int height;

  @override
  Widget build(BuildContext context) {
    final ratio = width / height;
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: Container(
          width: ratio >= 1 ? 28 : 28 * ratio,
          height: ratio >= 1 ? 28 / ratio : 28,
          decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}
