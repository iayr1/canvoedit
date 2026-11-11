import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The top bar shared by the photo, design and video editors: back, the
/// project's name (tap to rename), undo and redo, and export.
class EditorTopBar extends StatelessWidget {
  const EditorTopBar({
    super.key,
    required this.kind,
    required this.name,
    required this.onRename,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onExport,
    this.detail,
  });

  /// "Video", "Photo" or "Design".
  final String kind;
  final String name;

  /// Extra words after the kind, such as the video's shape.
  final String? detail;
  final VoidCallback onRename;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onExport;

  Widget _round(IconData icon, String tooltip, VoidCallback? onTap, {Key? key, bool filled = true, double size = 38}) => Tooltip(
    message: tooltip,
    child: Material(
      key: key,
      color: filled ? Colors.white.withValues(alpha: onTap == null ? .03 : .08) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: 19, color: onTap == null ? Colors.white24 : Colors.white),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: .06))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          children: [
            _round(Icons.arrow_back_ios_new_rounded, 'Back', () => Navigator.of(context).maybePop()),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                key: const ValueKey('project-name'),
                borderRadius: BorderRadius.circular(12),
                onTap: onRename,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(gradient: AppGradients.brand, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              detail == null ? kind.toUpperCase() : '${kind.toUpperCase()}  ·  $detail',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w700, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: -.2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_rounded, size: 13, color: AppColors.muted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _round(Icons.undo_rounded, 'Undo', canUndo ? onUndo : null, filled: false, size: 32),
            _round(Icons.redo_rounded, 'Redo', canRedo ? onRedo : null, filled: false, size: 32),
            const SizedBox(width: 6),
            GradientButton(key: const ValueKey('export'), label: 'Save', icon: Icons.file_download_outlined, compact: true, onPressed: onExport),
          ],
        ),
      ),
    );
  }
}

/// True when an editor has room to put its tools beside the picture: landscape
/// phones, tablets, laptops and desktop browsers.
bool useWideEditor(Size size) => size.width >= 1000 || (size.width >= 640 && size.width > size.height * 1.15);

/// The editor's tools: a scrolling strip along the bottom, or in wide layouts
/// a grid down the side.
class ToolDock extends StatelessWidget {
  const ToolDock({super.key, required this.tools, this.vertical = false});
  final List<Widget> tools;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (!vertical) {
      return Container(
        height: 74,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6), children: tools),
      );
    }
    return GridView.extent(maxCrossAxisExtent: 80, childAspectRatio: 1.1, padding: const EdgeInsets.all(6), children: tools);
  }
}

/// The side column of a wide editor: an optional panel above the tool grid.
class EditorSidePanel extends StatelessWidget {
  const EditorSidePanel({super.key, required this.tools, this.panel, this.header, this.panelTitle, this.onClosePanel});
  final Widget tools;
  final Widget? panel;
  final Widget? header;

  /// Name of the open panel, shown beside the arrow back to the tools.
  final String? panelTitle;
  final VoidCallback? onClosePanel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line.withValues(alpha: .6)),
      ),
      clipBehavior: Clip.antiAlias,
      // Panels with lists draw their ink on this Material.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            ?header,
            // An open panel takes the whole column, with an arrow back to the
            // tools, so short landscape screens never squeeze either.
            if (panel != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('close-panel'),
                      tooltip: 'Back to tools',
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      onPressed: onClosePanel,
                    ),
                    Expanded(
                      child: Text(
                        panelTitle ?? 'Tools',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: SingleChildScrollView(child: panel)),
            ] else
              Expanded(child: tools),
          ],
        ),
      ),
    );
  }
}

/// Asks for a name. Returns the trimmed name, or null if cancelled or empty.
Future<String?> showNameDialog(BuildContext context, {required String title, required String initial, String hint = 'Name'}) async {
  final field = TextEditingController(text: initial)..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: NameField(controller: field, hint: hint, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        GradientButton(label: 'Save', compact: true, onPressed: () => Navigator.pop(context, field.text)),
      ],
    ),
  );
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// A filled text field for names, used when naming projects and exports.
class NameField extends StatelessWidget {
  const NameField({super.key, required this.controller, this.hint = 'Name', this.autofocus = false, this.onSubmitted, this.onChanged});
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('name-field'),
    controller: controller,
    autofocus: autofocus,
    maxLength: 60,
    textCapitalization: TextCapitalization.sentences,
    onSubmitted: onSubmitted,
    onChanged: onChanged,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      hintText: hint,
      counterText: '',
      prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .07),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
      ),
    ),
  );
}

/// A file-safe version of a name, for exported files.
String fileSafeName(String name) {
  final safe = name.trim().replaceAll(RegExp(r'[^\w\- ]+'), '').replaceAll(RegExp(r'\s+'), '_');
  return safe.isEmpty ? 'Canvo_Edit' : safe;
}
