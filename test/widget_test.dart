import 'package:canvo_edit/app/theme.dart';
import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
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

    await tester.tap(find.text('Stickers'));
    await tester.pump();
    await tester.tap(find.text('🔥'));
    await tester.pump();
    expect(doc.layers.single.kind, LayerKind.sticker);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('video editor opens empty, on a phone-sized screen, without overflow', (tester) async {
    await phone(tester);
    await tester.pumpWidget(_app(VideoEditorScreen(project: VideoProject())));
    await tester.pump();
    expect(find.text('Add videos or photos'), findsOneWidget);
    expect(find.text('Add media'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
