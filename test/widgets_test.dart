import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_companion/app_state.dart';
import 'package:manga_companion/importers.dart';
import 'package:manga_companion/models/manga_entry.dart';
import 'package:manga_companion/screens/home_screen.dart';
import 'package:manga_companion/screens/import_preview.dart';
import 'package:manga_companion/storage.dart';
import 'package:manga_companion/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rows without a cover print the title on the spine too, so each title
/// appears twice; any of them hits the row.
Finder row(String title) => find.text(title).first;

MangaEntry entry(
  String title, {
  int chapter = 0,
  int updated = 1000,
  ShelfStatus status = ShelfStatus.reading,
}) =>
    MangaEntry(
      id: 'id-$title',
      title: title,
      currentChapter: chapter,
      status: status,
      addedAt: 1,
      lastUpdated: updated,
    );

Future<AppState> stateWith(List<MangaEntry> items) async {
  SharedPreferences.setMockInitialValues({});
  final store = await MangaStore.open();
  await store.save(items);
  return AppState(store);
}

Future<void> pumpHome(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.light),
    home: HomeScreen(state: state),
  ));
}

void main() {
  testWidgets('import preview lists changes and returns the choice',
      (tester) async {
    final state = await stateWith([
      entry('Berserk', chapter: 300),
      entry('Monster', chapter: 162, updated: 9000),
    ]);
    final incoming = [
      entry('Berserk', chapter: 364, updated: 2000),
      entry('Monster', chapter: 100, updated: 1),
      entry('Vagabond', chapter: 5),
    ];
    final plan = state.planMerge(incoming);
    ImportMode? result;

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showImportPreview(context,
                state: state,
                backup: ParsedBackup(BackupSource.mihon, incoming),
                plan: plan);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Import from Mihon?'), findsOneWidget);
    await tester.tap(find.text('Updated'));
    await tester.pumpAndSettle();
    expect(find.text('ch 300 → 364'), findsOneWidget);

    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    expect(result, ImportMode.merge);
  });

  testWidgets('a deleted title can be brought back', (tester) async {
    final state = await stateWith([entry('Berserk'), entry('Monster')]);
    await pumpHome(tester, state);

    await tester.tap(find.byTooltip('More actions for Berserk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(state.entries.map((e) => e.title), ['Monster']);
    expect(find.text('Deleted Berserk'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(state.entries.map((e) => e.title), ['Berserk', 'Monster']);
  });

  testWidgets('long-press selects; bulk delete can be undone',
      (tester) async {
    final state = await stateWith(
        [entry('Berserk'), entry('Monster'), entry('Vagabond')]);
    await pumpHome(tester, state);

    await tester.longPress(row('Berserk'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(row('Monster'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    expect(state.entries.map((e) => e.title), ['Vagabond']);
    expect(find.text('Deleted 2 titles'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(state.entries.length, 3);
  });

  testWidgets('bulk move puts titles on another shelf', (tester) async {
    final state = await stateWith([entry('Berserk'), entry('Monster')]);
    await pumpHome(tester, state);

    await tester.longPress(row('Berserk'));
    await tester.pump();
    await tester.tap(find.byTooltip('Select all on this shelf'));
    await tester.pump();
    await tester.tap(find.byTooltip('Move selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to on hold'));
    await tester.pumpAndSettle();

    expect(state.countFor(ShelfStatus.onHold), 2);
  });

  testWidgets('swipe right logs a chapter', (tester) async {
    final state = await stateWith([entry('Berserk', chapter: 9)]);
    await pumpHome(tester, state);

    await tester.drag(row('Berserk'), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(state.entries.single.currentChapter, 10);
  });

  testWidgets('swipe left marks read, with undo', (tester) async {
    final state = await stateWith([entry('Berserk', chapter: 9)]);
    await pumpHome(tester, state);

    await tester.drag(row('Berserk'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(state.entries.single.status, ShelfStatus.read);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(state.entries.single.status, ShelfStatus.reading);
  });

  testWidgets('an empty shelf shows the onboarding', (tester) async {
    final state = await stateWith([]);
    await pumpHome(tester, state);

    expect(find.text('Start your shelf'), findsOneWidget);
    expect(find.text('Import a backup or list'), findsOneWidget);

    await tester.tap(find.text('Add your first title'));
    await tester.pumpAndSettle();
    expect(find.text('Add a title'), findsOneWidget);
  });

  testWidgets('adding a title already on the shelf warns', (tester) async {
    final state = await stateWith([entry('Kaguya-sama: Love Is War')]);
    await pumpHome(tester, state);

    await tester.tap(find.byTooltip('Add a title'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'kaguya sama love is war');
    await tester.pump();

    expect(find.textContaining('is already on your reading shelf'),
        findsOneWidget);
    expect(find.text('Add anyway'), findsOneWidget);
  });

  testWidgets('every shelf has a tab', (tester) async {
    final state = await stateWith([
      entry('Berserk'),
      entry('Someday', status: ShelfStatus.planned),
    ]);
    await pumpHome(tester, state);

    for (final s in ShelfStatus.values) {
      expect(find.text(s.rail), findsOneWidget);
    }
    await tester.tap(find.text('PLANNED'));
    await tester.pump();
    expect(find.text('Someday'), findsWidgets);
    expect(find.text('Berserk'), findsNothing);
  });
}
