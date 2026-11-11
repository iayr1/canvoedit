import 'dart:ui' as ui;

import 'package:canvo_edit/core/artwork.dart';
import 'package:canvo_edit/core/color/filter_presets.dart';
import 'package:canvo_edit/core/media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every scene has a unique id and resolves at both sizes', () {
    expect(artScenes.map((s) => s.id).toSet().length, artScenes.length);
    for (final s in artScenes) {
      expect(artworkFor(s.path)!.scene, s);
      expect(artworkFor(s.thumbPath)!.width, lessThan(artworkFor(s.path)!.width));
    }
    expect(artworkFor('art://missing'), isNull);
    expect(artworkFor('/data/media/clip.mp4'), isNull);
  });

  test('projects saved with the old sample path still find their picture', () {
    expect(artworkFor(legacySamplePath)!.scene, artScenes.first);
  });

  testWidgets('every scene paints without errors and is not blank', (tester) async {
    await tester.runAsync(() async {
      for (final s in artScenes) {
        final image = await ImageBank.instance.load(s.thumbPath);
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final colours = <int>{};
        for (var i = 0; i < data.lengthInBytes; i += 4 * 997) {
          colours.add(data.getUint32(i));
        }
        expect(colours.length, greaterThan(20), reason: s.name);
      }
    });
  });

  test('looks featured on the home screen are real filters', () {
    for (final id in ['golden_hour', 'teal_amber', 'alpine', 'vapor', 'dune', 'blush', 'cyanotype', 'silver', 'neon', 'stock_200']) {
      expect(filterById(id).id, id);
    }
  });
}
