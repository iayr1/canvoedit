import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum ProjectType { design, photo, video }

class ProjectEntry {
  ProjectEntry({required this.id, required this.name, required this.type, required this.updatedAt, required this.data, this.thumbnail});

  final String id;
  final String name;
  final ProjectType type;
  final DateTime updatedAt;
  final Map<String, dynamic> data;
  final Uint8List? thumbnail;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type.name, 'updatedAt': updatedAt.toIso8601String(), 'data': data};

  factory ProjectEntry.fromJson(Map<String, dynamic> j, Uint8List? thumbnail) => ProjectEntry(
    id: j['id'] as String,
    name: j['name'] as String,
    type: ProjectType.values.byName(j['type'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    data: (j['data'] as Map).cast<String, dynamic>(),
    thumbnail: thumbnail,
  );
}

/// Saves projects as JSON with a PNG thumbnail in app storage. On web the store
/// lasts only for the session, since the browser build is a UI preview.
class ProjectStore {
  ProjectStore._();
  static final ProjectStore instance = ProjectStore._();

  final Map<String, ProjectEntry> _memory = {};
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/projects');
    await dir.create(recursive: true);
    return dir;
  }

  Future<List<ProjectEntry>> list() async {
    final entries = <ProjectEntry>[];
    if (kIsWeb) {
      entries.addAll(_memory.values);
    } else {
      final dir = await _dir();
      await for (final item in dir.list()) {
        if (item is! File || !item.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await item.readAsString()) as Map<String, dynamic>;
          final thumb = File(item.path.replaceAll('.json', '.png'));
          entries.add(ProjectEntry.fromJson(json, await thumb.exists() ? await thumb.readAsBytes() : null));
        } on FormatException catch (e) {
          debugPrint('Skipping unreadable project ${item.path}: $e');
        }
      }
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<void> save(ProjectEntry entry) async {
    if (kIsWeb) {
      _memory[entry.id] = entry;
    } else {
      final dir = await _dir();
      await File('${dir.path}/${entry.id}.json').writeAsString(jsonEncode(entry.toJson()));
      if (entry.thumbnail != null) {
        await File('${dir.path}/${entry.id}.png').writeAsBytes(entry.thumbnail!);
      }
    }
    revision.value++;
  }

  Future<void> delete(String id) async {
    if (kIsWeb) {
      _memory.remove(id);
    } else {
      final dir = await _dir();
      for (final ext in ['json', 'png']) {
        final file = File('${dir.path}/$id.$ext');
        if (await file.exists()) await file.delete();
      }
    }
    revision.value++;
  }
}
