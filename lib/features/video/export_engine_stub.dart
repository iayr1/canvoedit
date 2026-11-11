/// Browser builds have no FFmpeg, so video export is unavailable there.
class ExportEngine {
  static const bool isSupported = false;

  static Future<String?> run(List<String> args, {required int durationMs, required void Function(double progress) onProgress}) async =>
      'Video export needs the Android or iOS app.';

  static Future<void> cancel() async {}

  static Future<({int? durationMs, bool hasAudio})> probe(String path) async => (durationMs: null, hasAudio: false);

  static Future<String?> extractThumbnail(String path, int timeMs) async => null;
}
