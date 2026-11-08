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
| 389 original filters in 19 categories, with strength control | Built: 59 hand-tuned looks, plus 30 base looks in 11 variations each |
| Exposure, brightness, contrast, fade, saturation, temperature, tint, hue, sepia, vignette | Built |
| Crop, aspect ratios, rotate, flip | Built |
| Text, stickers, shapes, drawing, image layers | Built |
| Curves, HSL, highlights and shadows, sharpen, blur | Not yet |
| AI background removal, retouching, object removal | Not yet |

### Design (Canva-style)

| Feature | Status |
| --- | --- |
| Canvas presets for social, print and presentations | Built |
| 374 original templates in 26 topics, searchable, fully editable | Built: 10 hand-made, plus 364 generated from 14 layouts, 20 palettes and 10 font pairings |
| Layers: move, pinch or handle to scale and rotate, order, lock, hide, opacity, duplicate | Built |
| Snap to centre, 16 fonts, solid and gradient backgrounds | Built |
| PNG, JPG and single-page PDF export at 0.5x, 1x, 2x | Built |
| Stock photo library, brand kits | Not yet: needs licensed content and a backend |
| Multi-page designs | Not yet |
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
| Timed text, sticker and image overlays | Built |
| Music tracks with volume and fades | Built |
| Format presets (9:16, 1:1, 4:5, 16:9, 21:9), export up to 4K at 24, 30 or 60 fps | Built |
| Record from the camera, record a voiceover | Built |
| Reverse, background noise reduction, detach audio to its own track | Built |
| Keyframes, animated text, masks | Not yet |
| Multiple video tracks, picture-in-picture, blend modes | Not yet |
| LUTs, node-based grading, scopes | Not yet |
| Auto captions, beat sync | Not yet: captions need a speech model |
| Speed ramps, chroma key | Not yet |
| Stabilisation | Removed: it used enough memory on a test phone for Android to kill it |
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

**Release signing.** Release builds use the debug key until you add a signing key. Create
one, then add `android/key.properties` (git ignores it, and you should never commit it):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/path/to/upload-keystore.jks
```

Google Play rejects apps signed with the debug key. Keep a backup of the keystore: if you
lose it, you can no longer update the app under the same listing.

**Privacy policy.** Play requires one at a public URL. `PRIVACY.md` is a starting draft
written to match what the app does today; review it, and have it checked if you need to.

**Crash reports.** Errors are logged on the device only, and users can share the log from
the About screen. For reports from users' phones, add a crash reporting service, and
update the privacy policy to cover it.

**Fonts.** Fonts download from Google Fonts on first use, so a new font needs a network
connection. Bundle them as assets if the app has to work fully offline.
