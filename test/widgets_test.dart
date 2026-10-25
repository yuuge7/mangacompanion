import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manga_companion/app_state.dart';
import 'package:manga_companion/importers.dart';
import 'package:manga_companion/models/manga_entry.dart';
import 'package:manga_companion/screens/home_screen.dart';
import 'package:manga_companion/screens/import_preview.dart';
import 'package:manga_companion/storage.dart';
import 'package:manga_companion/theme.dart';

MangaEntry entry(String title, {int chapter = 0, int updated = 1000}) =>
    MangaEntry(
      id: 'id-$title',
      title: title,
      currentChapter: chapter,
      addedAt: 1,
      lastUpdated: updated,
    );

Future<AppState> stateWith(List<MangaEntry> items) async {
  SharedPreferences.setMockInitialValues({});
  final store = await MangaStore.open();
  await store.save(items);
  return AppState(store);
}

void main() {
  testWidgets('import preview lists changes and returns the choice',
      (tester) async {
    final state = await stateWith([
      entry('Berserk', chapter: 300, updated: 1000),
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
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: HomeScreen(state: state),
    ));

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
}
