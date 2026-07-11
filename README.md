# Manga Companion

Personal Android manga tracker. Data lives on-device only.

## Features

- Reading / Read / Dropped tabs with counts
- Per-entry cover image, read link (opens in browser), chapter progress
  with +/- buttons, progress bar, "Done!" badge, Mark Read
- 5-star ratings on completed titles
- Search, and sorting by recent activity / title / progress / rating
- Stats sheet (counts, total chapters read, average rating)
- Import/Export: plain JSON array

## Build

```sh
flutter pub get
flutter build apk --release
# APK at build/app/outputs/flutter-apk/app-release.apk
```

Icon source in `assets/icon/` (SVG → PNG via rsvg-convert, launcher
icons via `dart run flutter_launcher_icons`).

## Tests

`flutter test` — covers export parsing (typed/stringly fields,
null totals, malformed payloads) and export round-trip.
