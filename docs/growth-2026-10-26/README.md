# Store conversion and localization — 2026-10-26

## Delivered

- Japanese/English plus Korean, German, French and Spanish. All 64 working-tree UI entries and five InfoPlist entries have coverage. Existing photo-icon work is preserved; its 22 catalog entries remain part of the user's uncommitted work, with new translations also in translations.tsv.
- Six localized store names/subtitles/descriptions, with a consistent account of eight camera looks, three free cameras and individual purchases.
- Two iPhone screenshot drafts per language, 1320×2868 opaque JPEG. Gallery: `../../temp/screenshots/iphone/index.html` (local only).
- First screenshot compares the same café photograph before rendering and after the app's Sunset Fade processing. Labels describe a scene and the camera's result, not an existing-photo import feature. Second screenshot shows the real localized camera UI.
- Screenshot-only photo input is restricted to DEBUG simulator builds. The camera app's device behavior is unchanged.

## Hypothesis and measurement

Baseline supplied for 2026-09-24–2026-10-23: 2,449 impressions, 103 page views, 16 first downloads. Page views / impressions = 4.21%; downloads / page views = 15.53%. These are aggregate ratios, not a cohort conversion rate.

Hypothesis: making the actual photographic result visible on screenshot one improves store-page comprehension and first downloads. No advertising spend. After publication compare equal 14-day periods by locale/country and source where possible, monitoring impressions, page views and downloads together. Check direction after 7 days; extend to 28 days if counts are still small. Combined copy/localization changes cannot isolate the effect of one screenshot.

## Reproduce

Local source photograph (not committed): `fastlane/screenshots/source/photos/02_iced_coffee_cafe.jpg`.
Rendered comparison: `docs/screenshot_directions/src/assets/real/cafe-sunsetfade.jpg`. Provenance and matching FilmRenderer/CameraCatalog sources are documented in `docs/screenshot_directions/film-render/README.md`.

```sh
xcodebuild test -project RetroSnap.xcodeproj -scheme RetroSnap \
  -destination 'platform=iOS Simulator,id=564B1816-36F5-4386-B1CF-E6253B15CF59' \
  -only-testing:RetroSnapUITests/StoreLocalizationScreenshotTests \
  -parallel-testing-enabled NO -derivedDataPath /tmp/retrosnap-growth-build
swiftc -target arm64-apple-macosx15.0 docs/growth-2026-10-26/render-screenshots.swift -o /tmp/render-retro-growth
/tmp/render-retro-growth retro
```

Raw captures: `/tmp/retrosnap-growth-screens`. Output: `temp/screenshots/iphone`. Screenshots wait for the asynchronous Core Image preview after camera selection. The screenshot test skips if the private local source photo is unavailable.

## Verification and release

- Simulator build: `BUILD SUCCEEDED`.
- Six-locale camera UI capture: `TEST SUCCEEDED`, 0 failures.
- Locale coverage and interpolation placeholders checked for all entries; App Store title/subtitle length <=30 validated.
- Before/after English and Japanese values from existing uncommitted work preserved.
- ASC checked 2026-10-26: 0.3.4 is READY_FOR_SALE. At preview creation this work had not been uploaded, submitted or published; see the approved-upload record below.
- Preview approval precedes screenshot deployment. New images are iPhone only; verify iPad slots before upload. No independent native-speaker review yet.

## Approved store upload — 2026-10-26

User approved the preview images in this conversation. Upload target: RetroSnap 0.3.5, newly created PREPARE_FOR_SUBMISSION version.

Only the six approved descriptions, names, subtitles and iPhone screenshot pairs are updated. Existing iPad sets are retained. Older local screenshots remain as source history; the approved files have the `growth_20261026` filename suffix. Do not bulk-upload every old image in this directory.

Proof: `asc-before.json` (snapshot), `asc-upload.json` (uploaded asset IDs), `asc-verified.json` (server readback, metadata equality and ordered screenshot MD5 checksums). These changes save store drafts; no binary was uploaded and no review was submitted in this step. In-app translations require a new build.
