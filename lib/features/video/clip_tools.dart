import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/media.dart';
import 'export_engine.dart';
import 'ffmpeg_graph.dart';
import 'video_project.dart';

class ClipToolResult {
  const ClipToolResult(this.path, this.durationMs);
  final String path;
  final int durationMs;
}

String _s(int ms) => (ms / 1000).toStringAsFixed(3);

List<String> _trimmedInput(VideoClip clip) => ['-y', '-ss', _s(clip.inMs), '-t', _s(clip.outMs - clip.inMs), '-i', clip.path];

const _audioOut = ['-c:a', 'aac', '-b:a', '192k'];

/// Video is reversed one short chunk at a time, because FFmpeg's reverse filter
/// holds every frame it is given in memory: a minute of 1080p would need about
/// 5 GB. A chunk of 4K stays near 250 MB.
const reverseChunkMs = 1000;

/// Start times, in the source file, of the chunks covering a clip's trim.
List<int> reverseChunkStarts(VideoClip clip) => [for (var t = clip.inMs; t < clip.outMs; t += reverseChunkMs) t];

List<String> reverseChunkArgs(VideoClip clip, int startMs, String out) => [
  '-y',
  '-ss',
  _s(startMs),
  '-t',
  _s((clip.outMs - startMs).clamp(0, reverseChunkMs)),
  '-i',
  clip.path,
  '-vf',
  'reverse',
  '-an',
  ...VideoEncoder.x264.args,
  '-pix_fmt',
  'yuv420p',
  out,
];

/// Sound is small enough to reverse whole, which avoids clicks at chunk joins.
List<String> reverseAudioArgs(VideoClip clip, String out) => [..._trimmedInput(clip), '-vn', '-af', 'areverse', ..._audioOut, out];

/// Joins the reversed chunks, listed last-first in [listFile], with the
/// reversed sound, without re-encoding either.
List<String> reverseJoinArgs(String listFile, String? audio, String out) => [
  '-y',
  '-f',
  'concat',
  '-safe',
  '0',
  '-i',
  listFile,
  if (audio != null) ...['-i', audio, '-map', '0:v:0', '-map', '1:a:0'],
  '-c',
  'copy',
  out,
];

/// Keeps the whole file and copies its video untouched, so trim points still
/// apply and the picture loses no quality.
List<String> denoiseArgs(VideoClip clip, String out) => [
  '-y',
  '-i',
  clip.path,
  '-map',
  '0:v:0',
  '-map',
  '0:a:0',
  '-c:v',
  'copy',
  '-af',
  'afftdn=nf=-25',
  ..._audioOut,
  out,
];

/// The sound is cut and sped up to match the clip, so it stays in sync on its
/// own track.
List<String> extractAudioArgs(VideoClip clip, String out) {
  final tempo = atempoChain(clip.speed);
  return [
    ..._trimmedInput(clip),
    '-vn',
    if (tempo.isNotEmpty) ...['-af', tempo],
    ..._audioOut,
    out,
  ];
}

/// One-off clip processing that writes a new media file. The result behaves like
/// any other clip, so previews and exports need no special handling.
class ClipTools {
  /// Reversing buffers every frame in memory, so length has to be limited.
  static const maxReverseMs = 60000;

  @visibleForTesting
  static Directory? directoryOverride;

  static Future<Directory> outputDir() async {
    if (directoryOverride != null) return directoryOverride!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/media');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<ClipToolResult> _finish(String out, int fallbackMs) async {
    final probe = await ExportEngine.probe(out);
    return ClipToolResult(out, probe.durationMs ?? fallbackMs);
  }

  static Future<void> _run(List<String> args, int durationMs, ValueChanged<double> onProgress) async {
    final error = await ExportEngine.run(args, durationMs: durationMs, onProgress: onProgress);
    if (error != null) throw StateError(error);
  }

  static Future<ClipToolResult> reverse(VideoClip clip, ValueChanged<double> onProgress) async {
    final out = '${(await outputDir()).path}/${newId()}.mp4';
    final length = clip.outMs - clip.inMs;
    final work = await MediaLibrary.workDir('reverse-${newId()}');
    try {
      final starts = reverseChunkStarts(clip);
      final parts = <String>[];
      for (var i = 0; i < starts.length; i++) {
        final part = '${work.path}/part-$i.mp4';
        await _run(reverseChunkArgs(clip, starts[i], part), reverseChunkMs, (v) => onProgress((i + v) / (starts.length + 1)));
        parts.add(part);
      }
      final list = File('${work.path}/list.txt');
      await list.writeAsString(parts.reversed.map((p) => "file '$p'").join('\n'));
      String? audio;
      if (clip.hasAudio) {
        audio = '${work.path}/audio.m4a';
        await _run(reverseAudioArgs(clip, audio), length, (_) {});
      }
      await _run(reverseJoinArgs(list.path, audio, out), length, (v) => onProgress((starts.length + v) / (starts.length + 1)));
    } finally {
      await work.delete(recursive: true);
    }
    return _finish(out, length);
  }

  static Future<ClipToolResult> denoise(VideoClip clip, ValueChanged<double> onProgress) async {
    final out = '${(await outputDir()).path}/${newId()}.mp4';
    await _run(denoiseArgs(clip, out), clip.sourceMs, onProgress);
    return _finish(out, clip.sourceMs);
  }

  static Future<ClipToolResult> extractAudio(VideoClip clip, ValueChanged<double> onProgress) async {
    final out = '${(await outputDir()).path}/${newId()}.m4a';
    await _run(extractAudioArgs(clip, out), clip.durationMs, onProgress);
    return _finish(out, clip.durationMs);
  }
}
