import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manga_companion/app_state.dart';
import 'package:manga_companion/models/manga_entry.dart';
import 'package:manga_companion/storage.dart';

MangaEntry entry(
  String title, {
  String? id,
  int chapter = 0,
  int updated = 1000,
  String cover = '',
  int rating = 0,
}) =>
    MangaEntry(
      id: id ?? 'id-$title',
      title: title,
      coverUrl: cover,
      currentChapter: chapter,
      rating: rating,
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('merge', () {
    test('an older copy never rolls progress back', () async {
      final state =
          await stateWith([entry('Berserk', chapter: 364, updated: 2000)]);
      final plan = state.planMerge(
          [entry('Berserk', id: 'other', chapter: 300, updated: 1000)]);

      expect(plan.skipped.single.title, 'Berserk');
      expect(plan.updated, isEmpty);
      expect(plan.changesAnything, isFalse);

      await state.applyMerge(plan);
      expect(state.entries.single.currentChapter, 364);
    });

    test('the same backup twice changes nothing', () async {
      final state = await stateWith([entry('Berserk', updated: 2000)]);
      final plan = state.planMerge([entry('Berserk', updated: 2000)]);
      expect(plan.changesAnything, isFalse);
    });

    test('a newer copy updates in place and keeps what it lacks', () async {
      final state = await stateWith([
        entry('Berserk',
            chapter: 300, updated: 1000, cover: 'https://c', rating: 4),
      ]);
      // Matched by title, case-insensitively, from another app's file.
      final plan = state.planMerge(
          [entry('  berserk ', id: 'mal-1', chapter: 364, updated: 2000)]);
      await state.applyMerge(plan);

      final e = state.entries.single;
      expect(e.id, 'id-Berserk');
      expect(e.currentChapter, 364);
      expect(e.coverUrl, 'https://c');
      expect(e.rating, 4);
    });

    test('new titles are added, duplicates in the file collapse', () async {
      final state = await stateWith([entry('Berserk')]);
      final plan = state.planMerge([
        entry('Vagabond', id: 'a', chapter: 10, updated: 1),
        entry('Vagabond', id: 'b', chapter: 20, updated: 5),
      ]);
      expect(plan.added.single.currentChapter, 20);

      await state.applyMerge(plan);
      expect(state.entries.map((e) => e.title), ['Berserk', 'Vagabond']);
    });

    test('import can be undone with a snapshot', () async {
      final state = await stateWith([entry('Berserk', chapter: 1)]);
      final before = state.snapshot();
      await state.replaceAll([entry('Monster')]);
      expect(state.entries.single.title, 'Monster');

      await state.replaceAll(before);
      expect(state.entries.single.title, 'Berserk');
      expect(state.entries.single.currentChapter, 1);
    });
  });

  group('undo', () {
    test('a deleted title comes back in the same place', () async {
      final state =
          await stateWith([entry('A'), entry('B'), entry('C')]);
      final removed = await state.remove('id-B');
      expect(state.entries.map((e) => e.title), ['A', 'C']);

      await state.restoreRemoved(removed!);
      expect(state.entries.map((e) => e.title), ['A', 'B', 'C']);
    });

    test('restoring twice does not duplicate', () async {
      final state = await stateWith([entry('A')]);
      final removed = await state.remove('id-A');
      await state.restoreRemoved(removed!);
      await state.restoreRemoved(removed);
      expect(state.entries.length, 1);
    });

    test('a status change reverts from a copy', () async {
      final state = await stateWith([entry('A', updated: 1000)]);
      final item = state.entries.single;
      final before = item.copy();
      await state.setStatus(item, 'dropped');

      await state.update(before);
      expect(state.entries.single.status, 'reading');
      expect(state.entries.single.lastUpdated, 1000);
    });
  });

  test('sort mode survives a restart', () async {
    final state = await stateWith([]);
    state.setSort(SortMode.rating);

    final reopened = AppState(await MangaStore.open());
    expect(reopened.sortMode, SortMode.rating);
  });
}
