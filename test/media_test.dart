import 'dart:async';
import 'dart:io';

import 'package:canvo_edit/core/media.dart';
import 'package:canvo_edit/core/media_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root, media, projects, cache;
  final old = DateTime.now().add(const Duration(days: 1));

  setUp(() async {
    root = await Directory.systemTemp.createTemp('canvo-media');
    media = await Directory('${root.path}/media').create();
    projects = await Directory('${root.path}/projects').create();
    cache = await Directory('${root.path}/cache').create();
  });

  tearDown(() => root.delete(recursive: true));

  Future<File> write(Directory dir, String name, String content) => File('${dir.path}/$name').writeAsString(content);

  group('storing picks', () {
    test('a new file is copied under a new name', () async {
      final src = await write(root, 'clip.mp4', 'video');
      final path = await MediaLibrary.store(src, 'clip.mp4', media);
      expect(path, endsWith('.mp4'));
      expect(await File(path).readAsString(), 'video');
      expect(await src.exists(), isTrue, reason: 'files outside the cache are not ours to delete');
    });

    test('importing identical content reuses the stored file', () async {
      final first = await MediaLibrary.store(await write(root, 'a.mp4', 'same'), 'a.mp4', media);
      final second = await MediaLibrary.store(await write(root, 'b.mp4', 'same'), 'b.mp4', media);
      expect(second.replaceAll(r'\', '/'), first.replaceAll(r'\', '/'));
      expect(await media.list().length, 1);
    });

    test('same size with different content is kept separate', () async {
      final first = await MediaLibrary.store(await write(root, 'a.mp4', 'aaaa'), 'a.mp4', media);
      final second = await MediaLibrary.store(await write(root, 'b.mp4', 'aaab'), 'b.mp4', media);
      expect(second, isNot(first));
      expect(await File(second).readAsString(), 'aaab');
    });

    test('files larger than one read chunk are compared to the end', () async {
      final base = List.filled((1 << 20) + 10, 7);
      final changed = [...base]..[base.length - 1] = 8;
      final a = File('${root.path}/a.bin')..writeAsBytesSync(base);
      final b = File('${root.path}/b.bin')..writeAsBytesSync(changed);
      final first = await MediaLibrary.store(a, 'a.bin', media);
      expect(await MediaLibrary.store(b, 'b.bin', media), isNot(first));
    });

    test('the picker\'s cached copy is removed once stored', () async {
      final src = await write(cache, 'pick.mp4', 'video');
      final path = await MediaLibrary.store(src, 'pick.mp4', media, cache: cache);
      expect(await src.exists(), isFalse);
      expect(await File(path).exists(), isTrue);
    });
  });

  group('cleaning unused media', () {
    test('removes unused files and keeps those a project mentions', () async {
      await write(media, 'used.mp4', 'x');
      await write(media, 'orphan.mp4', 'x');
      await write(projects, 'p.json', '{"path":"/data/media/used.mp4"}');
      expect(await MediaLibrary.deleteUnusedMedia(media, projects, now: old), 1);
      expect(await File('${media.path}/used.mp4').exists(), isTrue);
      expect(await File('${media.path}/orphan.mp4').exists(), isFalse);
    });

    test('a project too damaged to parse still protects its files', () async {
      await write(media, 'used.mp4', 'x');
      await write(projects, 'broken.json', '{"path":"/data/media/used.mp4", oops');
      expect(await MediaLibrary.deleteUnusedMedia(media, projects, now: old), 0);
      expect(await File('${media.path}/used.mp4').exists(), isTrue);
    });

    test('recent files survive, as an editor may not have saved them yet', () async {
      await write(media, 'new.mp4', 'x');
      expect(await MediaLibrary.deleteUnusedMedia(media, projects), 0);
      expect(await File('${media.path}/new.mp4').exists(), isTrue);
    });

    test('two projects sharing a file keep it until neither uses it', () async {
      await write(media, 'shared.mp4', 'x');
      final a = await write(projects, 'a.json', 'shared.mp4');
      final b = await write(projects, 'b.json', 'shared.mp4');
      await a.delete();
      expect(await MediaLibrary.deleteUnusedMedia(media, projects, now: old), 0);
      await b.delete();
      expect(await MediaLibrary.deleteUnusedMedia(media, projects, now: old), 1);
    });

    test('a missing media folder is not an error', () async {
      await media.delete(recursive: true);
      expect(await MediaLibrary.deleteUnusedMedia(media, projects), 0);
    });
  });

  group('picker guard', () {
    void noError(String m) => fail('unexpected error: $m');

    test('a second request while one is open is ignored', () async {
      final gate = Completer<String>();
      var opened = 0;
      Future<String?> open() {
        opened++;
        return gate.future;
      }

      final first = MediaPicker.guard(open, onError: noError);
      expect(await MediaPicker.guard(open, onError: noError), isNull);
      gate.complete('picked');
      expect(await first, 'picked');
      expect(opened, 1);
    });

    test('the picker can be opened again afterwards, even after a failure', () async {
      final errors = <String>[];
      await MediaPicker.guard<String>(
        () => throw PlatformException(code: 'camera_access_denied', message: 'Denied'),
        onError: errors.add,
      );
      expect(errors, ['Denied']);
      expect(await MediaPicker.guard(() async => 'ok', onError: noError), 'ok');
    });

    test('an already-open error from Android is not shown to the user', () async {
      final result = await MediaPicker.guard<String>(() => throw PlatformException(code: 'already_active'), onError: noError);
      expect(result, isNull);
    });
  });
}
