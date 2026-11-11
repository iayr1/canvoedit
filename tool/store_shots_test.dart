// Renders the Google Play listing graphics from the real app screens:
// five designed phone screenshots, the 512 px icon and the feature graphic.
// Template fonts load from STORE_FONTS, a folder of one sub-folder per family
// holding its .ttf files. Run from the project root:
//   STORE_FONTS=path/to/fonts flutter test tool/store_shots_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:canvo_edit/app/logo.dart';
import 'package:canvo_edit/app/theme.dart';
import 'package:canvo_edit/canvas/document.dart';
import 'package:canvo_edit/canvas/layer.dart';
import 'package:canvo_edit/canvas/renderer.dart';
import 'package:canvo_edit/features/editor/editor_screen.dart';
import 'package:canvo_edit/features/home/home_screen.dart';
import 'package:canvo_edit/features/video/video_editor_screen.dart';
import 'package:canvo_edit/features/video/video_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'store-assets/screenshots';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

Future<void> _save(ui.Image image, String name) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$outDir/$name')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
  debugPrint('SAVED $name ${image.width}x${image.height}');
}

/// One designed screenshot: words on top, the app screen in a phone below.
class _Shot {
  const _Shot(this.file, this.title, this.subtitle, this.badge, this.colors, {this.wholePhone = false});
  final String file;
  final String title;
  final String subtitle;
  final String badge;
  final List<Color> colors;

  /// Shrinks the phone to show the whole screen, for tools at the bottom.
  final bool wholePhone;
}

void main() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final shots = <String, ui.Image>{};
  final boundary = GlobalKey();

  setUpAll(() async {
    await _loadFont('Poppins', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) 'assets/fonts/Poppins-$w.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
    await _loadFont('Roboto', ['$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf']);
    final fonts = Platform.environment['STORE_FONTS'];
    if (fonts != null) {
      for (final dir in Directory(fonts).listSync().whereType<Directory>()) {
        final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.ttf')).map((f) => f.path).toList();
        if (files.isNotEmpty) await _loadFont(dir.uri.pathSegments.where((p) => p.isNotEmpty).last, files);
      }
    }
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SceneRenderer.useGoogleFonts = false;
    // Somewhere for the app to keep files during the run.
    final tmp = Directory.systemTemp.createTempSync('canvo-shots').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp,
    );
    // The voiceover recorder has no desktop side; answer it quietly.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
  }

  Future<void> settle(WidgetTester tester, {int seconds = 3}) async {
    for (var i = 0; i < seconds; i++) {
      // Real time passes so painted scenes and thumbnails finish loading.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<ui.Image> capture(WidgetTester tester) async {
    late ui.Image image;
    await tester.runAsync(() async {
      final box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      image = await box.toImage(pixelRatio: 3).timeout(const Duration(seconds: 30));
    });
    return image;
  }

  Widget app(Widget home) => RepaintBoundary(
    key: boundary,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: home),
  );

  Future<void> clearSnack(WidgetTester tester, Type screen) async {
    final finder = find.byType(screen);
    if (finder.evaluate().isNotEmpty) ScaffoldMessenger.of(tester.element(finder)).removeCurrentSnackBar();
    await tester.pump();
  }

  VideoProject video() {
    final p = VideoProject(
      name: 'Summer trip',
      clips: [
        for (final id in ['sunset-coast', 'neon-city', 'alpine-lake', 'aurora-night']) VideoClip(path: 'art://$id', kind: ClipKind.image, sourceMs: 3000),
      ],
    );
    p.clips[0].effect = 'zin1.grain1.none';
    p.clips[0].transition = TransitionType.crossfade;
    p.clips[1].transition = TransitionType.pattern;
    p.clips[1].transitionPattern = 'circle-centre-open-m';
    p.clips[2].grade.filterId = 'teal_amber';
    return p;
  }

  testWidgets('home', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const HomeScreen()));
    await settle(tester, seconds: 4);
    shots['home'] = await capture(tester);
  });

  testWidgets('templates', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump();
    await tester.tap(find.text('Templates').last);
    await settle(tester, seconds: 6);
    shots['templates'] = await capture(tester);
  });

  testWidgets('video effects', (tester) async {
    await phone(tester);
    final p = video();
    await tester.pumpWidget(app(VideoEditorScreen(project: p)));
    await settle(tester, seconds: 2);
    await clearSnack(tester, VideoEditorScreen);
    await tester.tapAt(tester.getTopLeft(find.byKey(ValueKey('clip-${p.clips[0].id}'))) + const Offset(30, 20));
    await tester.pump();
    await tester.tap(find.text('Effects').first);
    await tester.pump();
    await settle(tester, seconds: 3);
    shots['effects'] = await capture(tester);
  });

  testWidgets('video colour', (tester) async {
    await phone(tester);
    final p = video();
    await tester.pumpWidget(app(VideoEditorScreen(project: p)));
    await settle(tester, seconds: 2);
    await clearSnack(tester, VideoEditorScreen);
    p.clips[0].grade.values.addAll({'liftR': -.2, 'liftG': .1, 'liftB': .38, 'gainR': .3, 'gainG': .1, 'gainB': -.25, 'gainY': .1});
    await tester.tapAt(tester.getTopLeft(find.byKey(ValueKey('clip-${p.clips[0].id}'))) + const Offset(30, 20));
    await tester.pump();
    final color = find.text('Color', skipOffstage: false);
    await tester.ensureVisible(color.last);
    await tester.pump();
    await tester.tap(color.last);
    await settle(tester, seconds: 2);
    shots['color'] = await capture(tester);
  });

  testWidgets('designer words', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(VideoEditorScreen(project: video())));
    await settle(tester, seconds: 1);
    await clearSnack(tester, VideoEditorScreen);
    final words = find.text('Words');
    await tester.ensureVisible(words);
    await tester.pump();
    await tester.tap(words);
    await tester.pump();
    await settle(tester, seconds: 6);
    shots['words'] = await capture(tester);
  });

  testWidgets('photo filters', (tester) async {
    await phone(tester);
    final base = CanvasLayer.image('art://spring-blossom', 1080, 1350, width: 1)
      ..name = 'Photo'
      ..isBase = true
      ..locked = true;
    final doc = CanvasDocument(name: 'Spring blossom', isPhoto: true, pixelWidth: 1080, pixelHeight: 1350)..layers.add(base);
    await tester.pumpWidget(app(EditorScreen(document: doc)));
    await settle(tester, seconds: 1);
    // Photos open on Filters; only tap it if the lens carousel isn't showing.
    if (find.byType(PageView).evaluate().isEmpty) {
      await tester.tap(find.text('Filters').first);
      await tester.pump();
    }
    await settle(tester, seconds: 3);
    shots['filters'] = await capture(tester);
  });

  test('compose the listing', () async {
    const brand = [Color(0xFF6D3CF5), Color(0xFFB13CF0), Color(0xFFFF5C8A)];
    final designs = [
      ('home', const _Shot('1-create-anything.png', 'Create anything,\nbeautifully', 'Photos, videos and designs in one app', '518,400 templates', brand)),
      (
        'effects',
        const _Shot('2-video-effects.png', 'Pro video editing\nin your pocket', '1,727 effects and 1,481 transitions', 'Effects on any part', [
          Color(0xFF1B1035),
          Color(0xFF5B2BD8),
          Color(0xFFFF3D8B),
        ]),
      ),
      (
        'color',
        const _Shot('3-color-grading.png', 'Cinematic\ncolour grading', 'Colour wheels for shadows and highlights', 'Music & sound cutting', [
          Color(0xFF0B2A4A),
          Color(0xFF1E6BD8),
          Color(0xFF33D6E6),
        ]),
      ),
      (
        'templates',
        const _Shot('4-templates.png', '518,400\nready-made templates', 'Instagram, YouTube, LinkedIn, posters and more', 'Drop in your photos', [
          Color(0xFFFF8A3D),
          Color(0xFFFF3D8B),
          Color(0xFF8B4DFF),
        ]),
      ),
      (
        'words',
        const _Shot('5-designer-words.png', 'Words that pop', '56,000 designer text styles and labels', '1,255 stickers', [
          Color(0xFF2A0F45),
          Color(0xFF8B2DE0),
          Color(0xFFFFB13D),
        ]),
      ),
      (
        'filters',
        const _Shot('6-photo-filters.png', '389 filters,\none swipe away', 'Swipe through looks for every photo', 'Pro photo editor', [
          Color(0xFFFF5C8A),
          Color(0xFFB13CF0),
          Color(0xFF5B3CF5),
        ], wholePhone: true),
      ),
    ];
    for (final (key, shot) in designs) {
      final screen = shots[key];
      if (screen == null) {
        debugPrint('MISSING $key');
        continue;
      }
      await _save(await _composeShot(shot, screen), shot.file);
    }

    // The 512 px Play Store icon: full-bleed, Google Play rounds the corners.
    await _save(
      await _render(512, 512, (c, s) {
        LogoPainter.paintBackground(c, s);
        const LogoPainter(tile: false, glyphScale: .56).paint(c, s);
      }),
      'play-store-icon-512.png',
    );
    await _save(await _render(1024, 500, _featureGraphic), 'feature-graphic-1024x500.png');
  });
}

Future<ui.Image> _render(int w, int h, void Function(Canvas, Size) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), Size(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  return image;
}

TextPainter _text(String text, double size, FontWeight weight, Color color, double maxWidth, {double height = 1.12, TextAlign align = TextAlign.center}) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: -size * .015),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
}

void _decor(Canvas c, Size s, int seed) {
  final r = math.Random(seed);
  // Soft glowing blobs.
  for (var i = 0; i < 3; i++) {
    final center = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
    final radius = s.width * (.35 + r.nextDouble() * .3);
    c.drawCircle(
      center,
      radius,
      Paint()..shader = ui.Gradient.radial(center, radius, [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: 0)]),
    );
  }
  // A scatter of sparkles.
  for (var i = 0; i < 14; i++) {
    final p = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
    final k = s.width * (.006 + r.nextDouble() * .014);
    final path = Path();
    for (var j = 0; j < 8; j++) {
      final a = -math.pi / 2 + j * math.pi / 4;
      final d = j.isEven ? k : k * .3;
      final q = p + Offset(math.cos(a) * d, math.sin(a) * d);
      j == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    c.drawPath(path..close(), Paint()..color = Colors.white.withValues(alpha: .25 + r.nextDouble() * .45));
  }
}

Future<ui.Image> _composeShot(_Shot shot, ui.Image screen) async {
  return _render(1080, 1920, (c, s) {
    final rect = Offset.zero & s;
    c.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, shot.colors, const [0, .55, 1]));
    _decor(c, s, shot.file.hashCode);

    // Headline and subtitle.
    final title = _text(shot.title, 92, FontWeight.w800, Colors.white, 960);
    title.paint(c, Offset((s.width - title.width) / 2, 120));
    final sub = _text(shot.subtitle, 38, FontWeight.w500, Colors.white.withValues(alpha: .88), 900, height: 1.3);
    final subTop = 120 + title.height + 26;
    sub.paint(c, Offset((s.width - sub.width) / 2, subTop));

    // A badge between the words and the phone.
    final badge = _text(shot.badge, 34, FontWeight.w700, AppColors.ink, 700);
    final bw = badge.width + 64 + 44, bh = 84.0;
    final badgeTop = subTop + sub.height + 34;
    final bRect = RRect.fromRectAndRadius(Rect.fromLTWH((s.width - bw) / 2, badgeTop, bw, bh), const Radius.circular(42));

    // The phone, running off the bottom edge.
    const bezel = 22.0;
    final top = badgeTop + bh + 44;
    final screenW = shot.wholePhone ? (s.height - top - 40 - bezel * 2) * screen.width / screen.height : 700.0;
    final screenH = screenW * screen.height / screen.width;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH((s.width - screenW) / 2 - bezel, top, screenW + bezel * 2, screenH + bezel * 2),
      const Radius.circular(96),
    );
    c.drawRRect(
      body.shift(const Offset(0, 30)),
      Paint()
        ..color = Colors.black.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );
    c.drawRRect(body, Paint()..color = const Color(0xFF0B0A12));
    c.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: .18),
    );
    final screenRect = Rect.fromLTWH((s.width - screenW) / 2, top + bezel, screenW, screenH);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(screenRect, const Radius.circular(76)));
    c.drawImageRect(screen, Offset.zero & Size(screen.width.toDouble(), screen.height.toDouble()), screenRect, Paint()..filterQuality = FilterQuality.high);
    c.restore();
    // Camera dot.
    c.drawCircle(Offset(s.width / 2, top + bezel + 30), 11, Paint()..color = const Color(0xFF0B0A12));

    c.drawRRect(
      bRect.shift(const Offset(0, 12)),
      Paint()
        ..color = Colors.black.withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    c.drawRRect(bRect, Paint()..color = Colors.white);
    final dot = Offset(bRect.left + 46, bRect.center.dy);
    c.drawCircle(dot, 18, Paint()..shader = AppGradients.brand.createShader(Rect.fromCircle(center: dot, radius: 18)));
    badge.paint(c, Offset(bRect.left + 78, bRect.center.dy - badge.height / 2));
  });
}

void _featureGraphic(Canvas c, Size s) {
  final rect = Offset.zero & s;
  c.drawRect(
    rect,
    Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, const [Color(0xFF6D3CF5), Color(0xFFB13CF0), Color(0xFFFF5C8A)], const [0, .55, 1]),
  );
  _decor(c, s, 7);
  const logo = 200.0;
  c.save();
  c.translate(90, (s.height - logo) / 2);
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(0, 14, logo, logo), const Radius.circular(52)),
    Paint()
      ..color = Colors.black.withValues(alpha: .3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
  );
  const LogoPainter().paint(c, const Size.square(logo));
  c.restore();
  final name = _text('Canvo Edit', 82, FontWeight.w800, Colors.white, 640, align: TextAlign.left);
  final tag = _text('Photo, video and design editor', 34, FontWeight.w500, Colors.white.withValues(alpha: .9), 640, align: TextAlign.left);
  final x = 90 + logo + 56, y = (s.height - name.height - tag.height - 10) / 2;
  name.paint(c, Offset(x, y));
  tag.paint(c, Offset(x, y + name.height + 10));
}
