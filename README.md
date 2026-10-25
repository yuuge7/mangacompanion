# Manga Companion

Personal Android manga tracker. Data lives on-device only.

## Features

- One shelf, filtered by Reading / On hold / Planned / Read / Dropped from
  a rail at the top
- Each title is a row that bleeds edge to edge: the cover is a full-height
  spine on the left with a brass bookmark at your position, the chapter
  stepper is a flush block on the right. Titles with no cover get a dye
  from a fixed set with the name running down the spine.
- While sorted by recent activity, the reading list bands by how long a
  title has sat untouched (Today / This week / Earlier this month / Older)
- Tap the spine or the title to open the site you read it on
- Swipe a row right to log a chapter, left to mark it read
- Long-press to select several titles, then move or delete them together
- 5-star ratings on completed titles; "Read again" counts re-reads
- Every logged chapter is kept as reading history (quick steps on the same
  day fold into one entry). Each title shows its start/finish dates and
  recent steps; the Stats sheet shows chapters this week/month/year and
  reading streaks
- Warns when you add a title that is already on the shelf (matched loosely:
  case, spacing and punctuation are ignored)
- Search, and sorting by recent activity / title / progress / rating
- Stats sheet, read as a statement rather than a dashboard
- "Reading" home screen widget: titles in progress with a + to log a
  chapter without opening the app. It edits the saved shelf directly
  (`android/.../ShelfStore.kt` mirrors the app's rules)
- First-run screen with add/import and a few tips
- Export: JSON (full backup, with history) or CSV for spreadsheets.
  Import reads the JSON, plus MyAnimeList XML,
  Anime-Planet JSON and Mihon/Tachiyomi backups (gzipped or not). Merge
  shows a preview first and never replaces a title with an older copy
- Undo for delete, status changes and imports
- Android cloud backup is off; your export files are the only backup

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

`flutter test` — covers the model and its JSON, history folding, stats,
CSV, the importers, merge rules, undo, bulk actions, and the main UI
flows (preview, swipes, selection, onboarding, duplicate warning).
`test/large_library_test.dart` runs the hot paths against 5,000 titles.
Lints are strict (see `analysis_options.yaml`). CI runs `flutter analyze`
and `flutter test` before every release build.
