# Manga Companion

Personal Android manga tracker. Data lives on-device only.

## Features

- One shelf, filtered by Reading / Read / Dropped from a rail at the top
- Each title is a row that bleeds edge to edge: the cover is a full-height
  spine on the left with a brass bookmark at your position, the chapter
  stepper is a flush block on the right. Titles with no cover get a dye
  from a fixed set with the name running down the spine.
- While sorted by recent activity, the reading list bands by how long a
  title has sat untouched (Today / This week / Earlier this month / Older)
- Tap the spine or the title to open the site you read it on
- 5-star ratings on completed titles
- Search, and sorting by recent activity / title / progress / rating
- Stats sheet, read as a statement rather than a dashboard
- Import/Export: plain JSON array

## Design

Tokens live in `lib/theme.dart` as an `AppTokens` `ThemeExtension`, with
light and dark built by hand rather than derived from a seed colour. The
accent (brass) means exactly one thing — where you are in a title — and is
allowed only on the current-chapter numeral and the spine bookmark. Never
on navigation, headings or buttons. Type is bound to role: PlexSerif names
things, PlexSans explains them, PlexMono counts them (and gives tabular
figures). Fonts are bundled from `assets/fonts/`, so the app needs no
network.

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
