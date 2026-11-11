import 'package:canvo_edit/app/theme.dart';
import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/core/artwork.dart';
import 'package:canvo_edit/features/editor/editor_screen.dart';
import 'package:canvo_edit/features/video/video_editor_screen.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(theme: buildTheme(), home: child);

void main() {
  setUp(() => SceneRenderer.useGoogleFonts = false);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('design editor adds a sticker and undoes it', (tester) async {
    await phone(tester);
    final doc = CanvasDocument(name: 'Test', pixelWidth: 1080, pixelHeight: 1080);
    await tester.pumpWidget(_app(EditorScreen(document: doc)));
    await tester.pump();

    await tester.ensureVisible(find.text('Stickers'));
    await tester.pump();
    await tester.tap(find.text('Stickers'));
    await tester.pump();
    await tester.tap(find.text('🔥'));
    await tester.pump();
    expect(doc.layers.single.kind, LayerKind.sticker);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(find.byKey(const ValueKey('export')), findsOneWidget);
  });

  testWidgets('tapping a photo in the tray fills the empty frame', (tester) async {
    await phone(tester);
    final frame = CanvasLayer.frame(width: .6, aspect: 1);
    final doc = CanvasDocument(name: 'Frames', pixelWidth: 1080, pixelHeight: 1080, layers: [frame]);
    await tester.pumpWidget(_app(EditorScreen(document: doc)));
    await tester.pump();
    expect(find.text('Gallery'), findsOneWidget, reason: 'templates with frames open on the Photos tray');
    final thumbs = find.descendant(of: find.byType(LongPressDraggable<String>), matching: find.byType(GestureDetector));
    await tester.tap(thumbs.first);
    await tester.pump();
    expect(frame.path, artScenes.first.path);
  });

  testWidgets('video editor opens empty, on a phone-sized screen, without overflow', (tester) async {
    await phone(tester);
    await tester.pumpWidget(_app(VideoEditorScreen(project: VideoProject())));
    await tester.pump();
    expect(find.text('Add videos or photos'), findsOneWidget);
    expect(find.text('Add media'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  VideoProject longProject() => VideoProject(
    clips: [
      for (final id in ['sunset-coast', 'neon-city']) VideoClip(path: 'art://$id', kind: ClipKind.image, sourceMs: 30 * 60 * 1000),
    ],
  );

  testWidgets('timeline zooms out to fit an hour-long video and back in', (tester) async {
    await phone(tester);
    final project = longProject();
    await tester.pumpWidget(_app(VideoEditorScreen(project: project)));
    await tester.pump();
    String step() => tester.widget<Text>(find.byKey(const ValueKey('timeline-step'))).data!;
    expect(step(), '1s');

    await tester.tap(find.byKey(const ValueKey('timeline-fit')));
    await tester.pump();
    expect(step(), endsWith('m'), reason: 'an hour on one screen labels minutes');

    for (var i = 0; i < 26; i++) {
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
    }
    expect(step(), '0.1s');
    expect(tester.takeException(), isNull);
  });

  testWidgets('video editor applies a library transition, effect, word and sticker', (tester) async {
    await phone(tester);
    final project = longProject();
    await tester.pumpWidget(_app(VideoEditorScreen(project: project)));
    await tester.pump();
    // Painted scenes are not files, so a "missing media" note shows first.
    await tester.pump();
    ScaffoldMessenger.of(tester.element(find.byType(VideoEditorScreen))).removeCurrentSnackBar();
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    final first = project.clips.first;

    await tester.tapAt(tester.getTopLeft(find.byKey(ValueKey('clip-${first.id}'))) + const Offset(20, 20));
    await tester.pump();
    await tester.tap(find.text('Transition'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('browse-transitions')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'spiral');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('transition-spiral-1-in-s')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(first.transition, TransitionType.pattern);
    expect(first.transitionPattern, 'spiral-1-in-s');

    await tester.tap(find.text('Effects'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('effect-zin1.none.none')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(first.effect, 'zin1.none.none');

    // Deselect the clip to reach the add tools.
    await tester.tapAt(tester.getTopLeft(find.byKey(ValueKey('clip-${first.id}'))) + const Offset(20, 20));
    await tester.pump();
    await tester.ensureVisible(find.text('Words'));
    await tester.pump();
    await tester.tap(find.text('Words'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('word-0')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(project.overlays.single.kind, LayerKind.text);

    // The new words are selected, so their tools show: restyle them.
    final word = project.overlays.single;
    final before = word.toJson();
    await tester.tap(find.text('Looks'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('word-5')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(word.text, before['text'], reason: 'restyling keeps the words');
    expect(word.toJson(), isNot(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('video editor adds a sticker from the library', (tester) async {
    await phone(tester);
    final project = VideoProject();
    await tester.pumpWidget(_app(VideoEditorScreen(project: project)));
    await tester.pump();
    await tester.ensureVisible(find.text('Stickers'));
    await tester.pump();
    await tester.tap(find.text('Stickers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('stickers'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('sticker-0')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(project.overlays.single.kind, LayerKind.sticker);
    expect(tester.takeException(), isNull);
  });
}
