import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/artwork.dart';
import '../core/media.dart';

/// Shows one of the app's painted scenes, rendering it on first use. A soft
/// gradient stands in for the moment before it's ready.
class ArtImage extends StatefulWidget {
  const ArtImage(this.scene, {super.key, this.thumb = true, this.fit = BoxFit.cover});
  final ArtScene scene;
  final bool thumb;
  final BoxFit fit;

  @override
  State<ArtImage> createState() => _ArtImageState();
}

class _ArtImageState extends State<ArtImage> {
  ui.Image? _image;

  String get _path => widget.thumb ? widget.scene.thumbPath : widget.scene.path;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ArtImage old) {
    super.didUpdateWidget(old);
    if (old.scene.id != widget.scene.id || old.thumb != widget.thumb) _load();
  }

  void _load() {
    _image = ImageBank.instance.peek(_path);
    if (_image != null) return;
    ImageBank.instance.load(_path).then((image) {
      if (mounted) setState(() => _image = image);
    }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF2A1640), Color(0xFF16141F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      );
    }
    return RawImage(image: image, fit: widget.fit, width: double.infinity, height: double.infinity, filterQuality: FilterQuality.medium);
  }
}
