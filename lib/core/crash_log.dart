import 'dart:io' show File, FileMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps a small on-device log of unexpected errors. Nothing leaves the phone
/// unless the user chooses to share it from the About screen.
class CrashLog {
  static const _maxBytes = 64 * 1024;

  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      record(details.exception, details.stack);
    };
    if (kReleaseMode) ErrorWidget.builder = (_) => const _FriendlyError();
  }

  static Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/crash.log');
  }

  static Future<void> record(Object error, StackTrace? stack) async {
    debugPrint('Unexpected error: $error');
    if (kIsWeb) return;
    try {
      final file = await _file();
      if (await file.exists() && await file.length() > _maxBytes) await file.delete();
      await file.writeAsString('${DateTime.now().toIso8601String()} $error\n$stack\n\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('Could not write the crash log: $e');
    }
  }

  static Future<String?> path() async {
    if (kIsWeb) return null;
    final file = await _file();
    return await file.exists() ? file.path : null;
  }
}

/// Replaces Flutter's error box in release builds when one screen fails to draw.
class _FriendlyError extends StatelessWidget {
  const _FriendlyError();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF0E0F13),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Something went wrong here. Your work is saved. Go back and try again.',
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: Colors.white70, fontSize: 14, decoration: TextDecoration.none),
        ),
      ),
    ),
  );
}
