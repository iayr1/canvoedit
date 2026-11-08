import 'dart:io';
import 'dart:ui' as ui;

import 'package:canvo_edit/app/theme.dart';
import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/canvas/template_library.dart';
import 'package:canvo_edit/canvas/templates.dart';
import 'package:canvo_edit/core/media.dart';
import 'package:canvo_edit/features/editor/editor_screen.dart';
import 'package:canvo_edit/features/home/home_screen.dart';
import 'package:canvo_edit/features/home/template_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Renders Google Play store graphics from the real app. Not part of the
/// regular suite: run it when the listing needs fresh images.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory out;

  Future<void> savePng(ui.Image image, String name) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${out.path}/$name.png').writeAsBytes(data!.buffer.asUint8List());
    debugPrint('ASSET $name ${image.width}x${image.height}');
  }

  setUpAll(() async {
    out = Directory('${(await getTemporaryDirectory()).path}/store');
    if (await out.exists()) await out.delete(recursive: true);
    await out.create();
  });

  test('app icon, 512 x 512', () async {
    final image = await SceneRenderer.rasterize(512, 512, (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = AppColors.ink);
      // Same artwork as the launcher icon, scaled from its 108-unit grid.
      c.scale(512 / 76);
      c.translate(-16, -16);
      c.drawPath(
        Path()
          ..moveTo(71, 37)
          ..arcToPoint(const Offset(71, 71), radius: const Radius.circular(24), largeArc: true, clockwise: false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = AppColors.coral,
      );
      c.drawPath(
        Path()
          ..moveTo(48, 42)
          ..lineTo(67, 54)
          ..lineTo(48, 66)
          ..close(),
        Paint()..color = Colors.white,
      );
    });
    await savePng(image, 'icon-512');
  });

  test('feature graphic, 1024 x 500', () async {
    final picks = [allTemplates[0], allTemplates[30], allTemplates[60]];
    final docs = [for (final t in picks) t.build()];
    for (final d in docs) {
      await SceneRenderer.prepare(d.layers);
    }
    final title = CanvasLayer.text('Canvo Edit', font: 'Poppins', size: .085)..bold = true;
    final tagline = CanvasLayer.text('Photos. Videos. Designs.', font: 'Poppins', size: .036, color: 0xFFFF9B85);
    await SceneRenderer.prepare([title, tagline]);
    final image = await SceneRenderer.rasterize(1024, 500, (c, s) {
      c.drawRect(
        Offset.zero & s,
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(s.width, s.height), const [Color(0xFF0E0F13), Color(0xFF2A1F4A)]),
      );
      title
        ..cx = .27
        ..cy = .42;
      tagline
        ..cx = .27
        ..cy = .58;
      SceneRenderer.paintLayer(c, s, title);
      SceneRenderer.paintLayer(c, s, tagline);
      var x = 540.0;
      for (var i = 0; i < docs.length; i++) {
        final d = docs[i];
        const height = 330.0;
        final width = height * d.aspectRatio;
        // Only whole cards: a cut-off one looks like a mistake.
        if (x + width > s.width - 12) break;
        c.save();
        c.translate(x, (s.height - height) / 2 + (i == 1 ? -14 : 14));
        c.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width, height), const Radius.circular(14)));
        SceneRenderer.paintDocument(c, Size(width, height), d);
        c.restore();
        x += width + 18;
      }
    });
    await savePng(image, 'feature-1024x500');
  });

  // Phone screenshots at 1080 x 1920, which suits Play's 2:1 limit, captured
  // from the app's own widgets rather than from the phone's screen.
  Future<void> shoot(WidgetTester tester, String name, Widget screen, {Future<void> Function()? then}) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: screen)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (then != null) {
      await then();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }
    await tester.runAsync(() async {
      // Fonts and images arrive asynchronously, so give them time, then repaint.
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump(const Duration(milliseconds: 300));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.7));
    await tester.runAsync(() => savePng(image!, name));
  }

  testWidgets('screenshot: home', (tester) async {
    await shoot(tester, 'shot-1-home', const HomeScreen());
  });

  testWidgets('screenshot: templates', (tester) async {
    await shoot(tester, 'shot-2-templates', const TemplateBrowser());
  });

  testWidgets('screenshot: photo filters', (tester) async {
    await tester.runAsync(() async {
      final photo = await SceneRenderer.rasterize(1080, 1350, (c, s) {
        c.drawRect(
          Offset.zero & s,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height * .72), const [
              Color(0xFF28407A),
              Color(0xFFE76F51),
              Color(0xFFF4C27A),
            ], [0, .62, 1]),
        );
        c.drawCircle(Offset(s.width * .68, s.height * .5), s.width * .13, Paint()..color = const Color(0xFFFFE9B0));
        c.drawRect(Rect.fromLTWH(0, s.height * .74, s.width, s.height * .26), Paint()..color = const Color(0xFF2A9D8F));
      });
      ImageBank.instance.put('store://photo', photo);
    });
    final base = CanvasLayer.image('store://photo', 1080, 1350, width: 1)
      ..isBase = true
      ..locked = true
      ..grade.filterId = 'golden_hour';
    final doc = CanvasDocument(name: 'Sunset', isPhoto: true, pixelWidth: 1080, pixelHeight: 1350, background: CanvasBackground(0xFF000000), layers: [base]);
    await shoot(tester, 'shot-3-photo', EditorScreen(document: doc));
  });

  testWidgets('screenshot: design editor', (tester) async {
    final doc = featuredTemplates.first.build();
    await shoot(tester, 'shot-4-design', EditorScreen(document: doc));
  });
}
