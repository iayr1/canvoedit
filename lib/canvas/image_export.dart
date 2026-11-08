import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Canvas, Size;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'document.dart';
import 'renderer.dart';

enum ImageExportFormat {
  png('PNG', 'png'),
  jpeg('JPG', 'jpg'),
  pdf('PDF', 'pdf');

  const ImageExportFormat(this.label, this.extension);
  final String label;
  final String extension;
}

/// Encodes a document as a file. All formats come from the same render.
Future<Uint8List> exportDocument(CanvasDocument doc, ImageExportFormat format, {double scale = 1}) async {
  switch (format) {
    case ImageExportFormat.png:
      return SceneRenderer.exportPng(doc, scale: scale);
    case ImageExportFormat.jpeg:
      await SceneRenderer.prepare(doc.layers);
      final w = (doc.pixelWidth * scale).round().clamp(1, 8192);
      final h = (doc.pixelHeight * scale).round().clamp(1, 8192);
      final image = await SceneRenderer.rasterize(w, h, (Canvas c, Size s) => SceneRenderer.paintDocument(c, s, doc));
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      // JPEG encoding is slow at full size, so it runs off the UI thread.
      return compute(_encodeJpeg, (data!.buffer.asUint8List(), w, h));
    case ImageExportFormat.pdf:
      return _encodePdf(await SceneRenderer.exportPng(doc, scale: scale), doc);
  }
}

Uint8List _encodeJpeg((Uint8List, int, int) input) {
  final (rgba, w, h) = input;
  final image = img.Image.fromBytes(width: w, height: h, bytes: rgba.buffer, numChannels: 4);
  return img.encodeJpg(image, quality: 92);
}

/// Places the render on one page. Large canvases are print presets at 300 dpi,
/// so an A4 design comes out as a true A4 page.
Future<Uint8List> _encodePdf(Uint8List png, CanvasDocument doc) {
  final dpi = math.max(doc.pixelWidth, doc.pixelHeight) >= 3000 ? 300 : 96;
  final format = PdfPageFormat(doc.pixelWidth * 72 / dpi, doc.pixelHeight * 72 / dpi);
  final pdf = pw.Document(title: doc.name)
    ..addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.SizedBox.expand(child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill)),
      ),
    );
  return pdf.save();
}
