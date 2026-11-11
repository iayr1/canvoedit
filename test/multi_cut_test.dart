import 'package:canvo_edit/app/theme.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/features/video/video_editor_screen.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => SceneRenderer.useGoogleFonts = false);

  Future<VideoProject> open(WidgetTester tester, int clips) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const scenes = ['sunset-coast', 'neon-city', 'alpine-lake', 'desert-dunes'];
    final project = VideoProject(
      clips: [for (var i = 0; i < clips; i++) VideoClip(path: 'art://${scenes[i]}', kind: ClipKind.image, sourceMs: 4000)],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: VideoEditorScreen(project: project),
      ),
    );
    await tester.pump();
    ScaffoldMessenger.of(tester.element(find.byType(VideoEditorScreen))).removeCurrentSnackBar();
    await tester.pump();
    // Fit the timeline so every cut marker is on screen.
    await tester.tap(find.byKey(const ValueKey('timeline-fit')));
    await tester.pump();
    return project;
  }

  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> pick(WidgetTester tester, Finder tile) async {
    await tester.tap(tile);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('each cut marker opens transitions for that cut', (tester) async {
    final project = await open(tester, 3);
    await tester.tap(find.byKey(const ValueKey('cut-0')));
    await settleSheet(tester);
    await pick(tester, find.byKey(const ValueKey('transition-crossfade')));
    await tester.tap(find.byKey(const ValueKey('cut-1')));
    await settleSheet(tester);
    await pick(tester, find.byKey(const ValueKey('transition-slideLeft')));
    expect(project.clips[0].transition, TransitionType.crossfade);
    expect(project.clips[1].transition, TransitionType.slideLeft);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a transition and an effect can go on every cut and clip at once', (tester) async {
    final project = await open(tester, 4);
    await tester.tap(find.byKey(const ValueKey('cut-1')));
    await settleSheet(tester);
    await tester.tap(find.byKey(const ValueKey('apply-all')));
    await tester.pump();
    await pick(tester, find.byKey(const ValueKey('transition-fadeBlack')));
    expect([for (final c in project.clips) c.transition], [TransitionType.fadeBlack, TransitionType.fadeBlack, TransitionType.fadeBlack, TransitionType.none]);

    ScaffoldMessenger.of(tester.element(find.byType(VideoEditorScreen))).removeCurrentSnackBar();
    await tester.pump();
    await tester.tap(find.text('Effects').first);
    await settleSheet(tester);
    await tester.tap(find.text('Whole video'));
    await tester.pump();
    await pick(tester, find.byKey(const ValueKey('effect-zin1.none.none')));
    expect(project.clips.every((c) => c.effect == 'zin1.none.none'), isTrue);
  });

  testWidgets('a transition goes at the playhead without splitting first', (tester) async {
    final project = await open(tester, 1);
    final controllerProject = project;
    // Nothing selected: the main tool bar's Transition works at the playhead.
    final editor = tester.state(find.byType(VideoEditorScreen)) as dynamic;
    editor.debugSeek(1500);
    await tester.pump();
    await tester.tap(find.text('Transition'));
    await settleSheet(tester);
    await pick(tester, find.byKey(const ValueKey('transition-crossfade')));
    expect(controllerProject.clips, hasLength(2), reason: 'cut made automatically at the playhead');
    expect(controllerProject.clips.first.transition, TransitionType.crossfade);
  });

  testWidgets('an effect covers a few seconds from the playhead', (tester) async {
    final project = await open(tester, 1);
    final editor = tester.state(find.byType(VideoEditorScreen)) as dynamic;
    editor.debugSeek(1000);
    await tester.pump();
    await tester.tap(find.text('Effects'));
    await settleSheet(tester);
    await tester.tap(find.text('2 s'));
    await tester.pump();
    await pick(tester, find.byKey(const ValueKey('effect-zin1.none.none')));
    expect([for (final c in project.clips) c.durationMs], [1000, 2000, 1000]);
    expect([for (final c in project.clips) c.effect], [null, 'zin1.none.none', null]);
    expect(find.byKey(ValueKey('effect-badge-${project.clips[1].id}')), findsOneWidget);
  });
}
