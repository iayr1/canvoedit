# Google Play release checklist

Answers prepared for Play Console, based on what the app does in version 1.0.0. Every
declaration here is yours to confirm before you submit it: Play holds you responsible
for its accuracy.

## App details

| Field | Value |
| --- | --- |
| App name | Canvo Edit |
| Package name | `online.athlorun.canvoedit` (permanent once uploaded) |
| Default language | English (United States) – en-US |
| App or game | App |
| Free or paid | Free |
| Category | Photography (Video Players & Editors also fits) |
| Contains ads | No |
| In-app purchases | No |

## Store listing

**Short description** (80 characters max):

> Edit photos and videos, and design posts with hundreds of filters and templates.

**Full description:**

> Canvo Edit is a photo editor, video editor and design studio in one free app.
>
> PHOTOS
> • 389 filters across 19 styles, each with a strength slider
> • Exposure, contrast, colour, temperature, fade, vignette and colour grading
> • Crop, rotate and flip, plus text, stickers, shapes and drawing
>
> VIDEOS
> • Multi-clip timeline with trim, split, reorder and speed from 0.25x to 4x
> • 8 transitions, per-clip filters and colour adjustments
> • Text, stickers and images that appear exactly when you want
> • Music, voiceover recording, background noise reduction and reverse
> • Export up to 4K at 24, 30 or 60 fps for Reels, Shorts and more
>
> DESIGNS
> • 374 templates for sales, quotes, events, birthdays, business and more
> • Sizes for every major platform, from stories to posters
> • Export as PNG, JPG or PDF
>
> PRIVATE BY DESIGN
> Your photos, videos and projects stay on your phone. Nothing is uploaded.
>
> FREE AND OPEN SOURCE
> Canvo Edit is licensed under the GNU GPL v3. Source code:
> https://github.com/iayr1/canvoedit

**Graphics you still need to make:**

| Asset | Size |
| --- | --- |
| App icon | 512 × 512 PNG |
| Feature graphic | 1024 × 500 PNG or JPG |
| Phone screenshots | at least 2, from the app on a phone |

## Privacy policy

Play requires a public URL. Once `PRIVACY.md` has your contact details and is pushed,
you can use: https://github.com/iayr1/canvoedit/blob/main/PRIVACY.md

## Data safety

Based on the code as of 1.0.0:

- **Does your app collect or share any of the required user data types?** No. Photos,
  videos, audio and projects are processed on the device and never sent off it.
- **Is data encrypted in transit?** Only font downloads leave the device, and they use
  HTTPS.
- **Font downloads:** the request to Google Fonts sends standard network information,
  such as the IP address, but no user data. Google's guidance treats data that isn't sent
  off the device, or that a service receives only in order to deliver content, as not
  collected. Check the current Play definitions before you answer.
- **Crash log:** stays on the device unless the user shares it themselves.

## Permissions to explain

| Permission | Purpose |
| --- | --- |
| `RECORD_AUDIO` | Voiceover recording, only while the user records |
| `INTERNET` | Downloading fonts |
| `WRITE_EXTERNAL_STORAGE` (Android 9 and older) | Saving exports to the gallery |

The photo picker needs no storage permission on current Android versions.

## Content rating questionnaire

Category: **Utility, Productivity, Communication or Other**. Expected answers:

- Violence, sexual content, profanity, controlled substances, gambling: none in the app.
- Users can interact or exchange content with each other: **No**. Sharing goes to apps
  the user picks, and there is nothing inside Canvo Edit to share with other users.
- Shares the user's location: **No**.
- Allows purchases of digital goods: **No**.

## Target audience

**18 and over** is the simplest choice. Choosing ages under 13 triggers the Families
policy, which brings extra requirements.

## Release

1. Testing, then Internal testing, then Create new release.
2. Use Play App Signing, which is the default. Your key in `C:/Users/mayur/canvo-signing`
   becomes the upload key.
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
4. Release name: `1.0.0 (1)`. Release notes: "First test release."
5. Add testers by email, then share the opt-in link with them.

## Before each new upload

- Increase the version in `pubspec.yaml`. For example, `1.0.0+1` becomes `1.0.1+2`.
  Play rejects a version code it has already seen.
- Tag the release in git, so the source for every published version is easy to find.
