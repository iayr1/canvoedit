import 'package:canvo_edit/app/theme.dart';
import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/features/editor/editor_screen.dart';
import 'package:canvo_edit/features/home/home_screen.dart';
import 'package:canvo_edit/features/video/video_editor_screen.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screen sizes in logical pixels: phones both ways, tablets both ways,
/// a laptop and a desktop browser.
const sizes = {
  'phone portrait': Size(360, 780),
  'phone landscape': Size(780, 360),
  'tablet portrait': Size(800, 1280),
  'tablet landscape': Size(1280, 800),
  'laptop': Size(1440, 900),
  'desktop': Size(1920, 1080),
};

void main() {
  setUp(() => SceneRenderer.useGoogleFonts = false);

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('home fits on $name', (tester) async {
      await setSize(tester, size);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      for (final tab in ['Templates', 'Projects', 'Home']) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('video editor fits on $name with every panel', (tester) async {
      await setSize(tester, size);
      final project = VideoProject(
        clips: [
          for (final id in ['sunset-coast', 'neon-city']) VideoClip(path: 'art://$id', kind: ClipKind.image, sourceMs: 4000),
        ],
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
      final first = project.clips.first;
      await tester.tapAt(tester.getTopLeft(find.byKey(ValueKey('clip-${first.id}'))) + const Offset(20, 20));
      await tester.pump();
      for (final tool in ['Transition', 'Filters', 'Adjust', 'Color', 'Volume']) {
        final f = find.text(tool);
        if (f.evaluate().isEmpty) continue;
        await tester.ensureVisible(f.last);
        await tester.pump();
        await tester.tap(f.last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }
      // Back to the main tools, where Add media and Music live.
      // Wide layouts show an open panel in place of the tools; close it first.
      final closePanel = find.byKey(const ValueKey('close-panel'));
      if (closePanel.evaluate().isNotEmpty) {
        await tester.tap(closePanel);
        await tester.pump();
      }
      final allTools = find.byKey(const ValueKey('all-tools'));
      if (allTools.evaluate().isEmpty) {
        // The tool strip (or side grid) scrolled; go back to its start.
        final strip = find.ancestor(of: find.text('Transition', skipOffstage: false).last, matching: find.byType(Scrollable)).first;
        await tester.drag(strip, const Offset(800, 800));
        await tester.pumpAndSettle();
      }
      expect(allTools, findsOneWidget, reason: 'a clip should still be selected, showing All tools');
      await tester.tap(allTools);
      await tester.pump();
      expect(find.text('Add media', skipOffstage: false), findsOneWidget);
      expect(find.text('Music', skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('timeline-add')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('photo editor fits on $name with every panel', (tester) async {
      await setSize(tester, size);
      final doc = CanvasDocument(name: 'Test', pixelWidth: 1080, pixelHeight: 1350)..layers.add(CanvasLayer.frame());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: EditorScreen(document: doc),
        ),
      );
      await tester.pump();
      for (final tool in ['Photos', 'Stickers', 'Shapes', 'Background', 'Draw', 'Layers', 'Resize']) {
        final f = find.text(tool);
        if (f.evaluate().isEmpty) continue;
        await tester.ensureVisible(f.last);
        await tester.pump();
        await tester.tap(f.last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
