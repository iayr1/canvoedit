import 'package:canvo_edit/core/color/grade.dart';
import 'package:canvo_edit/features/shared/editor_chrome.dart';
import 'package:canvo_edit/features/video/video_controller.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('music cutting', () {
    VideoController controllerWith(AudioTrack track) => VideoController(
      VideoProject(
        clips: [VideoClip(path: 'art://neon-city', kind: ClipKind.image, sourceMs: 20000)],
        audio: [track],
      ),
    );

    test('cutting a track at the playhead leaves two parts that play the same sound', () {
      final track = AudioTrack(path: '/m.mp3', name: 'Song', sourceMs: 60000, startMs: 1000, inMs: 5000, durationMs: 10000, fadeInMs: 500, fadeOutMs: 800);
      final c = controllerWith(track);
      expect(c.splitAudioAt(track, 4000), isTrue);
      final [a, b] = c.project.audio;
      expect((a.startMs, a.inMs, a.durationMs, a.fadeInMs, a.fadeOutMs), (1000, 5000, 3000, 500, 0));
      expect((b.startMs, b.inMs, b.durationMs, b.fadeInMs, b.fadeOutMs), (4000, 8000, 7000, 0, 800));
      expect(b.id, isNot(a.id));
      expect(c.selectedAudio, b);
    });

    test('cuts outside the track are refused', () {
      final track = AudioTrack(path: '/m.mp3', name: 'Song', sourceMs: 60000, startMs: 1000, durationMs: 5000);
      final c = controllerWith(track);
      expect(c.splitAudioAt(track, 500), isFalse);
      expect(c.splitAudioAt(track, 5950), isFalse);
      expect(c.project.audio, hasLength(1));
    });

    test('trimming the start keeps the rest of the sound in place', () {
      final track = AudioTrack(path: '/m.mp3', name: 'Song', sourceMs: 60000, startMs: 2000, inMs: 1000, durationMs: 8000);
      final c = controllerWith(track);
      c.trimAudioStart(track, 1500);
      expect((track.startMs, track.inMs, track.durationMs), (3500, 2500, 6500));
      c.trimAudioStart(track, -10000);
      expect((track.startMs, track.inMs, track.durationMs), (1000, 0, 9000), reason: 'cannot reach before the song starts');
    });

    test('duplicating places the copy straight after', () {
      final track = AudioTrack(path: '/m.mp3', name: 'Song', sourceMs: 60000, startMs: 2000, durationMs: 3000);
      final c = controllerWith(track)..duplicateAudio(track);
      expect(c.project.audio.last.startMs, 5000);
    });
  });

  group('colour wheels', () {
    List<double> apply(Map<String, double> v, List<double> rgb) {
      final m = matrixFromValues(v);
      return [for (var r = 0; r < 3; r++) m[r * 5] * rgb[0] + m[r * 5 + 1] * rgb[1] + m[r * 5 + 2] * rgb[2] + m[r * 5 + 4]];
    }

    test('lift brightens shadows more than highlights', () {
      final dark = apply({'liftY': 1}, [0, 0, 0]), light = apply({'liftY': 1}, [255, 255, 255]);
      expect(dark[0], greaterThan(40));
      expect(light[0], closeTo(255, 1e-6));
    });

    test('gain scales highlights and leaves black alone', () {
      expect(apply({'gainY': 1}, [0, 0, 0])[0], 0);
      expect(apply({'gainY': -1}, [200, 200, 200])[0], closeTo(100, 1e-6));
    });

    test('offset tints every tone by the same amount', () {
      final a = apply({'offR': .5}, [10, 10, 10]), b = apply({'offR': .5}, [200, 200, 200]);
      expect(a[0] - 10, closeTo(b[0] - 200, 1e-6));
      expect(a[0], greaterThan(10));
    });
  });

  test('export names become safe file names', () {
    expect(fileSafeName('My trip: Goa / 2026!'), 'My_trip_Goa_2026');
    expect(fileSafeName('   '), 'Canvo_Edit');
  });
}
