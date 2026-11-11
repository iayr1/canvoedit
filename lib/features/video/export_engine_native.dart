import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';

import '../../core/media.dart';

/// Runs FFmpeg on the device for export, media probing and thumbnails.
class ExportEngine {
  static const bool isSupported = true;

  /// Returns null on success, or an error message. Cancelling is not an error.
  static Future<String?> run(List<String> args, {required int durationMs, required void Function(double progress) onProgress}) async {
    final done = Completer<String?>();
    final logTail = <String>[];
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code) || ReturnCode.isCancel(code)) {
          done.complete(null);
        } else {
          done.complete('FFmpeg failed (code ${code?.getValue()}):\n${logTail.join()}');
        }
      },
      (log) {
        logTail.add(log.getMessage());
        if (logTail.length > 30) logTail.removeAt(0);
      },
      (stats) {
        if (durationMs > 0) {
          onProgress((stats.getTime() / durationMs).clamp(0.0, 1.0).toDouble());
        }
      },
    );
    return done.future;
  }

  static Future<void> cancel() => FFmpegKit.cancel();

  static Future<({int? durationMs, bool hasAudio})> probe(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      if (info == null) return (durationMs: null, hasAudio: false);
      final seconds = double.tryParse(info.getDuration() ?? '');
      final hasAudio = info.getStreams().any((s) => s.getType() == 'audio');
      return (durationMs: seconds == null ? null : (seconds * 1000).round(), hasAudio: hasAudio);
    } catch (e) {
      debugPrint('Probe failed for $path: $e');
      return (durationMs: null, hasAudio: false);
    }
  }

  static Future<String?> extractThumbnail(String path, int timeMs) async {
    final dir = await MediaLibrary.workDir('thumbnails');
    final out = '${dir.path}/${newId()}.jpg';
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-ss',
      (timeMs / 1000).toStringAsFixed(3),
      '-i',
      path,
      '-frames:v',
      '1',
      '-vf',
      'scale=-2:120',
      out,
    ]);
    return ReturnCode.isSuccess(await session.getReturnCode()) ? out : null;
  }
}
