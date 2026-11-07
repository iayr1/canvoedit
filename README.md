# Canvo Edit

A mobile photo, video and design editor built with Flutter for Android and iOS.

All code, filters and templates here are original. Nothing is copied or decompiled
from Canva, Adobe, Blackmagic or Instagram, and nothing should be: decompiling those
apps breaks their licence terms and would put this app at legal risk.

## Run it

Connect an Android phone with USB debugging on, or start an emulator, then:

```bash
flutter pub get
```

```bash
flutter run
```

Build an APK to install directly:

```bash
flutter build apk --release --split-per-abi
```

iOS builds need a Mac with Xcode. The browser build (`flutter run -d chrome`) is only
for previewing the interface: it has no video export and doesn't keep projects.

## Tests

```bash
flutter test
```

## What's built, and what isn't

Marked against the products Canvo Edit is inspired by. "Partial" says what's missing.

### Photo editing

| Feature | Status |
| --- | --- |
| 59 original filters in 10 categories, with strength control | Built |
| Exposure, brightness, contrast, fade, saturation, temperature, tint, hue, sepia, vignette | Built |
| Crop, aspect ratios, rotate, flip | Built |
| Text, stickers, shapes, drawing, image layers | Built |
| Curves, HSL, highlights and shadows, sharpen, blur | Not yet |
| AI background removal, retouching, object removal | Not yet |

### Design (Canva-style)

| Feature | Status |
| --- | --- |
| Canvas presets for social, print and presentations | Built |
| 10 original templates, fully editable | Built |
| Layers: move, pinch or handle to scale and rotate, order, lock, hide, opacity, duplicate | Built |
| Snap to centre, 16 fonts, solid and gradient backgrounds | Built |
| PNG export at 0.5x, 1x, 2x | Built |
| Stock library, thousands of templates, brand kits | Not yet: needs content and a backend |
| PDF export, multi-page designs | Not yet |
| Real-time collaboration, accounts, cloud sync | Not yet: needs a backend |

### Video editing (Premiere, Resolve and Edits-style)

| Feature | Status |
| --- | --- |
| Multi-clip timeline with zoom, photos and videos | Built |
| Trim, split, duplicate, reorder, delete, undo and redo | Built |
| Speed 0.25x to 4x, clip volume, fit or fill, flip | Built |
| 8 transitions | Built: the preview approximates the exact export look |
| Filters and adjustments on each clip | Built |
| Shadow and highlight colour grading | Partial: lift and gain only, no colour wheels or curves |
| Timed text and sticker overlays | Built |
| Music tracks with volume and fades | Built |
| Format presets (9:16, 1:1, 4:5, 16:9, 21:9), export up to 4K at 24, 30 or 60 fps | Built |
| Record from the camera | Built |
| Keyframes, animated text, masks | Not yet |
| Multiple video tracks, picture-in-picture, blend modes | Not yet |
| LUTs, node-based grading, scopes | Not yet |
| Auto captions, beat sync, voiceover recording, noise reduction | Not yet |
| Reverse, speed ramps, stabilisation, chroma key | Not yet |
| Proxies, multicam, audio mixer, Fairlight-style audio tools | Not yet |
| HDR, RAW and ProRes workflows | Not yet: limited by phone hardware |

## How it fits together

- `lib/core/color`: slider values become one colour matrix, used by the Flutter preview
  and by FFmpeg at export. Only linear operations are allowed, so both stay in step.
- `lib/canvas`: the layer model and `SceneRenderer`. The live canvas, PNG exports and
  video overlays all paint through this one class.
- `lib/features/video/ffmpeg_graph.dart`: turns a project into FFmpeg arguments. This is
  plain Dart with no device dependency, so it's covered by unit tests.
- `lib/features/video/playback_engine.dart`: plays the timeline from a master clock
  using one native player per clip on screen.

## Before you publish

**FFmpeg licensing.** `ffmpeg_kit_flutter_new` is the full GPL build because it includes
x264. Distributing an app that uses it means releasing your app's source under GPL v3.
To keep the app closed source, switch to an LGPL FFmpeg build and use
`VideoEncoder.hardwareAndroid` in `ffmpeg_graph.dart`, plus an equivalent for iOS.
H.264 and AAC may also carry patent licensing duties in some markets, so get legal
advice before a commercial launch.

**Release signing.** `android/app/build.gradle.kts` still signs release builds with the
debug key. Add your own signing key before uploading to Google Play.

**Fonts.** Fonts download from Google Fonts on first use, so a new font needs a network
connection. Bundle them as assets if the app has to work fully offline.
